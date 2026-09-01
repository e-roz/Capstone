# AimPark — ESP32 Gate Integration Guide

**How to connect the RFID gate hardware to the AimPark API.**

Written 2026-07-30, against the API as of Phase 4. The API side is complete and
testable today — you do not need the hardware to verify any of it.

**This guide covers the barrier readers.** The third unit — the reader on the
admin's desk that reads a card during registration — is a different job with
different rules, and lives in [`../firmware/README.md`](../firmware/README.md).
Its key is issued with `gate: 0`, and the entry and exit endpoints below refuse
it: a reader sitting on an open desk must not be able to open a barrier.

---

## 1. How it fits together

```
   RFID card
       │  tap
       ▼
   ┌─────────┐   HTTPS POST + X-Api-Key    ┌──────────┐
   │  ESP32  │ ──────────────────────────► │ AimPark  │
   │ + RC522 │ ◄────────────────────────── │   API    │
   └─────────┘   { result, slotCode, gate } └──────────┘
       │
       ├── barrier servo
       ├── LED / buzzer
       └── LCD  "GATE 2 · G2-M3"
```

The ESP32 does **no decision-making**. It reads a card, reports it, and acts on
the answer. Every rule — is this tag known, is access suspended, which bay to
assign — lives in the API. That keeps firmware small and means policy changes
never require reflashing.

### Why devices do not log in

People sign in and receive a JWT that expires after 60 minutes. A reader has no
operator to sign it in, and there is no refresh flow — an embedded token would
work for exactly one hour and then the barrier would stop, mid-shift, with no
way to recover short of reflashing.

So hardware authenticates with a **long-lived device key** instead: no expiry,
revocable, and scoped so a stolen reader cannot reach user data.

### The gate is not a parameter you send

Each device record stores the gate it is mounted at. The API takes the gate from
**the key you authenticated with**, and ignores any gate in the request body. A
reader bolted to Gate 1 physically cannot report entries at Gate 2, even if its
firmware is wrong or its key is stolen.

---

## 2. Issue a device key

One key per physical reader. Do this once per unit.

**Admin JWT required** — log in as an Admin account first. Devices cannot create
devices.

```bash
curl -X POST https://YOUR-API/api/admin/gate-devices \
  -H "Authorization: Bearer <admin JWT>" \
  -H "Content-Type: application/json" \
  -d '{ "name": "Gate 1 Reader", "gate": 1 }'
```

Response:

```json
{
  "deviceId": "3f2a...",
  "name": "Gate 1 Reader",
  "gate": 1,
  "apiKey": "aimpark_kJ8x2Qm...",
  "warning": "Copy this key now — it is not stored and cannot be shown again."
}
```

> **The key is shown once.** Only a SHA-256 hash is stored, exactly as with a
> password. If you lose it, revoke the device and issue a new one — there is no
> recovery path.

Repeat for Gate 2. You should end up with two keys.

Other admin calls:

| Action | Call |
|---|---|
| List devices | `GET /api/admin/gate-devices` |
| Revoke a key | `POST /api/admin/gate-devices/{deviceId}/revoke` |

The list shows `apiKeyPrefix` (first 12 characters) so you can tell units apart,
and `lastSeenAt` so you can tell whether a reader is still alive.

---

## 3. Test the whole flow before you have hardware

**Do this first.** The ESP32 is an ordinary HTTP client — nothing about it is
special. If curl works, the firmware will work, and when the hardware arrives
you will be debugging only wiring instead of wiring *and* API at once.

### Entry

```bash
curl -X POST https://YOUR-API/api/admin/parking/log-entry \
  -H "X-Api-Key: aimpark_kJ8x2Qm..." \
  -H "Content-Type: application/json" \
  -d '{ "rfidTagId": "04A2B3C4D5" }'
```

```json
{
  "result": "ASSIGNED",
  "message": "Entry logged.",
  "logId": "9c1e...",
  "slotId": "0000...0003",
  "slotCode": "G1-M1",
  "gate": 1
}
```

### Exit

The reader only knows the card, so send the tag — the API finds the open session
itself.

```bash
curl -X POST https://YOUR-API/api/admin/parking/log-exit \
  -H "X-Api-Key: aimpark_kJ8x2Qm..." \
  -H "Content-Type: application/json" \
  -d '{ "rfidTagId": "04A2B3C4D5" }'
```

```json
{
  "result": "EXIT_LOGGED",
  "message": "Exit logged.",
  "paymentId": "7b3d...",
  "amountDue": 22.50
}
```

If both of those work, the integration is proven.

---

## 4. Result codes — the contract

**Branch on `result`, never on `message`.** The message is written for humans and
its wording will change. The codes will not.

### Entry — `POST /api/admin/parking/log-entry`

| `result` | HTTP | Meaning | Suggested behaviour |
|---|---|---|---|
| `ASSIGNED` | 200 | Allocated. Use `slotCode` + `gate` | Open barrier, show slot, green |
| `UNKNOWN_TAG` | 404 | Card not registered | Stay shut, red, "Not registered" |
| `RFID_SUSPENDED` | 400 | Access suspended by a violation | Stay shut, red, "Access suspended" |
| `ALREADY_INSIDE` | 400 | Vehicle already has an open session | Stay shut, amber, "Already inside" |
| `LOT_FULL` | 400 | No compatible bay anywhere | Stay shut, red, "Lot full" |
| `NO_VEHICLE_REGISTERED` | 400 | Account has no vehicle on file | Stay shut, red, "No vehicle" |
| `SLOT_UNAVAILABLE` | 400/404 | Named slot was taken (not used by gates) | Stay shut, red |

### Exit — `POST /api/admin/parking/log-exit`

| `result` | HTTP | Meaning | Suggested behaviour |
|---|---|---|---|
| `EXIT_LOGGED` | 200 | Closed. `amountDue` is the fee | Open barrier, show amount |
| `UNKNOWN_TAG` | 404 | Card not registered | Stay shut, red |
| `LOG_NOT_FOUND` | 404 | No open session for this card | Stay shut, amber, "No entry found" |
| `ALREADY_EXITED` | 400 | Session already closed | Stay shut, amber |

### Transport failures

These are **not** result codes — handle them separately:

| Situation | Meaning |
|---|---|
| HTTP 401 | Key wrong, or revoked |
| No response / timeout | WiFi or server down |

Never fail open. If you cannot reach the API, keep the barrier shut and show a
fault light. An unreadable answer is not permission.

---

## 5. Firmware

Arduino / ESP32 core, using `ArduinoJson` and `HTTPClient`. This is the whole
integration — everything else in your sketch is RFID reading and servo control.

```cpp
#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>

// ── Configuration ────────────────────────────────────────────────────────────
const char* WIFI_SSID     = "your-ssid";
const char* WIFI_PASSWORD = "your-password";

// Use the LAN address of the machine running the API on demo day.
const char* API_BASE = "http://192.168.1.50:5000";

// Issued by POST /api/admin/gate-devices. This unit's gate comes from the key,
// so there is nothing else to configure per gate.
const char* API_KEY = "aimpark_kJ8x2Qm...";

// ── Networking ───────────────────────────────────────────────────────────────
void connectWifi() {
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.printf("\nWiFi up: %s\n", WiFi.localIP().toString().c_str());
}

// Posts a scan and fills `doc` with the reply.
// Returns the HTTP status, or a negative number if the request never completed.
int postScan(const char* path, const char* rfidTag, JsonDocument& doc) {
  if (WiFi.status() != WL_CONNECTED) connectWifi();

  HTTPClient http;
  http.begin(String(API_BASE) + path);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("X-Api-Key", API_KEY);
  http.setTimeout(5000);

  String body = String("{\"rfidTagId\":\"") + rfidTag + "\"}";
  int status = http.POST(body);

  if (status > 0) {
    DeserializationError err = deserializeJson(doc, http.getString());
    if (err) {
      Serial.printf("Bad JSON: %s\n", err.c_str());
      status = -1;
    }
  } else {
    Serial.printf("Request failed: %s\n", http.errorToString(status).c_str());
  }

  http.end();
  return status;
}

// ── Entry gate ───────────────────────────────────────────────────────────────
void handleEntryScan(const char* rfidTag) {
  JsonDocument doc;
  int status = postScan("/api/admin/parking/log-entry", rfidTag, doc);

  // Unreachable or unparseable: never fail open.
  if (status <= 0) { showFault("Gate offline"); return; }
  if (status == 401) { showFault("Device key rejected"); return; }

  const char* result = doc["result"] | "";

  if (strcmp(result, "ASSIGNED") == 0) {
    const char* slot = doc["slotCode"] | "?";
    int gate         = doc["gate"] | 0;
    showAssigned(gate, slot);   // e.g. "GATE 2 · G2-M3"
    openBarrier();
  }
  else if (strcmp(result, "RFID_SUSPENDED") == 0)      showDenied("Access suspended");
  else if (strcmp(result, "UNKNOWN_TAG") == 0)         showDenied("Card not registered");
  else if (strcmp(result, "ALREADY_INSIDE") == 0)      showDenied("Already inside");
  else if (strcmp(result, "LOT_FULL") == 0)            showDenied("Parking full");
  else if (strcmp(result, "NO_VEHICLE_REGISTERED") == 0) showDenied("No vehicle on file");
  else                                                 showDenied("Entry refused");
}

// ── Exit gate ────────────────────────────────────────────────────────────────
void handleExitScan(const char* rfidTag) {
  JsonDocument doc;
  int status = postScan("/api/admin/parking/log-exit", rfidTag, doc);

  if (status <= 0) { showFault("Gate offline"); return; }
  if (status == 401) { showFault("Device key rejected"); return; }

  const char* result = doc["result"] | "";

  if (strcmp(result, "EXIT_LOGGED") == 0) {
    float amount = doc["amountDue"] | 0.0;
    showAmountDue(amount);
    openBarrier();
  }
  else if (strcmp(result, "LOG_NOT_FOUND") == 0)  showDenied("No entry found");
  else if (strcmp(result, "ALREADY_EXITED") == 0) showDenied("Already exited");
  else                                            showDenied("Exit refused");
}
```

`showAssigned`, `showDenied`, `showFault`, `showAmountDue` and `openBarrier` are
yours — LCD, LEDs, buzzer, servo. Nothing above depends on how they are built.

### Reading the tag

Whatever your reader library gives you, format the UID the **same way every
time** and store that string in the user's `RfidTagId` field via the admin
panel. Uppercase hex, no separators, is the usual choice:

```cpp
String uid = "";
for (byte i = 0; i < rfid.uid.size; i++) {
  if (rfid.uid.uidByte[i] < 0x10) uid += "0";
  uid += String(rfid.uid.uidByte[i], HEX);
}
uid.toUpperCase();     // e.g. "04A2B3C4D5"
```

A mismatch here is the most common integration bug: the lookup is a string
comparison, so `04a2b3` and `04:A2:B3` would otherwise be three different cards.

The API now squeezes every UID into this shape on the way in — separators
dropped, uppercased — on both the enrollment scan and the admin panel's assign,
so the two ends agree even if a library changes its formatting. Format it the
same way anyway: matching what is stored keeps serial output readable against
the admin panel.

---

## 6. Two gates

Both readers run **identical firmware**. The only difference is `API_KEY`.

| Unit | Key from | Gate reported |
|---|---|---|
| Gate 1 reader | `{ "name": "Gate 1 Reader", "gate": 1 }` | 1 |
| Gate 2 reader | `{ "name": "Gate 2 Reader", "gate": 2 }` | 2 |

No gate constant in the sketch, no per-unit build. Flash the same binary, change
one string.

Allocation uses the gate to prefer bays at the barrier the driver is actually
standing at, only sending them across when that gate is full for their vehicle:

> `"Gate 1 is full for your vehicle — proceed to Gate 2."`

That message arrives in `message`; the machine-readable half is still
`result: "ASSIGNED"` with `gate: 2`. Show the driver `gate` and `slotCode` —
they need to know they are being sent elsewhere.

---

## 7. Demo day

**Run the API on the LAN, not the cloud.** Venue WiFi is the single biggest risk
to a live demo: if the ESP32 cannot reach the internet, the gate is dead. Running
locally per `HOW_TO_RUN.txt` and pointing `API_BASE` at a LAN address removes the
dependency entirely. It is one string in the firmware.

**Checklist**

- [ ] API reachable from the ESP32's network — `curl` from a laptop on the same WiFi
- [ ] Both device keys issued and flashed
- [ ] Test tags registered to accounts, with a vehicle on each account
- [ ] At least one Car account and one Motorcycle account
- [ ] `RfidTagId` values match the reader's UID format exactly
- [ ] A denial case ready to show — suspend one account so `RFID_SUSPENDED` can be demonstrated
- [ ] Gate 1's motorcycle bays fillable from the admin grid, to demo cross-gate routing

**Fallback:** the admin panel's Parking → Log Entry does everything the gate
does, by hand. If the hardware fails mid-presentation, you can still show the
full flow. Keep the panel open on a second screen.

---

## 8. Security

**TLS.** ESP32 HTTPS needs the server's CA certificate compiled into the
firmware, and breaks whenever that certificate rotates. For a LAN demo, plain
HTTP to a local address is the pragmatic choice — nothing leaves the local
network. If you do go over the internet, use `WiFiClientSecure` with the CA
pinned; `setInsecure()` works but accepts any certificate, so treat it as a
deliberate, documented decision rather than a default.

**Key handling.** The key sits in firmware in clear — unavoidable on a
microcontroller. Mitigations that matter: keys are scoped to gate endpoints
only, revocable in one call, and per-device, so losing one reader does not
compromise the other. Revoke immediately if a unit goes missing.

**What a device key cannot do.** It cannot read user profiles, issue violations,
approve registrations, or create more devices. If a reader is compromised, the
blast radius is entry and exit logging at that one gate.

---

## 9. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| 401 on every request | Key wrong, revoked, or header misspelled | Header is `X-Api-Key`, case-insensitive but exact spelling. Check `GET /api/admin/gate-devices` for `isRevoked` |
| `UNKNOWN_TAG` for a card you registered | UID format mismatch | Print the UID over serial and compare it character-for-character with `RfidTagId` |
| `NO_VEHICLE_REGISTERED` | Account has no vehicle | Complete vehicle registration for that account |
| `LOT_FULL` for a car with bays free | Free bays are motorcycle-only | There are only 4 four-wheel bays total; cars cannot use motorcycle bays |
| `ALREADY_INSIDE` on first scan | An earlier session was never closed | Close it from admin Parking → Log Exit |
| Connection timeout | Wrong `API_BASE`, or ESP32 on another network | `curl` the same URL from a laptop on the ESP32's WiFi |
| Works then stops after ~1 hour | You are sending a JWT, not a device key | Device keys never expire. Use `X-Api-Key`, not `Authorization` |
| 403 `DEVICE_NOT_AT_GATE` | The key belongs to the enrollment desk (`gate: 0`) | Issue a separate key with `gate: 1` or `gate: 2` for a barrier unit |

---

## 10. Endpoint reference

| Endpoint | Auth | Purpose |
|---|---|---|
| `POST /api/admin/parking/log-entry` | Device key **or** Admin/Security JWT | Record entry, get assigned bay |
| `POST /api/admin/parking/log-exit` | Device key **or** Admin/Security JWT | Close session, get fee |
| `POST /api/admin/rfid/scan` | Device key, `gate: 0` only | Report a card at the enrollment desk |
| `GET /api/admin/rfid/last-scan` | Admin JWT only | Read the last card tapped at the desk |
| `POST /api/admin/gate-devices` | Admin JWT only | Register a device, receive its key |
| `GET /api/admin/gate-devices` | Admin JWT only | List devices, prefixes, last seen |
| `POST /api/admin/gate-devices/{id}/revoke` | Admin JWT only | Disable a key |

**Entry request** — `rfidTagId` (gate) or `userId` (panel). `slotId` optional; omit
it for automatic allocation, which is what gates always do. `gate` in the body is
ignored for device callers.

**Exit request** — `rfidTagId` (gate) or `logId` (panel).
