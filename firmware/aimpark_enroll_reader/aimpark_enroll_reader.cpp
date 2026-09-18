// AimPark — enrollment desk reader
// ESP32 + RC522. Reads a card and prints its UID over USB-serial; a small
// companion script on whatever computer it's plugged into forwards it to the
// cloud and prints back the result. See ../host_bridge/ and ../README.md.
//
// This unit is NOT a gate. It sits on the admin's desk: when an admin opens
// "Assign RFID" for a user, they tap the card here and the UID appears in the
// dialog. It cannot open a barrier — the WiFi-based barrier readers are a
// separate sketch/unit, covered in ../MD files/ESP32_Gate_Integration.md.
//
// Why serial instead of WiFi: a classic ESP32 (this board) has no native USB
// peripheral, so it can't emulate a USB keyboard/HID device — only ESP32-S2/S3
// chips can do that. Talking over the same USB-serial link that flashes the
// board gets the same "plug into any computer, no WiFi setup" result without
// new hardware: the board holds no WiFi credentials or API key at all now,
// and moving it to a new desk means running the companion script there once,
// not reflashing it.
//
// Wiring and setup: see ../README.md

#include <Arduino.h>
#include <SPI.h>
#include <MFRC522.h>

// ── Pins ─────────────────────────────────────────────────────────────────────
#define PIN_RC522_SS   5    // RC522 SDA
#define PIN_RC522_RST  22

// Optional feedback. Comment a line out and its code compiles away.
#define PIN_LED_OK     26   // green
#define PIN_LED_BUSY   27   // amber
#define PIN_BUZZER     25

// ── Behaviour ────────────────────────────────────────────────────────────────
// The RC522 re-reads a card that is still sitting on it many times a second.
// Without this, one tap is dozens of scans and the buffer churns.
const unsigned long SAME_CARD_COOLDOWN_MS = 3000;

// How long to wait for the host script to answer a scan before giving up and
// signalling an error. The host call to the cloud can be slow (free-tier API
// hosts sleep when idle), so this is generous.
const unsigned long BRIDGE_RESPONSE_TIMEOUT_MS = 60000;

MFRC522 rfid(PIN_RC522_SS, PIN_RC522_RST);

String lastUid = "";
unsigned long lastUidAt = 0;

// ── Feedback ─────────────────────────────────────────────────────────────────
void signal(bool ok, int beeps) {
#ifdef PIN_LED_OK
  digitalWrite(PIN_LED_OK, ok ? HIGH : LOW);
#endif
#ifdef PIN_LED_BUSY
  digitalWrite(PIN_LED_BUSY, ok ? LOW : HIGH);
#endif
#ifdef PIN_BUZZER
  for (int i = 0; i < beeps; i++) {
    digitalWrite(PIN_BUZZER, HIGH);
    delay(ok ? 80 : 200);
    digitalWrite(PIN_BUZZER, LOW);
    delay(120);
  }
#endif
}

void clearSignal() {
#ifdef PIN_LED_OK
  digitalWrite(PIN_LED_OK, LOW);
#endif
#ifdef PIN_LED_BUSY
  digitalWrite(PIN_LED_BUSY, LOW);
#endif
}

// ── Reading ──────────────────────────────────────────────────────────────────
// Uppercase hex, no separators. This must match how the UID is stored, because
// the gate compares the two as plain strings — "04a2b3" and "04:A2:B3" are the
// same card and three different records. The API normalizes to this shape too,
// so the two ends agree even if a library changes its formatting.
String readUid() {
  String uid = "";
  for (byte i = 0; i < rfid.uid.size; i++) {
    if (rfid.uid.uidByte[i] < 0x10) uid += "0";
    uid += String(rfid.uid.uidByte[i], HEX);
  }
  uid.toUpperCase();
  return uid;
}

// Prints "UID:<uid>" for the host bridge script and waits for its reply, a
// single line "RESULT:<value>" — FREE, IN_USE, INVALID_TAG (mirroring the
// API's RfidScanResponse.Result), or ERROR when the bridge itself couldn't
// reach the cloud or had no key configured. Anything else, or no reply within
// the timeout, is treated the same as ERROR.
void handleCard(const String& uid) {
  Serial.print("UID:");
  Serial.println(uid);

  Serial.setTimeout(BRIDGE_RESPONSE_TIMEOUT_MS);
  String line = Serial.readStringUntil('\n');
  line.trim();

  if (!line.startsWith("RESULT:")) {
    Serial.println("  -> no answer from the bridge script");
    signal(false, 3);
    return;
  }

  String result = line.substring(7);
  Serial.printf("  -> %s\n", result.c_str());

  // FREE and IN_USE both reached the panel — the admin decides what to do with
  // a card that is already held. Only a misread/failure is an error here.
  if (result == "FREE")         signal(true, 1);
  else if (result == "IN_USE")  signal(true, 2);
  else                          signal(false, 3);
}

// ── Lifecycle ────────────────────────────────────────────────────────────────
void setup() {
  Serial.begin(115200);
  delay(300);
  Serial.println("\nAimPark enrollment reader");

#ifdef PIN_LED_OK
  pinMode(PIN_LED_OK, OUTPUT);
#endif
#ifdef PIN_LED_BUSY
  pinMode(PIN_LED_BUSY, OUTPUT);
#endif
#ifdef PIN_BUZZER
  pinMode(PIN_BUZZER, OUTPUT);
#endif
  clearSignal();

  SPI.begin();
  rfid.PCD_Init();
  rfid.PCD_DumpVersionToSerial();   // Prints 0x00 or 0xFF when wiring is wrong.

  Serial.println("Ready. Tap a card.");
}

void loop() {
  if (!rfid.PICC_IsNewCardPresent()) return;
  if (!rfid.PICC_ReadCardSerial()) return;

  String uid = readUid();
  unsigned long now = millis();

  // A card left resting on the reader is one tap, not a stream of them.
  bool repeat = (uid == lastUid) && (now - lastUidAt < SAME_CARD_COOLDOWN_MS);
  lastUid = uid;

  if (!repeat) {
    clearSignal();
    handleCard(uid);
  }

  // Stamped after the tap is handled, not before it. handleCard blocks until
  // the bridge answers or times out, and that alone can outrun the cooldown —
  // the card still resting there would post all over again otherwise.
  lastUidAt = millis();

  rfid.PICC_HaltA();
  rfid.PCD_StopCrypto1();
}
