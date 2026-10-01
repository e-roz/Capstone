// AimPark — ESP-NOW hub
// Plugged by USB into the site server's PC. Relays between the server and the
// wireless nodes (G1, G2 gates; S1, S2 slot sensors). It decides nothing: the
// server answers every tap, as it does for a USB gate reader.
//
// Protocol, one line each way, every line starting with the board it is about:
//   hub    -> server   G1 UID:04A1B2C3          a card was tapped at gate 1
//   server -> hub      G1 RESULT:OPEN           (or RESULT:SHUT) the answer
//   server -> hub      G2 CMD:OPEN              the guard's "Open gate" button
//   hub    -> server   S1/3 SLOT:OCCUPIED 3.7   slot 3 on board S1 changed;
//   hub    -> server   S1/3 SLOT:FREE 0.0       distance in cm, 0 = nothing in range
//   hub    -> server   G1 ONLINE / G1 OFFLINE   a node came up or went quiet
//   hub    -> server   G1 ERR:NOT_DELIVERED     a RESULT/CMD didn't reach it
//   server -> hub      STATUS                   one line per node, right now
// Lines starting with "#" are for people reading the Serial Monitor.
//
// No wiring: just the USB cable.

#include <Arduino.h>
#include <AimParkEspNow.h>

using namespace aimpark;

struct NodeState {
  bool online = false;
  unsigned long lastSeen = 0;

  bool anySeq = false;       // Drops the duplicates a lost ack can cause.
  uint16_t lastSeq = 0;

  // Gates: the seq of the tap waiting for the server's answer.
  bool tapPending = false;
  uint16_t tapSeq = 0;

  // Sensors: one entry per slot on the board. -1 until the first reading.
  uint8_t slotCount = 0;
  int8_t occupied[MAX_SLOTS];
  uint16_t distanceMm[MAX_SLOTS];

  NodeState() { forgetSlots(); }
  void forgetSlots() {
    slotCount = 0;
    for (uint8_t i = 0; i < MAX_SLOTS; i++) {
      occupied[i] = -1;
      distanceMm[i] = 0;
    }
  }
};

NodeState nodes[NODE_COUNT];
bool isHub = false;
uint16_t mySeq = 0;

// ── To the server ────────────────────────────────────────────────────────────
// Slots are numbered from 1, as printed on the model.
void printSlot(Node n, uint8_t slot) {
  const NodeState& s = nodes[n];
  Serial.printf("%s/%u SLOT:%s %u.%u\n", BOARDS[n].name, slot + 1,
                s.occupied[slot] == 1 ? "OCCUPIED" : "FREE",
                s.distanceMm[slot] / 10, s.distanceMm[slot] % 10);
}

void printStatus() {
  for (uint8_t i = 1; i < NODE_COUNT; i++) {
    Node n = (Node)i;
    Serial.printf("%s %s\n", BOARDS[n].name, nodes[n].online ? "ONLINE" : "OFFLINE");
    if (BOARDS[n].role == ROLE_SENSOR && nodes[n].online) {
      for (uint8_t slot = 0; slot < nodes[n].slotCount; slot++) {
        if (nodes[n].occupied[slot] >= 0) printSlot(n, slot);
      }
    }
  }
}

// ── From the nodes ───────────────────────────────────────────────────────────
void handlePacket(const Incoming& in) {
  Node n = in.from;
  const Packet& p = in.packet;
  NodeState& s = nodes[n];

  if (n == HUB) return;   // Only a board flashed with the wrong sketch.

  s.lastSeen = millis();
  if (!s.online) {
    s.online = true;
    s.anySeq = false;     // It rebooted: its seq started over.
    Serial.printf("%s ONLINE\n", BOARDS[n].name);
  }

  if (s.anySeq && p.seq == s.lastSeq) return;
  s.anySeq = true;
  s.lastSeq = p.seq;

  switch (p.type) {
    case MSG_UID:
      if (BOARDS[n].role != ROLE_GATE) return;
      s.tapPending = true;
      s.tapSeq = p.seq;
      Serial.printf("%s UID:%s\n", BOARDS[n].name, p.uid);
      break;

    case MSG_SLOT: {
      if (BOARDS[n].role != ROLE_SENSOR) return;
      s.slotCount = (p.slotCount < MAX_SLOTS) ? p.slotCount : MAX_SLOTS;
      for (uint8_t slot = 0; slot < s.slotCount; slot++) {
        int8_t occupied = (p.occupiedMask >> slot) & 1;
        bool changed = (occupied != s.occupied[slot]);
        s.occupied[slot] = occupied;
        s.distanceMm[slot] = p.distanceMm[slot];
        if (changed) printSlot(n, slot);   // Heartbeats that change nothing stay quiet.
      }
      break;
    }

    default:  // MSG_HELLO: lastSeen above is all it is for.
      break;
  }
}

void checkForSilentNodes() {
  for (uint8_t i = 1; i < NODE_COUNT; i++) {
    NodeState& s = nodes[i];
    if (s.online && millis() - s.lastSeen > OFFLINE_AFTER_MS) {
      s.online = false;
      s.tapPending = false;
      s.forgetSlots();     // Unknown, not free: a dead sensor proves nothing.
      Serial.printf("%s OFFLINE\n", BOARDS[i].name);
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

void deliver(Node n, const Packet& packet) {
  if (!sendConfirmed(n, packet)) {
    Serial.printf("%s ERR:NOT_DELIVERED\n", BOARDS[n].name);
  }
}

void handleLine(const String& line) {
  if (line.equalsIgnoreCase("STATUS")) {
    printStatus();
    return;
  }

  int space = line.indexOf(' ');
  Node n = (space > 0) ? nodeForName(line.substring(0, space)) : UNKNOWN_NODE;
  if (n == UNKNOWN_NODE || BOARDS[n].role != ROLE_GATE) {
    Serial.printf("# ERR:UNKNOWN_COMMAND %s\n", line.c_str());
    return;
  }

  String command = line.substring(space + 1);
  command.trim();
  NodeState& s = nodes[n];

  if (command == "CMD:OPEN") {
    deliver(n, makePacket(MSG_OPEN, ++mySeq));
    return;
  }

  if (command.startsWith("RESULT:")) {
    if (!s.tapPending) {
      Serial.printf("# %s: no tap waiting for an answer\n", BOARDS[n].name);
      return;
    }
    String result = command.substring(7);
    Packet p = makePacket(MSG_RESULT, s.tapSeq);   // Echo the tap's seq.
    p.flag = (result == "OPEN" || result == "FREE") ? 1 : 0;
    s.tapPending = false;
    deliver(n, p);
    return;
  }

  Serial.printf("# ERR:UNKNOWN_COMMAND %s\n", line.c_str());
}

// ── Lifecycle ────────────────────────────────────────────────────────────────
void setup() {
  Serial.begin(115200);
  delay(300);
  Serial.println("\n# AimPark ESP-NOW hub");

  Node self = identifySelf();
  if (self != HUB) {
    Serial.printf("# This board (%s) is not the hub. It is %s.\n", selfMac().c_str(),
                  self == UNKNOWN_NODE ? "not in AimParkEspNow.h" : BOARDS[self].name);
    Serial.println("# Flash the gate or sensor sketch onto it instead.");
    return;
  }

  if (!begin()) {
    Serial.println("# ESP-NOW failed to start. Reset the board.");
    return;
  }
  for (uint8_t i = 1; i < NODE_COUNT; i++) {
    if (!addPeer((Node)i)) Serial.printf("# Could not add peer %s\n", BOARDS[i].name);
  }

  isHub = true;
  Serial.printf("# Ready on channel %u. Waiting for nodes.\n", WIFI_CHANNEL);
}

void loop() {
  if (!isHub) {
    delay(1000);
    return;
  }

  Incoming in;
  while (receive(in)) handlePacket(in);

  checkForSilentNodes();

  String line = readLineIfAny();
  if (line.length() > 0) handleLine(line);

  delay(2);
}
