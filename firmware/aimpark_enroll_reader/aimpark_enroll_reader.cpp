// AimPark — enrollment desk reader
// ESP32 + RC522. Reads a card, posts its UID to the API, lights up the answer.
//
// This unit is NOT a gate. It sits on the admin's desk: when an admin opens
// "Assign RFID" for a user, they tap the card here and the UID appears in the
// dialog. It cannot open a barrier — its key is registered to gate 0, which the
// entry and exit endpoints refuse.
//
// Wiring, libraries and setup: see ../README.md

#include <Arduino.h>
#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <SPI.h>
#include <MFRC522.h>

// ── Configuration ────────────────────────────────────────────────────────────
// The WiFi password and the device key are not kept in this file: it is
// committed, and the repository is public. They live in `secrets.h`, which git
// ignores. Copy `secrets.example.h` next to this sketch as `secrets.h` and fill
// in the four values before building.
#if !__has_include("secrets.h")
#error "Copy secrets.example.h to secrets.h (same folder) and fill in your values."
#endif
#include "secrets.h"

// ── Pins ─────────────────────────────────────────────────────────────────────
#define PIN_RC522_SS   5    // RC522 SDA
#define PIN_RC522_RST  22

// Optional feedback. Comment a line out and its code compiles away.
#define PIN_LED_OK     26   // green
#define PIN_LED_BUSY   27   // amber
#define PIN_BUZZER     25

// ── Behaviour ────────────────────────────────────────────────────────────────
// The RC522 re-reads a card that is still sitting on it many times a second.
// Without this, one tap is dozens of POSTs and the buffer churns.
const unsigned long SAME_CARD_COOLDOWN_MS = 3000;

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

// ── Networking ───────────────────────────────────────────────────────────────
void connectWifi() {
  Serial.printf("WiFi: joining %s", WIFI_SSID);
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.printf("\nWiFi: up, this reader is %s\n", WiFi.localIP().toString().c_str());
}

// Posts one UID. Returns the HTTP status, or a negative number if the request
// never completed. `doc` is filled with the reply when there is one.
int postScan(const String& uid, JsonDocument& doc) {
  if (WiFi.status() != WL_CONNECTED) connectWifi();

  HTTPClient http;
  http.begin(String(API_BASE) + "/api/admin/rfid/scan");
  http.addHeader("Content-Type", "application/json");
  http.addHeader("X-Api-Key", API_KEY);
  http.setTimeout(5000);

  String body = String("{\"rfidTagId\":\"") + uid + "\"}";
  int status = http.POST(body);

  if (status > 0) {
    DeserializationError err = deserializeJson(doc, http.getString());
    if (err) {
      Serial.printf("Bad JSON from API: %s\n", err.c_str());
      status = -1;
    }
  } else {
    Serial.printf("Request failed: %s\n", http.errorToString(status).c_str());
  }

  http.end();
  return status;
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

void handleCard(const String& uid) {
  Serial.printf("Card: %s\n", uid.c_str());

  JsonDocument doc;
  int status = postScan(uid, doc);

  if (status <= 0) {
    Serial.println("  -> could not reach the API");
    signal(false, 3);
    return;
  }
  if (status == 401) {
    Serial.println("  -> device key rejected (wrong, or revoked)");
    signal(false, 3);
    return;
  }
  if (status == 403) {
    Serial.println("  -> this key is not allowed to enroll cards");
    signal(false, 3);
    return;
  }

  const char* result = doc["result"] | "";
  const char* message = doc["message"] | "";
  Serial.printf("  -> %s: %s\n", result, message);

  // FREE and IN_USE both reached the panel — the admin decides what to do with
  // a card that is already held. Only a misread is a failure here.
  if (strcmp(result, "FREE") == 0)         signal(true, 1);
  else if (strcmp(result, "IN_USE") == 0)  signal(true, 2);
  else                                     signal(false, 3);
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

  connectWifi();
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
  lastUidAt = now;

  if (!repeat) {
    clearSignal();
    handleCard(uid);
  }

  rfid.PICC_HaltA();
  rfid.PCD_StopCrypto1();
}
