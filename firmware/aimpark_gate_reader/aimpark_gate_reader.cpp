// AimPark — barrier reader (USB, with servo barrier)
// ESP32 + RC522 + SG90 servo(s). Reads a card, prints its UID over USB-serial,
// and waits for the site server to say whether the barrier opens. The server
// makes every decision — card, suspension, plate match, entry or exit, slot —
// so this board holds no list of cards and no settings at all.
//
// It is plugged by USB into the PC running the site server. Which gate it is
// gets chosen there, on the Gate Readers screen, by picking its COM port.
//
// Protocol, one line each way:
//   board  -> server   UID:04A1B2C3
//   server -> board    RESULT:OPEN   (or RESULT:SHUT)
//   server -> board    CMD:OPEN      (the guard's "Open gate" button, any time)
// RESULT:FREE is also taken as open, so host_bridge/bridge.py in "entry" or
// "exit" mode drives this board too.
//
// Wiring (RC522 -> ESP32): SDA 5, SCK 18, MOSI 23, MISO 19, RST 22, 3.3V, GND.
// Servo signal on GPIO 13 (a second arm, if fitted, on GPIO 12). Put a
// 470-1000 uF capacitor across the servo's 5V and GND so its start-up current
// doesn't brown the board out and reset it mid-tap.

#include <Arduino.h>
#include <SPI.h>
#include <MFRC522.h>
#include <ESP32Servo.h>

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

// A refused tap jiggles the arm instead of opening it — this unit has no LED
// or buzzer to say "no".
const int SHAKE_ANGLE_OFFSET = 15;
const int SHAKE_REPEATS      = 2;

// ── Behaviour ────────────────────────────────────────────────────────────────
// The RC522 re-reads a card that is still sitting on it many times a second.
const unsigned long SAME_CARD_COOLDOWN_MS = 3000;

// How long to wait for the server's answer before treating the tap as
// refused. The server answers from its own database, so this is generous.
const unsigned long SERVER_RESPONSE_TIMEOUT_MS = 15000;

MFRC522 rfid(PIN_RC522_SS, PIN_RC522_RST);
Servo servo1;
#ifdef PIN_SERVO_2
Servo servo2;
#endif

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

// ── Commands from the server ─────────────────────────────────────────────────
// Reads one line if a whole one is waiting. Returns "" otherwise.
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
    if (c != '\r') buffer += c;
  }
  return "";
}

// ── Reading ──────────────────────────────────────────────────────────────────
// Uppercase hex, no separators — the same shape the API stores, so the card
// read here matches the one assigned in the admin panel.
String readUid() {
  String uid = "";
  for (byte i = 0; i < rfid.uid.size; i++) {
    if (rfid.uid.uidByte[i] < 0x10) uid += "0";
    uid += String(rfid.uid.uidByte[i], HEX);
  }
  uid.toUpperCase();
  return uid;
}

// Sends the UID and waits for the server's RESULT line. A CMD:OPEN arriving
// meanwhile is still obeyed — the guard's button must never be ignored.
void handleCard(const String& uid) {
  Serial.print("UID:");
  Serial.println(uid);

  unsigned long started = millis();
  while (millis() - started < SERVER_RESPONSE_TIMEOUT_MS) {
    String line = readLineIfAny();
    if (line.length() == 0) {
      delay(5);
      continue;
    }

    if (line == "CMD:OPEN") {
      openGate();
      continue;
    }

    if (line.startsWith("RESULT:")) {
      String result = line.substring(7);
      Serial.printf("  -> %s\n", result.c_str());
      if (result == "OPEN" || result == "FREE") openGate();
      else                                      refuse();
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
  Serial.println("\nAimPark barrier reader");

  ESP32PWM::allocateTimer(0);
  servo1.setPeriodHertz(50);
  servo1.attach(PIN_SERVO_1, 500, 2400);
#ifdef PIN_SERVO_2
  servo2.setPeriodHertz(50);
  servo2.attach(PIN_SERVO_2, 500, 2400);
#endif
  closeGate();

  SPI.begin();
  rfid.PCD_Init();
  rfid.PCD_DumpVersionToSerial();   // Prints 0x00 or 0xFF when wiring is wrong.

  Serial.println("Ready. Tap a card.");
}

void loop() {
  if (gateIsOpen && millis() - gateOpenedAt >= GATE_OPEN_MS) {
    closeGate();
  }

  // The guard's button, while no card is being handled.
  if (readLineIfAny() == "CMD:OPEN") {
    openGate();
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
