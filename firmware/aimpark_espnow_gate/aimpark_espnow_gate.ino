// AimPark — wireless gate node (G1 / G2)
// ESP32 + RC522 + SG90 servo(s), talking to the hub over ESP-NOW instead of a
// USB cable. Same job as aimpark_gate_reader: read a card, pass the UID on,
// open or shake the barrier on the server's answer. This board decides nothing.
//
// The same sketch goes on G1 and G2; each works out which gate it is from its
// own MAC (see AimParkEspNow.h).
//
// Wiring (RC522 -> ESP32): SDA 5, SCK 18, MOSI 23, MISO 19, RST 22, 3.3V, GND.
// Servo signal on GPIO 13 (a second arm, if fitted, on GPIO 12). Put a
// 470-1000 uF capacitor across the servo's 5V and GND so its start-up current
// doesn't brown the board out and reset it mid-tap.

#include <Arduino.h>
#include <SPI.h>
#include <MFRC522.h>
#include <ESP32Servo.h>
#include <AimParkEspNow.h>

using namespace aimpark;

// ── Pins ─────────────────────────────────────────────────────────────────────
#define PIN_RC522_SS   5    // RC522 SDA
#define PIN_RC522_RST  22
#define PIN_SERVO_1    13
// Second barrier arm. Comment out if the gate has only one servo.
#define PIN_SERVO_2    12

// ── Barrier ──────────────────────────────────────────────────────────────────
const int GATE_CLOSED_ANGLE = 0;
const int GATE_OPEN_ANGLE   = 90;
const unsigned long GATE_OPEN_MS = 3000;

const int SHAKE_ANGLE_OFFSET = 15;
const int SHAKE_REPEATS      = 2;

// ── Behaviour ────────────────────────────────────────────────────────────────
const unsigned long SAME_CARD_COOLDOWN_MS = 3000;

// How long to wait for the server's answer, relayed by the hub, before
// treating the tap as refused.
const unsigned long SERVER_RESPONSE_TIMEOUT_MS = 15000;

MFRC522 rfid(PIN_RC522_SS, PIN_RC522_RST);
Servo servo1;
#ifdef PIN_SERVO_2
Servo servo2;
#endif

Node self = UNKNOWN_NODE;
bool linkUp = false;
uint16_t seq = 0;
unsigned long lastHelloAt = 0;

String lastUid = "";
unsigned long lastUidAt = 0;

bool gateIsOpen = false;
unsigned long gateOpenedAt = 0;

// ── Barrier ──────────────────────────────────────────────────────────────────
void moveArms(int angle) {
  servo1.write(angle);
#ifdef PIN_SERVO_2
  servo2.write(angle);
#endif
}

void openGate() {
  moveArms(GATE_OPEN_ANGLE);
  gateIsOpen = true;
  gateOpenedAt = millis();
  Serial.println("Gate opened.");
}

void closeGate() {
  moveArms(GATE_CLOSED_ANGLE);
  gateIsOpen = false;
  Serial.println("Gate closed.");
}

void refuse() {
  if (gateIsOpen) return;   // Never shake an arm that a car may be under.
  for (int i = 0; i < SHAKE_REPEATS; i++) {
    moveArms(GATE_CLOSED_ANGLE + SHAKE_ANGLE_OFFSET);
    delay(150);
    moveArms(GATE_CLOSED_ANGLE);
    delay(150);
  }
}

// ── From the hub ─────────────────────────────────────────────────────────────
// Handles one packet. Returns true when it was the answer to tap `waitingSeq`,
// with `opened` set to what the server said.
bool handlePacket(const Incoming& in, bool waiting, uint16_t waitingSeq, bool& opened) {
  if (in.from != HUB) return false;   // Only the hub gives orders.

  if (in.packet.type == MSG_OPEN) {
    Serial.println("Opened by the guard.");
    openGate();
    return false;
  }

  if (in.packet.type == MSG_RESULT && waiting && in.packet.seq == waitingSeq) {
    opened = in.packet.flag == 1;
    return true;
  }
  return false;   // A late answer to an earlier tap: ignore it.
}

void checkHub() {
  Incoming in;
  bool unused;
  while (receive(in)) handlePacket(in, false, 0, unused);
}

void sendHello() {
  sendConfirmed(HUB, makePacket(MSG_HELLO, ++seq), 1);
  lastHelloAt = millis();
}

// ── Reading ──────────────────────────────────────────────────────────────────
// Uppercase hex, no separators — the same shape the API stores.
String readUid() {
  String uid = "";
  for (byte i = 0; i < rfid.uid.size; i++) {
    if (rfid.uid.uidByte[i] < 0x10) uid += "0";
    uid += String(rfid.uid.uidByte[i], HEX);
  }
  uid.toUpperCase();
  return uid;
}

void handleCard(const String& uid) {
  Serial.printf("Card %s\n", uid.c_str());

  Packet p = makePacket(MSG_UID, ++seq);
  strncpy(p.uid, uid.c_str(), UID_CHARS);

  if (!sendConfirmed(HUB, p)) {
    Serial.println("  -> hub unreachable");
    refuse();
    return;
  }
  lastHelloAt = millis();   // The tap counts as a check-in.

  unsigned long started = millis();
  while (millis() - started < SERVER_RESPONSE_TIMEOUT_MS) {
    Incoming in;
    bool opened = false;
    if (!receive(in)) {
      delay(5);
      continue;
    }
    if (handlePacket(in, true, p.seq, opened)) {
      Serial.printf("  -> %s\n", opened ? "OPEN" : "SHUT");
      if (opened) openGate();
      else        refuse();
      return;
    }
  }

  Serial.println("  -> no answer from the server");
  refuse();
}

// ── Lifecycle ────────────────────────────────────────────────────────────────
void setup() {
  Serial.begin(115200);
  delay(300);
  Serial.println("\nAimPark wireless gate node");

  ESP32PWM::allocateTimer(0);
  servo1.setPeriodHertz(50);
  servo1.attach(PIN_SERVO_1, 500, 2400);
#ifdef PIN_SERVO_2
  servo2.setPeriodHertz(50);
  servo2.attach(PIN_SERVO_2, 500, 2400);
#endif
  closeGate();

  self = identifySelf();
  if (self == UNKNOWN_NODE || BOARDS[self].role != ROLE_GATE) {
    Serial.printf("This board (%s) is not a gate node. It is %s.\n", selfMac().c_str(),
                  self == UNKNOWN_NODE ? "not in AimParkEspNow.h" : BOARDS[self].name);
    Serial.println("Flash the hub or sensor sketch onto it instead.");
    return;
  }

  if (!begin() || !addPeer(HUB)) {
    Serial.println("ESP-NOW failed to start. Reset the board.");
    return;
  }
  linkUp = true;
  seq = (uint16_t)esp_random();   // So the hub can't mistake a reboot for a repeat.
  Serial.printf("I am %s. Hub is %s.\n", BOARDS[self].name, macToString(BOARDS[HUB].mac).c_str());

  SPI.begin();
  rfid.PCD_Init();
  rfid.PCD_DumpVersionToSerial();   // Prints 0x00 or 0xFF when wiring is wrong.

  sendHello();
  Serial.println("Ready. Tap a card.");
}

void loop() {
  if (!linkUp) {
    delay(1000);
    return;
  }

  if (gateIsOpen && millis() - gateOpenedAt >= GATE_OPEN_MS) {
    closeGate();
  }

  checkHub();

  if (millis() - lastHelloAt >= HEARTBEAT_MS) {
    sendHello();
  }

  if (!rfid.PICC_IsNewCardPresent()) return;
  if (!rfid.PICC_ReadCardSerial()) return;

  String uid = readUid();
  unsigned long now = millis();

  // A card left resting on the reader is one tap, not a stream of them.
  bool repeat = (uid == lastUid) && (now - lastUidAt < SAME_CARD_COOLDOWN_MS);
  lastUid = uid;

  if (!repeat) {
    handleCard(uid);
  }

  // Stamped after the tap is handled, so the wait for the server doesn't eat
  // the cooldown and re-send a card that is still resting there.
  lastUidAt = millis();

  rfid.PICC_HaltA();
  rfid.PCD_StopCrypto1();
}
