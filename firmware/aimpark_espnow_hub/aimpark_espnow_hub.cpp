// AimPark — ESP-NOW hub
// Plugged by USB into the site server's PC. Relays between the server and the
// wireless nodes (gates G1, G2; slot sensor boards S1, S2). It decides
// nothing: the server answers every tap, and the installer decides which
// boards may join and what each is called.
//
// Protocol, one line each way, every line starting with the board it is about:
//   hub    -> server   G1 UID:04A1B2C3          a card was tapped at gate 1
//   server -> hub      G1 RESULT:OPEN           (or RESULT:SHUT) the answer
//   server -> hub      G2 CMD:OPEN              the guard's "Open gate" button
//   hub    -> server   S1/3 SLOT:OCCUPIED 3.7   slot 3 on board S1 changed;
//   hub    -> server   S1/3 SLOT:FREE 0.0       distance in cm, 0 = nothing in range
//   hub    -> server   S1/3 SLOT:FAULT 0.0      sensor 3 on S1 hears no echo (unplugged
//                                               or broken); OCCUPIED/FREE clears it
//   hub    -> server   G1 ONLINE / G1 OFFLINE   a node came up or went quiet
//   hub    -> server   G1 ERR:NOT_DELIVERED     a RESULT/CMD didn't reach it
//   server -> hub      STATUS                   every paired board (PAIRED line,
//                                               then its state), right now
// Pairing. A board is known by its id (MAC, 12 hex digits) until it is named:
//   hub    -> server   PAIRREQ 582ABDD0A36C GATE    an unpaired board asks to join
//   server -> hub      PAIR 582ABDD0A36C G1         accept it, and call it G1
//   hub    -> server   PAIRED G1 582ABDD0A36C GATE  (also repeated on STATUS)
//   server -> hub      FORGET G1                    remove it
//   hub    -> server   FORGOT G1
//   hub    -> server   ERR 582ABDD0A36C <why>       a PAIR that didn't work
//   server -> hub      PING                         answered: HUB <id> <protocol>
// Diagnostics, for the panel's connection test:
//   server -> hub      DIAG                         the hub's own health:
//   hub    -> server   DIAG HUB id=… proto=4 up=… heap=… reset=… nodes=… fails=…
//   server -> hub      DIAG G1                      ping the board over the air:
//   hub    -> server   DIAG G1 rtt=… rssi=… noderssi=… up=… heap=… reset=…
//                               fails=… packets=… drops=… [rc522=… | sensors=… noecho=…]
//   hub    -> server   DIAG G1 FAIL <why>           NOT_PAIRED, NOT_DELIVERED, NO_REPLY
// Naming a board with a name another board has (a replacement for a broken
// G1) removes the old one. Gates are G1–G9, sensor boards S1–S9.
// Lines starting with "#" are for people reading the Serial Monitor.
//
// No wiring: just the USB cable.

#include <Arduino.h>
#include <Preferences.h>
#include <AimParkEspNow.h>

using namespace aimpark;

constexpr uint8_t NAME_CHARS = 3;   // "G1", "S9"

struct NodeState {
  bool used = false;
  uint8_t mac[6] = {0};
  uint8_t role = 0;
  char name[NAME_CHARS] = {0};

  bool online = false;
  unsigned long lastSeen = 0;

  bool anySeq = false;       // Drops the duplicates a lost ack can cause.
  uint16_t lastSeq = 0;

  // Gates: the seq of the tap waiting for the server's answer.
  bool tapPending = false;
  uint16_t tapSeq = 0;

  // Connection test: the PING waiting for its PONG, and what the radio saw.
  bool pingPending = false;
  uint16_t pingSeq = 0;
  unsigned long pingSentAt = 0;
  int8_t rssi = 0;              // Of the last packet heard from it, dBm.
  uint32_t packets = 0;         // Heard from it since the hub booted.
  uint16_t drops = 0;           // Times it went offline since the hub booted.

  // Sensors: one entry per slot on the board. -1 until the first reading.
  uint8_t slotCount = 0;
  int8_t occupied[MAX_SLOTS];
  uint16_t distanceMm[MAX_SLOTS];
  bool fault[MAX_SLOTS];        // The sensor hears no echo: unplugged or broken.

  NodeState() { forgetSlots(); }
  void forgetSlots() {
    slotCount = 0;
    for (uint8_t i = 0; i < MAX_SLOTS; i++) {
      occupied[i] = -1;
      distanceMm[i] = 0;
      fault[i] = false;
    }
  }
};

// Boards asking to join, so PAIR can only accept one that really asked.
struct Request {
  bool used = false;
  uint8_t mac[6];
  uint8_t role = 0;
  unsigned long lastAt = 0;
  unsigned long lastPrintedAt = 0;
};

// A board answers a PING from its loop: a sensor board between scans, so
// allow a full scan of nine sensors and then some.
constexpr unsigned long PING_TIMEOUT_MS = 2000;

constexpr uint8_t MAX_REQUESTS = 8;
constexpr unsigned long REQUEST_FORGOTTEN_MS = 30000;
constexpr unsigned long REQUEST_REPRINT_MS = 5000;

NodeState nodes[MAX_NODES];
Request requests[MAX_REQUESTS];
Preferences prefs;
uint16_t mySeq = 0;
String hubId;

// ── Flash ────────────────────────────────────────────────────────────────────
struct __attribute__((packed)) Saved {
  uint8_t mac[6];
  uint8_t role;
  char name[NAME_CHARS];
};

void saveNodes() {
  Saved saved[MAX_NODES];
  uint8_t count = 0;
  for (auto& n : nodes) {
    if (!n.used) continue;
    memcpy(saved[count].mac, n.mac, 6);
    saved[count].role = n.role;
    memcpy(saved[count].name, n.name, NAME_CHARS);
    count++;
  }
  if (count == 0) prefs.remove("nodes");
  else prefs.putBytes("nodes", saved, count * sizeof(Saved));
}

void loadNodes() {
  Saved saved[MAX_NODES];
  size_t bytes = prefs.isKey("nodes") ? prefs.getBytes("nodes", saved, sizeof saved) : 0;
  uint8_t count = bytes / sizeof(Saved);
  for (uint8_t i = 0; i < count && i < MAX_NODES; i++) {
    nodes[i] = NodeState();
    nodes[i].used = true;
    memcpy(nodes[i].mac, saved[i].mac, 6);
    nodes[i].role = saved[i].role;
    memcpy(nodes[i].name, saved[i].name, NAME_CHARS);
    nodes[i].name[NAME_CHARS - 1] = '\0';
    if (!setPeer(nodes[i].mac, true)) Serial.printf("# Could not add peer %s\n", nodes[i].name);
  }
}

NodeState* byMac(const uint8_t* mac) {
  for (auto& n : nodes)
    if (n.used && memcmp(n.mac, mac, 6) == 0) return &n;
  return nullptr;
}

NodeState* byName(const String& name) {
  for (auto& n : nodes)
    if (n.used && name.equalsIgnoreCase(n.name)) return &n;
  return nullptr;
}

// G1–G9 for a gate, S1–S9 for a sensor board.
bool nameFits(const String& name, uint8_t role) {
  if (name.length() != 2 || name[1] < '1' || name[1] > '9') return false;
  char letter = toupper(name[0]);
  return (role == ROLE_GATE && letter == 'G') || (role == ROLE_SENSOR && letter == 'S');
}

// ── To the server ────────────────────────────────────────────────────────────
void printPaired(const NodeState& n) {
  Serial.printf("PAIRED %s %s %s\n", n.name, macToId(n.mac).c_str(), roleName(n.role));
}

// Slots are numbered from 1, as printed on the model. A faulted sensor's
// occupancy is only its last good reading, so FAULT is all that is said.
void printSlot(const NodeState& n, uint8_t slot) {
  Serial.printf("%s/%u SLOT:%s %u.%u\n", n.name, slot + 1,
                n.fault[slot] ? "FAULT" : n.occupied[slot] == 1 ? "OCCUPIED" : "FREE",
                n.distanceMm[slot] / 10, n.distanceMm[slot] % 10);
}

void printStatus() {
  for (auto& n : nodes) {
    if (!n.used) continue;
    printPaired(n);
    Serial.printf("%s %s\n", n.name, n.online ? "ONLINE" : "OFFLINE");
    if (n.role == ROLE_SENSOR && n.online) {
      for (uint8_t slot = 0; slot < n.slotCount; slot++) {
        if (n.occupied[slot] >= 0) printSlot(n, slot);
      }
    }
  }
}

void printDiag(const NodeState& n, const Diag& d, unsigned long rttMs) {
  Serial.printf("DIAG %s rtt=%lu rssi=%d noderssi=%d up=%lu heap=%u reset=%s fails=%lu packets=%lu drops=%u",
                n.name, rttMs, n.rssi, d.rssi, (unsigned long)d.uptimeS, d.freeHeapKb,
                resetReasonName(d.resetReason), (unsigned long)d.sendFailures,
                (unsigned long)n.packets, n.drops);
  if (n.role == ROLE_GATE) Serial.printf(" rc522=%02X", d.rc522);
  if (n.role == ROLE_SENSOR) Serial.printf(" sensors=%u noecho=%04X", d.slotCount, d.noEchoMask);
  Serial.println();
}

void printHubDiag() {
  uint8_t paired = 0;
  for (auto& n : nodes) if (n.used) paired++;
  Serial.printf("DIAG HUB id=%s proto=%u up=%lu heap=%u reset=%s channel=%u nodes=%u fails=%lu\n",
                hubId.c_str(), PROTOCOL_VERSION, millis() / 1000, (unsigned)(ESP.getFreeHeap() / 1024),
                resetReasonName(esp_reset_reason()), WIFI_CHANNEL, paired, (unsigned long)sendFailures());
}

// ── From the nodes ───────────────────────────────────────────────────────────
void noteRequest(const Incoming& in) {
  if (in.packet.role != ROLE_GATE && in.packet.role != ROLE_SENSOR) return;

  // One of ours asking again has lost its memory of us (BOOT held, or
  // reflashed). It is offline until accepted again; its name is kept.
  if (NodeState* known = byMac(in.mac)) {
    if (known->online) {
      known->online = false;
      known->tapPending = false;
      known->forgetSlots();
      Serial.printf("%s OFFLINE\n", known->name);
    }
  }

  Request* slot = nullptr;
  for (auto& r : requests)
    if (r.used && memcmp(r.mac, in.mac, 6) == 0) { slot = &r; break; }
  if (!slot)
    for (auto& r : requests)
      if (!r.used || millis() - r.lastAt > REQUEST_FORGOTTEN_MS) { slot = &r; slot->lastPrintedAt = 0; break; }
  if (!slot) return;

  slot->used = true;
  memcpy(slot->mac, in.mac, 6);
  slot->role = in.packet.role;
  slot->lastAt = millis();
  if (slot->lastPrintedAt == 0 || millis() - slot->lastPrintedAt >= REQUEST_REPRINT_MS) {
    slot->lastPrintedAt = millis();
    Serial.printf("PAIRREQ %s %s\n", macToId(in.mac).c_str(), roleName(in.packet.role));
  }
}

void handlePacket(const Incoming& in) {
  const Packet& p = in.packet;

  if (p.type == MSG_PAIR_REQ) {
    noteRequest(in);
    return;
  }

  NodeState* n = byMac(in.mac);
  if (!n) return;   // Not one of ours.
  NodeState& s = *n;

  s.packets++;
  if (in.rssi != 0) s.rssi = in.rssi;
  s.lastSeen = millis();
  if (!s.online) {
    s.online = true;
    s.anySeq = false;     // It rebooted: its seq started over.
    Serial.printf("%s ONLINE\n", s.name);
  }

  if (s.anySeq && p.seq == s.lastSeq) return;
  s.anySeq = true;
  s.lastSeq = p.seq;

  switch (p.type) {
    case MSG_UID:
      if (s.role != ROLE_GATE) return;
      s.tapPending = true;
      s.tapSeq = p.seq;
      Serial.printf("%s UID:%s\n", s.name, p.uid);
      break;

    case MSG_SLOT: {
      if (s.role != ROLE_SENSOR) return;
      s.slotCount = (p.slotCount < MAX_SLOTS) ? p.slotCount : MAX_SLOTS;
      for (uint8_t slot = 0; slot < s.slotCount; slot++) {
        int8_t occupied = (p.occupiedMask >> slot) & 1;
        bool fault = (p.faultMask >> slot) & 1;
        bool changed = (occupied != s.occupied[slot]) || (fault != s.fault[slot]);
        s.occupied[slot] = occupied;
        s.fault[slot] = fault;
        s.distanceMm[slot] = p.distanceMm[slot];
        if (changed) printSlot(s, slot);   // Heartbeats that change nothing stay quiet.
      }
      break;
    }

    case MSG_PONG:
      if (s.pingPending && p.diag.pingSeq == s.pingSeq) {
        s.pingPending = false;
        printDiag(s, p.diag, millis() - s.pingSentAt);
      }
      break;

    default:  // MSG_HELLO: lastSeen above is all it is for.
      break;
  }
}

void checkForSilentNodes() {
  for (auto& s : nodes) {
    if (s.used && s.pingPending && millis() - s.pingSentAt > PING_TIMEOUT_MS) {
      s.pingPending = false;
      Serial.printf("DIAG %s FAIL NO_REPLY\n", s.name);
    }
    if (s.used && s.online && millis() - s.lastSeen > OFFLINE_AFTER_MS) {
      s.online = false;
      s.drops++;
      s.tapPending = false;
      s.forgetSlots();     // Unknown, not free: a dead sensor proves nothing.
      Serial.printf("%s OFFLINE\n", s.name);
    }
  }
}

// ── From the server ──────────────────────────────────────────────────────────
String readLineIfAny() {
  static String buffer = "";
  while (Serial.available()) {
    char c = (char)Serial.read();
    if (c == '\n') {
      String line = buffer;
      buffer = "";
      line.trim();
      return line;
    }
    if (c != '\r' && buffer.length() < 120) buffer += c;
  }
  return "";
}

void removeNode(NodeState& n, bool tellIt) {
  // Best effort: a board that is off forgets nothing, but can no longer talk
  // to us. Holding its BOOT button 5 s makes it ask to join again.
  if (tellIt) sendConfirmed(n.mac, makePacket(MSG_FORGET, ROLE_HUB, ++mySeq), 2);
  removePeer(n.mac);
  String name = n.name;
  n = NodeState();
  Serial.printf("FORGOT %s\n", name.c_str());
}

void pair(const String& args) {
  int space = args.indexOf(' ');
  String id = space > 0 ? args.substring(0, space) : args;
  String name = space > 0 ? args.substring(space + 1) : "";
  id.trim();
  id.toUpperCase();
  name.trim();
  name.toUpperCase();

  uint8_t mac[6];
  if (!idToMac(id, mac)) { Serial.printf("ERR %s isn't a board id\n", id.c_str()); return; }

  Request* req = nullptr;
  for (auto& r : requests)
    if (r.used && memcmp(r.mac, mac, 6) == 0 && millis() - r.lastAt <= REQUEST_FORGOTTEN_MS) { req = &r; break; }
  if (!req) {
    Serial.printf("ERR %s isn't asking to join. Power it on and wait a few seconds.\n", id.c_str());
    return;
  }
  if (!nameFits(name, req->role)) {
    const char* letter = req->role == ROLE_GATE ? "G" : "S";
    Serial.printf("ERR %s is a %s board: call it %s1 to %s9\n", id.c_str(), roleName(req->role), letter, letter);
    return;
  }

  NodeState* self = byMac(mac);

  // The answer goes out plain: the board doesn't share the key with us yet.
  if (!setPeer(mac, false)) { Serial.printf("ERR %s could not be added\n", id.c_str()); return; }
  if (!sendConfirmed(mac, makePacket(MSG_PAIR_OK, ROLE_HUB, ++mySeq))) {
    if (self) setPeer(mac, true);   // Was ours: stays ours.
    else removePeer(mac);
    Serial.printf("ERR %s didn't answer. Keep it powered near the hub and try again.\n", id.c_str());
    return;
  }

  // A replacement takes the name: the old board with it is removed. The same
  // board under a new name keeps its place.
  NodeState* taken = byName(name);
  if (taken && taken != self) removeNode(*taken, true);

  if (!self) {
    for (auto& s : nodes) if (!s.used) { self = &s; break; }
    if (!self) {
      removePeer(mac);
      Serial.printf("ERR %s: this hub holds %u boards. Remove one first.\n", id.c_str(), MAX_NODES);
      saveNodes();
      return;
    }
    *self = NodeState();
    memcpy(self->mac, mac, 6);
  }

  setPeer(mac, true);
  self->used = true;
  self->role = req->role;
  strncpy(self->name, name.c_str(), NAME_CHARS - 1);
  self->name[NAME_CHARS - 1] = '\0';
  self->online = false;
  self->anySeq = false;
  saveNodes();
  req->used = false;
  printPaired(*self);
}

void forget(const String& name) {
  NodeState* n = byName(name);
  if (!n) { Serial.printf("FORGOT %s\n", name.c_str()); return; }
  removeNode(*n, true);
  saveNodes();
}

// Pings a board. The answer (or NO_REPLY) is printed from the loop.
void diagnose(const String& name) {
  NodeState* n = byName(name);
  if (!n) { Serial.printf("DIAG %s FAIL NOT_PAIRED\n", name.c_str()); return; }

  n->pingSeq = ++mySeq;
  n->pingSentAt = millis();
  if (!sendConfirmed(n->mac, makePacket(MSG_PING, ROLE_HUB, n->pingSeq), 2)) {
    n->pingPending = false;
    Serial.printf("DIAG %s FAIL NOT_DELIVERED\n", n->name);
    return;
  }
  n->pingPending = true;
}

void deliver(NodeState& n, const Packet& packet) {
  if (!sendConfirmed(n.mac, packet)) {
    Serial.printf("%s ERR:NOT_DELIVERED\n", n.name);
  }
}

void handleLine(const String& line) {
  if (line.equalsIgnoreCase("STATUS")) { printStatus(); return; }
  if (line.equalsIgnoreCase("PING")) { Serial.printf("HUB %s %u\n", hubId.c_str(), PROTOCOL_VERSION); return; }
  if (line.startsWith("PAIR ")) { pair(line.substring(5)); return; }
  if (line.startsWith("FORGET ")) { String name = line.substring(7); name.trim(); forget(name); return; }
  if (line.equalsIgnoreCase("DIAG")) { printHubDiag(); return; }
  if (line.startsWith("DIAG ")) { String name = line.substring(5); name.trim(); name.toUpperCase(); diagnose(name); return; }

  int space = line.indexOf(' ');
  NodeState* n = (space > 0) ? byName(line.substring(0, space)) : nullptr;
  if (!n || n->role != ROLE_GATE) {
    Serial.printf("# ERR:UNKNOWN_COMMAND %s\n", line.c_str());
    return;
  }

  String command = line.substring(space + 1);
  command.trim();
  NodeState& s = *n;

  if (command == "CMD:OPEN") {
    deliver(s, makePacket(MSG_OPEN, ROLE_HUB, ++mySeq));
    return;
  }

  if (command.startsWith("RESULT:")) {
    if (!s.tapPending) {
      Serial.printf("# %s: no tap waiting for an answer\n", s.name);
      return;
    }
    String result = command.substring(7);
    Packet p = makePacket(MSG_RESULT, ROLE_HUB, s.tapSeq);   // Echo the tap's seq.
    p.flag = (result == "OPEN" || result == "FREE") ? 1 : 0;
    s.tapPending = false;
    deliver(s, p);
    return;
  }

  Serial.printf("# ERR:UNKNOWN_COMMAND %s\n", line.c_str());
}

// ── Lifecycle ────────────────────────────────────────────────────────────────
void setup() {
  Serial.begin(115200);
  delay(300);
  Serial.println("\n# AimPark ESP-NOW hub");

  if (!begin()) {
    Serial.println("# ESP-NOW failed to start. Reset the board.");
    while (true) delay(1000);
  }
  hubId = selfId();
  setPeer(BROADCAST, false);

  // "-3": protocol 3 keeps names with each board; an older list would be misread.
  prefs.begin("aimpark-hub-3", false);
  loadNodes();

  Serial.printf("# Ready on channel %u. Hub %s, protocol %u.\n", WIFI_CHANNEL, hubId.c_str(), PROTOCOL_VERSION);
  printStatus();
}

void loop() {
  Incoming in;
  while (receive(in)) handlePacket(in);

  checkForSilentNodes();

  String line = readLineIfAny();
  if (line.length() > 0) handleLine(line);

  delay(2);
}
