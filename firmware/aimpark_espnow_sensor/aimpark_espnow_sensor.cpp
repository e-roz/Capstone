// AimPark — wireless slot sensor board
// ESP32 + one HC-SR04 per parking slot, looking down at the slot. Tells the
// hub whenever any slot turns occupied or free, or a sensor stops answering
// (unplugged or broken: its ECHO line never rises), and repeats every slot's state
// every few seconds as a heartbeat, so the hub catches up after either one
// restarts.
//
// The same sketch goes on every sensor board. Which board it is (S1, S2) is
// chosen on the guard panel when it is accepted (see AimParkNode.h): power it
// on and accept it there. Hold BOOT 5 s to unpair. Slot numbers are the order
// of the pin table below, starting at 1: the hub prints S2/3 for the third
// sensor on S2.
//
// GPIO 2 is a TRIG pin here, so this board has no pairing blink: the serial
// monitor says "Not paired yet", and the panel lists it under New boards.
//
// Wiring, per sensor (HC-SR04 -> ESP32):
//   VCC  -> 5V (VIN)          GND -> GND
//   TRIG -> its TRIG pin below
//   ECHO -> its ECHO pin through a divider: ECHO -- 1k -- pin -- 2k -- GND.
//           ECHO swings to 5 V and the ESP32's pins take 3.3 V at most.

#include <Arduino.h>
#include <AimParkNode.h>

using namespace aimpark;

// ── Pins ─────────────────────────────────────────────────────────────────────
// One entry per slot, in slot order. Taken from the bench sketch SENSORS1.4.
// 34 and 35 are input-only, which is fine for ECHO.
const uint8_t SLOT_COUNT = 9;
const uint8_t TRIG_PINS[SLOT_COUNT] = {13, 5, 4, 14, 2, 15, 18, 19, 21};
const uint8_t ECHO_PINS[SLOT_COUNT] = {26, 25, 23, 27, 32, 33, 34, 35, 22};
static_assert(SLOT_COUNT <= MAX_SLOTS, "More slots than a packet carries");

// ── Detection ────────────────────────────────────────────────────────────────
// Sized for the miniature model: a car sits a few cm under the sensor. A
// reading outside this window is noise on the ECHO line or the empty floor,
// and counts as nothing there. Measure an empty and a filled slot with the
// Serial Monitor open and adjust.
const uint16_t MIN_VALID_MM   = 1;
const uint16_t OCCUPIED_MAX_MM = 50;

// Quick to call a slot occupied, slower to call it free, so a dropped echo
// under a parked car doesn't clear it. Counted in full scans of every sensor.
const uint8_t OCCUPIED_CONFIRM_SCANS = 2;
// Three scans (about 1.7 s) still rides out one or two missed echoes while
// a car leaving shows as free quickly enough for the guard.
const uint8_t FREE_CONFIRM_SCANS     = 3;
// A fitted HC-SR04 raises ECHO after every trigger, echo or not; many on the
// model hear nothing back over an empty bay. One whose ECHO never rises this
// many scans in a row (about 3 s) is unplugged or broken: the hub is told,
// and its slot keeps its last state instead of turning free.
const uint8_t FAULT_CONFIRM_SCANS    = 6;

// Sensors fire one at a time with this gap, so one's echo isn't heard by the
// next. A full scan of 9 takes about half a second.
const unsigned long SETTLE_MS = 50;
const unsigned long ECHO_TIMEOUT_US = 10000;
// A fitted sensor raises ECHO once it has sent its burst: the clones on the
// model take about 2.2 ms, echo or not. Not rising by this is no sensor at all.
const unsigned long ECHO_START_US = 10000;

// Prints every slot's distance this often, for setting the window above with
// the Serial Monitor open. 0 turns it off.
const unsigned long PRINT_DISTANCE_EVERY_MS = 1000;

// No LED: GPIO 2 is a TRIG pin on this board.
NodeLink hubLink(ROLE_SENSOR, -1);
bool linkUp = false;

bool occupied[SLOT_COUNT];
uint8_t occupiedStreak[SLOT_COUNT];
uint8_t freeStreak[SLOT_COUNT];
uint8_t missingStreak[SLOT_COUNT];
bool fault[SLOT_COUNT];
uint16_t distanceMm[SLOT_COUNT];

unsigned long lastReportAt = 0;
unsigned long lastPrintAt = 0;

// ── Sensors ──────────────────────────────────────────────────────────────────
// readDistanceMm's answer when the ECHO line never rose: no sensor there.
const uint16_t NO_SENSOR = 0xFFFF;

// Distance in mm, 0 when nothing echoed back in range, or NO_SENSOR.
uint16_t readDistanceMm(uint8_t slot) {
  uint8_t trig = TRIG_PINS[slot];
  uint8_t echo = ECHO_PINS[slot];
  digitalWrite(trig, LOW);
  delayMicroseconds(2);
  digitalWrite(trig, HIGH);
  delayMicroseconds(10);
  digitalWrite(trig, LOW);

  unsigned long triggeredAt = micros();
  while (digitalRead(echo) == LOW)
    if (micros() - triggeredAt > ECHO_START_US) return NO_SENSOR;

  unsigned long roseAt = micros();
  while (digitalRead(echo) == HIGH)
    if (micros() - roseAt > ECHO_TIMEOUT_US) return 0;   // Still waiting: nothing in range.

  unsigned long echoUs = micros() - roseAt;
  uint16_t mm = (uint16_t)(echoUs * 343UL / 2000UL);   // Sound: 0.343 mm/us, there and back.
  return (mm < MIN_VALID_MM) ? 0 : mm;
}

// Reads every sensor once. Returns true if any slot's confirmed state changed.
bool scan() {
  bool changed = false;

  for (uint8_t i = 0; i < SLOT_COUNT; i++) {
    uint16_t mm = readDistanceMm(i);

    // No sensor says nothing about a car, so it counts toward neither streak.
    if (mm == NO_SENSOR) {
      distanceMm[i] = 0;
      if (missingStreak[i] < 255) missingStreak[i]++;
      if (!fault[i] && missingStreak[i] >= FAULT_CONFIRM_SCANS) {
        fault[i] = true;
        changed = true;
        Serial.printf("Slot %u FAULT (sensor not answering)\n", i + 1);
      }
      delay(SETTLE_MS);
      continue;
    }

    distanceMm[i] = mm;
    missingStreak[i] = 0;
    if (fault[i]) {
      fault[i] = false;
      changed = true;
      Serial.printf("Slot %u answering again\n", i + 1);
    }

    bool seesCar = (mm > 0 && mm <= OCCUPIED_MAX_MM);
    if (seesCar) {
      freeStreak[i] = 0;
      if (occupiedStreak[i] < 255) occupiedStreak[i]++;
      if (!occupied[i] && occupiedStreak[i] >= OCCUPIED_CONFIRM_SCANS) {
        occupied[i] = true;
        changed = true;
        Serial.printf("Slot %u OCCUPIED (%u mm)\n", i + 1, mm);
      }
    } else {
      occupiedStreak[i] = 0;
      if (freeStreak[i] < 255) freeStreak[i]++;
      if (occupied[i] && freeStreak[i] >= FREE_CONFIRM_SCANS) {
        occupied[i] = false;
        changed = true;
        Serial.printf("Slot %u FREE\n", i + 1);
      }
    }

    delay(SETTLE_MS);
  }
  return changed;
}

void printDistances() {
  Serial.print(" ");
  for (uint8_t i = 0; i < SLOT_COUNT; i++) {
    if (fault[i])                Serial.printf(" %u:!!", i + 1);
    else if (distanceMm[i] == 0) Serial.printf(" %u:--", i + 1);
    else                    Serial.printf(" %u:%u.%ucm", i + 1, distanceMm[i] / 10, distanceMm[i] % 10);
    Serial.print(occupied[i] ? "*" : " ");
  }
  Serial.println();
}

// For the hub's connection test: the sensors that have stopped answering.
void fillDiagnostics(Diag& diag) {
  diag.slotCount = SLOT_COUNT;
  for (uint8_t i = 0; i < SLOT_COUNT; i++)
    if (fault[i]) diag.noEchoMask |= (uint16_t)1 << i;
}

// ── To the hub ───────────────────────────────────────────────────────────────
void report() {
  Packet p = makePacket(MSG_SLOT, ROLE_SENSOR, hubLink.nextSeq());
  p.slotCount = SLOT_COUNT;
  for (uint8_t i = 0; i < SLOT_COUNT; i++) {
    if (occupied[i]) p.occupiedMask |= (uint16_t)1 << i;
    if (fault[i])    p.faultMask    |= (uint16_t)1 << i;
    p.distanceMm[i] = distanceMm[i];
  }

  // A report that doesn't get through is repeated by the next heartbeat.
  lastReportAt = millis();
  if (!hubLink.paired()) return;
  if (!hubLink.send(p)) Serial.println("  (hub unreachable; will retry)");
}

// ── Lifecycle ────────────────────────────────────────────────────────────────
void setup() {
  Serial.begin(115200);
  delay(300);
  Serial.println("\nAimPark wireless slot sensor board");

  for (uint8_t i = 0; i < SLOT_COUNT; i++) {
    pinMode(TRIG_PINS[i], OUTPUT);
    pinMode(ECHO_PINS[i], INPUT);
    digitalWrite(TRIG_PINS[i], LOW);
    occupied[i] = false;
    occupiedStreak[i] = freeStreak[i] = missingStreak[i] = 0;
    fault[i] = false;
    distanceMm[i] = 0;
  }

  if (!hubLink.begin()) {
    Serial.println("ESP-NOW failed to start. Reset the board.");
    return;
  }
  linkUp = true;
  hubLink.setDiagnostics(fillDiagnostics);
  Serial.printf("Watching %u slots.\n", SLOT_COUNT);

  // Settle on what the sensors see before the first report, rather than
  // telling the hub every slot is free and correcting it a second later.
  // Long enough to catch a sensor that is already unplugged.
  for (uint8_t i = 0; i < FAULT_CONFIRM_SCANS; i++) scan();
  printDistances();
  Serial.println("Ready.");
  report();
}

void loop() {
  if (!linkUp) {
    delay(1000);
    return;
  }

  if (scan()) report();

  if (millis() - lastReportAt >= HEARTBEAT_MS) {
    report();
  }

  if (PRINT_DISTANCE_EVERY_MS > 0 && millis() - lastPrintAt >= PRINT_DISTANCE_EVERY_MS) {
    lastPrintAt = millis();
    printDistances();
  }

  // Nothing from the hub is meant for a sensor; polling handles pairing.
  Incoming in;
  while (hubLink.poll(in)) {}
  if (hubLink.takeJustPaired()) report();
}
