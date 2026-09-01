# AimPark firmware

Sketches for the ESP32 units, built with [PlatformIO](https://platformio.org/)
in VS Code. One folder per unit, one `[env:...]` in `platformio.ini` per folder.

| Sketch | PlatformIO env | Job |
|---|---|---|
| `aimpark_enroll_reader/` | `enroll_reader` | The reader on the admin's desk. Reads a card during registration so the UID is never typed by hand. |

The barrier readers are covered separately in
[`../MD files/ESP32_Gate_Integration.md`](../MD%20files/ESP32_Gate_Integration.md).

---

## 1. Wiring — ESP32 to RC522

The RC522 is a **3.3 V** part. Its `3.3V` pin goes to the ESP32's `3V3`, never
to `VIN` or `5V` — 5 V will kill the module, usually not immediately, which is
worse than if it did.

| RC522 pin | ESP32 pin | Note |
|---|---|---|
| `SDA` (SS) | `GPIO 5` | Chip select |
| `SCK` | `GPIO 18` | SPI clock |
| `MOSI` | `GPIO 23` | |
| `MISO` | `GPIO 19` | |
| `IRQ` | — | Leave unconnected; the sketch polls |
| `GND` | `GND` | |
| `RST` | `GPIO 22` | |
| `3.3V` | `3V3` | **Not 5V** |

These are the ESP32's default VSPI pins, and they are the same on the 30-pin and
38-pin DevKit boards. If your board's silkscreen numbers differ, go by the GPIO
number, not by position.

Optional feedback parts, all defined at the top of the sketch and safe to leave
out — comment out the `#define` and that code disappears:

| Part | ESP32 pin | Wiring |
|---|---|---|
| Green LED | `GPIO 26` | LED in series with a 220 Ω resistor to `GND` |
| Amber LED | `GPIO 27` | same |
| Buzzer | `GPIO 25` | Active buzzer, `+` to the pin, `−` to `GND` |

## 2. PlatformIO setup

1. **Extension** — install **PlatformIO IDE** from the VS Code extensions
   marketplace. First launch downloads its toolchain; give it a few minutes.
2. **Open the right folder** — open `firmware/` in VS Code, not the repository
   root. PlatformIO looks for `platformio.ini` in the folder you opened, and
   ours lives in `firmware/`.
3. **Board and libraries** — nothing to install by hand. `platformio.ini`
   already pins the board (`esp32dev`, the "ESP32 Dev Module" of the Arduino
   world) and fetches `MFRC522` and `ArduinoJson` v7 on the first build.
4. **USB driver** — if no COM port appears when the board is plugged in,
   install the **CP210x** or **CH340** driver for your board's USB chip. Which
   one depends on the board, not on the ESP32 itself.

## 3. Configure the sketch

Credentials are not in the sketch. Copy the template next to it:

```bash
cd firmware/aimpark_enroll_reader
cp secrets.example.h secrets.h
```

`secrets.h` is git-ignored — it holds a WiFi password and a device key, and this
repository is public. Building without it fails with a message telling you to
make it. Open it and set four values:

```cpp
#define WIFI_SSID     "your-ssid"
#define WIFI_PASSWORD "your-password"
#define API_BASE      "http://192.168.1.50:5041"
#define API_KEY       "aimpark_..."
```

**`API_BASE`** is the LAN address of the machine running the API — `ipconfig` on
that machine, take the IPv4 address. Not `localhost`, which from the ESP32's
point of view means the ESP32. Port `5041` is what the API's `http` launch
profile binds; it already listens on `0.0.0.0`, so it is reachable from the LAN.

**`API_KEY`** is issued once, with `gate: 0`:

```bash
curl -X POST http://192.168.1.50:5041/api/admin/gate-devices \
  -H "Authorization: Bearer <admin JWT>" \
  -H "Content-Type: application/json" \
  -d '{ "name": "Enrollment Desk", "gate": 0 }'
```

Gate `0` means "not on a barrier". The entry and exit endpoints refuse a key
registered this way, so the reader sitting on an open desk cannot be used to
open a gate. Copy the `apiKey` from the response immediately — only its hash is
stored, and it is never shown again.

## 4. Build, upload, watch

From the PlatformIO toolbar, or from a terminal in `firmware/`:

```bash
pio run -e enroll_reader -t upload   # build and flash
pio device monitor -e enroll_reader  # serial monitor, 115200 baud
```

A healthy start looks like:

```
AimPark enrollment reader
Firmware Version: 0x92 = v2.0
WiFi: joining STI-Baliuag....
WiFi: up, this reader is 192.168.1.77
Ready. Tap a card.
```

Tap a card:

```
Card: 04A2B3C4D5
  -> FREE: Card read. Not yet assigned.
```

The panel side: open a user, choose **Assign RFID**, *then* tap. The dialog
polls only while it is open, so tapping first shows nothing.

## 5. When it does not work

| What you see | Cause | Fix |
|---|---|---|
| `#error` about `secrets.h` | Template never copied | `cp secrets.example.h secrets.h` in the sketch folder |
| `Error: Unknown environment` | VS Code opened at the repo root | Open `firmware/` itself — that is where `platformio.ini` is |
| Upload hangs at `Connecting....` | Board not in flash mode | Hold **BOOT** while it connects. A data-capable USB cable matters; some are charge-only |
| `Firmware Version: 0x00` or `0xFF` | RC522 not wired or not powered | Recheck SPI pins; confirm `3.3V`, not 5 V. `0x00` is usually a loose `SDA`/`SCK` |
| WiFi dots forever | Wrong password, or a 5 GHz network | ESP32 is 2.4 GHz only. Phone hotspots often default to 5 GHz |
| `could not reach the API` | Wrong `API_BASE`, different network, or firewall | `curl` the same URL from a laptop on the reader's WiFi. Windows Firewall blocks inbound on new networks by default |
| `device key rejected` | Key wrong or revoked | Check `GET /api/admin/gate-devices` for `isRevoked`. Reissue if lost |
| `not allowed to enroll cards` | Key belongs to a barrier reader | Issue a separate key with `gate: 0` |
| Card reads, panel shows nothing | Panel polls only while the Assign dialog is open | Open the dialog first, then tap |
| Same card fires repeatedly | Card left resting on the reader | Expected up to the 3 s cooldown; lift the card off |
