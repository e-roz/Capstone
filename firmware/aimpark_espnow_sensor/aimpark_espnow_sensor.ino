// AimPark — wireless slot sensor board (S1 / S2)
// ESP32 + one HC-SR04 per parking slot, looking down at the slot. Tells the
// hub whenever any slot turns occupied or free, and repeats every slot's state
// every few seconds as a heartbeat, so the hub catches up after either one
// restarts.
//
// The same sketch goes on S1 and S2; each works out which board it is from its
// own MAC (see AimParkEspNow.h). Slot numbers are the order of the pin table
// below, starting at 1: the hub prints S2/3 for the third sensor on S2.
//
// Wiring, per sensor (HC-SR04 -> ESP32):
//   VCC  -> 5V (VIN)          GND -> GND
//   TRIG -> its TRIG pin below
//   ECHO -> its ECHO pin through a divider: ECHO -- 1k -- pin -- 2k -- GND.
//           ECHO swings to 5 V and the ESP32's pins take 3.3 V at most.

#include <Arduino.h>
#include <AimParkEspNow.h>

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

// Quick to call a slot occupied, slow to call it free, so one dropped echo
// under a parked car doesn't clear it. Counted in full scans of every sensor.
const uint8_t OCCUPIED_CONFIRM_SCANS = 2;
const uint8_t FREE_CONFIRM_SCANS     = 6;

// Sensors fire one at a time with this gap, so one's echo isn't heard by the
// next. A full scan of 9 takes about half a second.
const unsigned long SETTLE_MS = 50;
const unsigned long ECHO_TIMEOUT_US = 10000;

// Prints every slot's distance this often, for setting the window above with
// the Serial Monitor open. 0 turns it off.
const unsigned long PRINT_DISTANCE_EVERY_MS = 1000;

Node self = UNKNOWN_NODE;
bool linkUp = false;
uint16_t seq = 0;

bool occupied[SLOT_COUNT];
uint8_t occupiedStreak[SLOT_COUNT];
uint8_t freeStreak[SLOT_COUNT];
uint16_t distanceMm[SLOT_COUNT];

unsigned long lastReportAt = 0;
unsigned long lastPrintAt = 0;

// ── Sensors ──────────────────────────────────────────────────────────────────
// Distance in mm, or 0 when nothing echoed back inside the valid window.
uint16_t readDistanceMm(uint8_t slot) {
  uint8_t trig = TRIG_PINS[slot];
  digitalWrite(trig, LOW);
  delayMicroseconds(2);
  digitalWrite(trig, HIGH);
  delayMicroseconds(10);
  digitalWrite(trig, LOW);

  unsigned long echoUs = pulseIn(ECHO_PINS[slot], HIGH, ECHO_TIMEOUT_US);
  if (echoUs == 0) return 0;
  uint16_t mm = (uint16_t)(echoUs * 343UL / 2000UL);   // Sound: 0.343 mm/us, there and back.
  return (mm < MIN_VALID_MM) ? 0 : mm;
}

// Reads every sensor once. Returns true if any slot's confirmed state changed.
bool scan() {
  bool changed = false;

  for (uint8_t i = 0; i < SLOT_COUNT; i++) {
    uint16_t mm = readDistanceMm(i);
    distanceMm[i] = mm;
    bool seesCar = (mm > 0 && mm <= OCCUPIED_MAX_MM);

    if (seesCar) {
      freeStreak[i] = 0;
      if (occupiedStreak[i] < 255) occupiedStreak[i]++;
      if (!occupied[i] && occupiedStreak[i] >= OCCUPIED_CONFIRM_SCANS) {
        occupied[i] = true;
        changed = true;
        Serial.printf("%s/%u OCCUPIED (%u mm)\n", BOARDS[self].name, i + 1, mm);
      }
    } else {
      occupiedStreak[i] = 0;
      if (freeStreak[i] < 255) freeStreak[i]++;
      if (occupied[i] && freeStreak[i] >= FREE_CONFIRM_SCANS) {
        occupied[i] = false;
        changed = true;
        Serial.printf("%s/%u FREE\n", BOARDS[self].name, i + 1);
      }
    }

    delay(SETTLE_MS);
  }
  return changed;
}

void printDistances() {
  Serial.print(" ");
  for (uint8_t i = 0; i < SLOT_COUNT; i++) {
    if (distanceMm[i] == 0) Serial.printf(" %u:--", i + 1);
    else                    Serial.printf(" %u:%u.%ucm", i + 1, distanceMm[i] / 10, distanceMm[i] % 10);
    Serial.print(occupied[i] ? "*" : " ");
  }
  Serial.println();
}

// ── To the hub ───────────────────────────────────────────────────────────────
void report() {
  Packet p = makePacket(MSG_SLOT, ++seq);
  p.slotCount = SLOT_COUNT;
  for (uint8_t i = 0; i < SLOT_COUNT; i++) {
    if (occupied[i]) p.occupiedMask |= (uint16_t)1 << i;
    p.distanceMm[i] = distanceMm[i];
  }

  // A report that doesn't get through is repeated by the next heartbeat.
  bool delivered = sendConfirmed(HUB, p);
  lastReportAt = millis();
  if (!delivered) Serial.println("  (hub unreachable; will retry)");
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
    occupiedStreak[i] = freeStreak[i] = 0;
    distanceMm[i] = 0;
  }

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
  Serial.printf("I am %s with %u slots. Hub is %s.\n", BOARDS[self].name, SLOT_COUNT,
                macToString(BOARDS[HUB].mac).c_str());

  // Settle on what the sensors see before the first report, rather than
  // telling the hub every slot is free and correcting it a second later.
  for (uint8_t i = 0; i < FREE_CONFIRM_SCANS; i++) scan();
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

  // Nothing from the hub is meant for a sensor; just keep the inbox empty.
  Incoming in;
  while (receive(in)) {}
}
