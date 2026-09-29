// AimPark — wireless slot sensor (S1 / S2)
// ESP32 + HC-SR04 ultrasonic sensor looking down (or across) one parking slot.
// Tells the hub when the slot turns occupied or free, and repeats its state
// every few seconds as a heartbeat, so the hub catches up after either one
// restarts.
//
// The same sketch goes on S1 and S2; each works out which slot it is from its
// own MAC (see AimParkEspNow.h).
//
// Wiring (HC-SR04 -> ESP32):
//   VCC  -> 5V (VIN)
//   GND  -> GND
//   TRIG -> GPIO 5
//   ECHO -> GPIO 18 through a divider: ECHO -- 1k -- GPIO 18 -- 2k -- GND.
//           ECHO swings to 5 V and the ESP32's pins take 3.3 V at most.
// The on-board LED (GPIO 2) lights while the slot is occupied.

#include <Arduino.h>
#include <AimParkEspNow.h>

using namespace aimpark;

// ── Pins ─────────────────────────────────────────────────────────────────────
#define PIN_TRIG  5
#define PIN_ECHO  18
#define PIN_LED   2

// ── Detection ────────────────────────────────────────────────────────────────
// Sized for the miniature model. Measure the empty slot and a parked car with
// the Serial Monitor open and set these between the two. The gap between them
// stops a reading that sits right on the line from flipping back and forth.
const int OCCUPIED_BELOW_CM = 10;
const int FREE_ABOVE_CM     = 14;

// A state has to hold for this many readings in a row before it counts, so a
// hand passing over the sensor doesn't book the slot.
const int CONFIRM_READINGS = 3;
const unsigned long MEASURE_EVERY_MS = 200;

// No echo within this long means nothing is in range (about 5 m).
const unsigned long ECHO_TIMEOUT_US = 30000;

Node self = UNKNOWN_NODE;
bool linkUp = false;
uint16_t seq = 0;

bool occupied = false;
int agreeingReadings = 0;
uint16_t lastDistanceCm = 0;

unsigned long lastMeasureAt = 0;
unsigned long lastReportAt = 0;

// ── Sensor ───────────────────────────────────────────────────────────────────
// Distance in cm, or 0 when nothing echoed back.
uint16_t readDistanceCm() {
  digitalWrite(PIN_TRIG, LOW);
  delayMicroseconds(2);
  digitalWrite(PIN_TRIG, HIGH);
  delayMicroseconds(10);
  digitalWrite(PIN_TRIG, LOW);

  unsigned long echoUs = pulseIn(PIN_ECHO, HIGH, ECHO_TIMEOUT_US);
  if (echoUs == 0) return 0;
  return (uint16_t)(echoUs / 58);   // Sound's round trip: 58 us per cm.
}

// ── To the hub ───────────────────────────────────────────────────────────────
void report() {
  Packet p = makePacket(MSG_SLOT, ++seq);
  p.flag = occupied ? 1 : 0;
  p.distanceCm = lastDistanceCm;

  // A report that doesn't get through is repeated by the next heartbeat.
  bool delivered = sendConfirmed(HUB, p);
  lastReportAt = millis();
  if (!delivered) Serial.println("  (hub unreachable; will retry)");
}

void measure() {
  uint16_t cm = readDistanceCm();
  lastDistanceCm = cm;

  bool seesCar  = (cm > 0 && cm < OCCUPIED_BELOW_CM);
  bool seesNone = (cm == 0 || cm > FREE_ABOVE_CM);

  // Readings in the gap between the two thresholds neither confirm nor reset.
  if ((seesCar && !occupied) || (seesNone && occupied)) {
    agreeingReadings++;
  } else if (seesCar || seesNone) {
    agreeingReadings = 0;
  }

  if (agreeingReadings >= CONFIRM_READINGS) {
    occupied = !occupied;
    agreeingReadings = 0;
    digitalWrite(PIN_LED, occupied ? HIGH : LOW);
    Serial.printf("%s %s (%u cm)\n", BOARDS[self].name, occupied ? "OCCUPIED" : "FREE", cm);
    report();
  }
}

// ── Lifecycle ────────────────────────────────────────────────────────────────
void setup() {
  Serial.begin(115200);
  delay(300);
  Serial.println("\nAimPark wireless slot sensor");

  pinMode(PIN_TRIG, OUTPUT);
  pinMode(PIN_ECHO, INPUT);
  pinMode(PIN_LED, OUTPUT);
  digitalWrite(PIN_TRIG, LOW);
  digitalWrite(PIN_LED, LOW);

  self = identifySelf();
  if (self == UNKNOWN_NODE || BOARDS[self].role != ROLE_SENSOR) {
    Serial.printf("This board (%s) is not a slot sensor. It is %s.\n", selfMac().c_str(),
                  self == UNKNOWN_NODE ? "not in AimParkEspNow.h" : BOARDS[self].name);
    Serial.println("Flash the hub or gate sketch onto it instead.");
    return;
  }

  if (!begin() || !addPeer(HUB)) {
    Serial.println("ESP-NOW failed to start. Reset the board.");
    return;
  }
  linkUp = true;
  seq = (uint16_t)esp_random();   // So the hub can't mistake a reboot for a repeat.
  Serial.printf("I am %s. Hub is %s.\n", BOARDS[self].name, macToString(BOARDS[HUB].mac).c_str());

  // Start from what the sensor sees now rather than assuming free.
  uint16_t cm = readDistanceCm();
  lastDistanceCm = cm;
  occupied = (cm > 0 && cm < OCCUPIED_BELOW_CM);
  digitalWrite(PIN_LED, occupied ? HIGH : LOW);
  Serial.printf("Starting %s (%u cm). Ready.\n", occupied ? "OCCUPIED" : "FREE", cm);
  report();
}

void loop() {
  if (!linkUp) {
    delay(1000);
    return;
  }

  if (millis() - lastMeasureAt >= MEASURE_EVERY_MS) {
    lastMeasureAt = millis();
    measure();
  }

  if (millis() - lastReportAt >= HEARTBEAT_MS) {
    report();
  }

  // Nothing from the hub is meant for a sensor; just keep the inbox empty.
  Incoming in;
  while (receive(in)) {}

  delay(5);
}
