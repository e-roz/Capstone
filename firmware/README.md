# AimPark firmware

Sketches for the ESP32 units, built with [PlatformIO](https://platformio.org/)
in VS Code. One folder per unit, one `[env:...]` in `platformio.ini` per folder.

| Sketch | PlatformIO env | Job |
|---|---|---|
| `aimpark_enroll_reader/` | `enroll_reader` | The reader on the admin's desk. Reads a card during registration so the UID is never typed by hand. |
| `aimpark_gate_reader/` | `gate_reader` | A barrier: RC522 + SG90 servo, plugged by USB into the site server's PC. The server reads it directly (Gate Readers screen) and answers open or shut. See [`../SITE_SERVER.md`](../SITE_SERVER.md) Step 10. |
| `aimpark_espnow_hub/` | `espnow_hub` | The ESP-NOW hub. Plugged by USB into the site server's PC and relays to the wireless nodes. See section 4. |
| `aimpark_espnow_gate/` | `espnow_gate` | A wireless barrier (G1, G2): the same RC522 + servo, talking to the hub over ESP-NOW. |
| `aimpark_espnow_sensor/` | `espnow_sensor` | A wireless slot sensor board (S1, S2): one HC-SR04 per slot, 9 slots each. |

The barrier readers are covered separately in
[`../MD files/ESP32_Gate_Integration.md`](../MD%20files/ESP32_Gate_Integration.md).

---

## Why this reader has no WiFi

Earlier versions of this sketch joined WiFi and POSTed straight to the cloud
API, with the network's SSID/password and a device API key baked into
`secrets.h` at flash time. That meant moving the reader to a different desk or
site meant reflashing it with new credentials.

The board is a classic ESP32, which has no native USB peripheral — it can only
appear as a USB-serial adapter (CP210x/CH340), not a USB keyboard/HID device
(that needs an ESP32-S2/S3). So instead, the reader now does the simplest
thing it can do everywhere: it reads a card and prints the UID over the same
USB-serial connection used to flash it. A small companion script —
[`host_bridge/bridge.py`](host_bridge/bridge.py) — runs on whichever computer
it's plugged into, reads that UID, and POSTs it to the cloud API using *that
computer's* internet connection. The reader itself holds no WiFi credentials
or API key at all now; the bridge script's `config.json` does.

Plugging the reader into a new computer only requires that computer to have
the bridge script's dependencies installed and its `config.json` filled in —
no reflashing.

Chrome and Edge can now open the serial port themselves (Web Serial), so on
those browsers the admin panel reads the reader directly and the bridge isn't
needed at all — see section 3.

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

## 2. PlatformIO setup (flash once)

1. **Extension** — install **PlatformIO IDE** from the VS Code extensions
   marketplace. First launch downloads its toolchain; give it a few minutes.
2. **Open the right folder** — open `firmware/` in VS Code, not the repository
   root. PlatformIO looks for `platformio.ini` in the folder you opened, and
   ours lives in `firmware/`.
3. **Board and libraries** — nothing to install by hand. `platformio.ini`
   already pins the board (`esp32dev`, the "ESP32 Dev Module" of the Arduino
   world) and fetches `MFRC522` on the first build.
4. **USB driver** — if no COM port appears when the board is plugged in,
   install the **CP210x** or **CH340** driver for your board's USB chip. Which
   one depends on the board, not on the ESP32 itself.

Build and upload:

```bash
pio run -e enroll_reader -t upload   # build and flash
pio device monitor -e enroll_reader  # serial monitor, 115200 baud
```

A healthy start looks like:

```
AimPark enrollment reader
Firmware Version: 0x92 = v2.0
Ready. Tap a card.
```

There is nothing to configure on the board itself — no `secrets.h`, no WiFi,
no API key. Once flashed, it stays flashed; only the bridge script below needs
per-computer setup.

## 3. Plug and play in Chrome or Edge (recommended)

No bridge script, no `config.json`, no API key on the desk PC:

1. Plug the reader into the computer by USB.
2. In the admin panel (Chrome or Edge), open **Assign RFID** on a user, or
   issue a visitor pass.
3. Click **Connect reader** and pick the board's port (CP210x / CH340).
4. Tap a card. The field fills at once: one beep if it is free, two if someone
   already holds it, three if the read failed.

The browser reads the board directly over Web Serial, so the tap never goes
through the cloud; only the "who holds this card" check and the final save do.
Chrome remembers the port, so later visits reconnect on their own.

Only one program can hold the port at a time. If Connect says the reader is in
use, close `bridge.py`, the Arduino/PlatformIO Serial Monitor, or another
admin-panel tab. Firefox and Safari don't support Web Serial; use the bridge
below there.

## 3b. Host bridge (other browsers, or entry/exit gate mode)

This is what actually talks to the cloud. Everything under
[`host_bridge/`](host_bridge/):

```bash
cd firmware/host_bridge
pip install -r requirements.txt
cp config.example.json config.json
```

Edit `config.json` — it's git-ignored, since it holds the device API key:

```json
{
  "api_base": "https://your-api.onrender.com",
  "api_key": "aimpark_PASTE_YOUR_KEY_HERE",
  "port": null
}
```

- **`api_base`** — the deployed API's URL. The bridge script runs on this
  computer (not on the ESP32), so if the API is also running on this same
  machine for dev, `"http://localhost:5041"` is correct here. If the API runs
  on a different machine on the LAN, use that machine's IP instead (e.g.
  `"http://192.168.1.50:5041"`).
- **`api_key`** — issued once, with `gate: 0`:

  ```bash
  curl -X POST https://your-api.onrender.com/api/admin/gate-devices \
    -H "Authorization: Bearer <admin JWT>" \
    -H "Content-Type: application/json" \
    -d '{ "name": "Enrollment Desk", "gate": 0 }'
  ```

  Gate `0` means "not on a barrier". The entry and exit endpoints refuse a key
  registered this way, so this reader cannot be used to open a gate. Copy the
  `apiKey` from the response immediately — only its hash is stored, and it is
  never shown again.
- **`port`** — leave `null` to auto-detect. Only set it if the script reports
  more than one candidate serial device plugged in.

Run it:

```bash
python bridge.py
```

```
Connecting to COM3 ...
Connected. Waiting for taps. Ctrl+C to stop.
Card: 04A2B3C4D5
  -> FREE: Card read. Not yet assigned.
```

Leave this running while the reader is in use — it's what turns a tap into a
cloud call. The panel side: open a user, choose **Assign RFID**, *then* tap.
The dialog polls only while it is open, so tapping first shows nothing.

### Standalone `.exe`, no Python required

For a computer that shouldn't need Python installed at all, package the
script once with [PyInstaller](https://pyinstaller.org/):

```bash
cd firmware/host_bridge
pip install pyinstaller
pyinstaller --onefile --name aimpark_rfid_bridge --console bridge.py
```

This produces `dist/aimpark_rfid_bridge.exe` — a single file with Python and
every dependency bundled in (~10 MB). To deploy it to another computer, copy
just two files next to each other anywhere on that machine:

- `aimpark_rfid_bridge.exe`
- `config.json` (copy `config.example.json` next to the `.exe` and fill it in
  — same three fields as above)

Double-click the `.exe` (or run it from a terminal) instead of `python
bridge.py`; everything else about it is identical. It isn't committed to the
repo — rebuild it with the command above whenever `bridge.py` changes.

## 4. ESP-NOW hub and wireless nodes

Five boards in a star. Only the hub has a cable to the server; the gates and
slot sensors reach it by ESP-NOW, encrypted, on WiFi channel 1 (no router
involved).

| Board | MAC | Sketch |
|---|---|---|
| HUB | `20:50:0d:cf:87:18` | `aimpark_espnow_hub` |
| G1 | `58:2a:bd:d0:a3:6c` | `aimpark_espnow_gate` |
| G2 | `20:50:0d:cf:cd:00` | `aimpark_espnow_gate` |
| S1 | `58:2a:bd:d7:5c:fc` | `aimpark_espnow_sensor` |
| S2 | `4c:c3:82:ed:1d:a4` | `aimpark_espnow_sensor` |

The table lives in `lib/AimParkEspNow/src/AimParkEspNow.h`. Each board finds
itself in it by its own MAC, so G1 and G2 get the identical sketch, and a
board flashed with the wrong one says so on the Serial Monitor instead of
joining. Replacing a board means reading its MAC
(`py -m esptool --port COMx read-mac`), editing the table, and reflashing all
five.

**Keys.** The defaults are in the header. For your own, create
`lib/AimParkEspNow/src/AimParkEspNowKeys.h` (git-ignored) defining
`AIMPARK_PMK` and `AIMPARK_LMK`, 16 characters each, then reflash all five.

**Arduino IDE.** The IDE only finds the shared header as a library. Link it in
once, from `firmware/`:

```bash
cmd //c mklink /J "%USERPROFILE%\Documents\Arduino\libraries\AimParkEspNow" "lib\AimParkEspNow"
```

Then open the sketch's `.ino`, board **ESP32 Dev Module**, and upload.

**Slot sensor wiring.** Each sensor board watches several slots, one HC-SR04
per slot, numbered in this order (S1 and S2 are wired the same):

| Slot | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 |
|---|---|---|---|---|---|---|---|---|---|
| `TRIG` | 13 | 5 | 4 | 14 | 2 | 15 | 18 | 19 | 21 |
| `ECHO` | 26 | 25 | 23 | 27 | 32 | 33 | 34 | 35 | 22 |

Every sensor's `VCC` goes to `5V` (VIN) and `GND` to `GND`, and every `ECHO`
goes **through a divider** (ECHO — 1 kΩ — pin — 2 kΩ — GND): ECHO swings to
5 V. The sketch prints every slot's distance once a second; a slot reads
occupied between `MIN_VALID_MM` and `OCCUPIED_MAX_MM` (1–50 mm, sized for the
miniature model). Test with a flat, hard object held level about 3 cm under a
sensor — a hand soaks up the echo and reads as nothing. The gate nodes are
wired exactly like `aimpark_gate_reader`.

**Hub protocol** (USB serial, 115200). Every line names the board it is about:

| Direction | Line | Meaning |
|---|---|---|
| hub → server | `G1 UID:04A1B2C3` | Card tapped at gate 1 |
| server → hub | `G1 RESULT:OPEN` / `G1 RESULT:SHUT` | The answer to that tap |
| server → hub | `G2 CMD:OPEN` | Guard's "Open gate" |
| hub → server | `S1/3 SLOT:OCCUPIED 3.7` / `S1/3 SLOT:FREE 0.0` | Slot 3 on board S1 changed; distance in cm, 0 = nothing in range. Every slot is printed once when its board comes online |
| hub → server | `G1 ONLINE` / `G1 OFFLINE` | Node came up, or missed three heartbeats (≈16 s). A sensor board going offline leaves its slots unknown, not free |
| hub → server | `G1 ERR:NOT_DELIVERED` | A RESULT or CMD didn't reach the node |
| server → hub | `STATUS` | Hub prints every node's state |
| server → hub | `DIAG` | Connection test of the hub: `DIAG HUB id=… proto=3 up=… heap=… reset=… channel=1 nodes=… fails=…` |
| server → hub | `DIAG G1` | Pings G1 over the air: `DIAG G1 rtt=… rssi=… noderssi=… up=… heap=… reset=… fails=… packets=… drops=…`, plus `rc522=92` on a gate (`00`/`FF` = reader not wired) or `sensors=9 noecho=0000` on a sensor board (bit set = that sensor hears nothing), or `DIAG G1 FAIL NOT_PAIRED` / `NOT_DELIVERED` / `NO_REPLY` |
| hub → server | `# ...` | Comments for a person reading the monitor |

`rssi` is how loud the board is at the hub and `noderssi` the hub at the board,
in dBm (below about −80 packets start getting lost); `reset=BROWNOUT` means the
board last restarted from a power dip. The Gate Readers screen runs these as
**Test connection**, and its **Console** shows every line over the cable. A
board on firmware older than the test ignores the ping (`NO_REPLY`): reflash
the hub and every board to get the details.

A gate node shakes its arm if the hub doesn't acknowledge the tap, or if no
answer comes back within 15 s. You can drive the whole thing by hand from the
hub's Serial Monitor (Newline line ending) before the server speaks this
protocol.

Opening the hub's COM port resets it (the USB chip's reset line), so whatever
connects should wait for `# Ready` and then send `STATUS` to catch up. Only one
program can hold a port: if the site server has the hub bound on the Gate
Readers screen, close it before using the Serial Monitor, and never bind a
sensor or gate board plugged in by USB for flashing.

## 5. When it does not work

| What you see | Cause | Fix |
|---|---|---|
| `Error: Unknown environment` | VS Code opened at the repo root | Open `firmware/` itself — that is where `platformio.ini` is |
| Upload hangs at `Connecting....` | Board not in flash mode | Hold **BOOT** while it connects. A data-capable USB cable matters; some are charge-only |
| `Firmware Version: 0x00` or `0xFF` | RC522 not wired or not powered | Recheck SPI pins; confirm `3.3V`, not 5 V. `0x00` is usually a loose `SDA`/`SCK` |
| `Missing config.json` | Template never copied | `cp config.example.json config.json` in `host_bridge/`, then fill it in |
| `No serial ports found` | Reader not plugged in, or driver missing | Install the CP210x/CH340 driver for the board |
| `More than one candidate port` | Multiple serial devices plugged in | Set `"port"` in `config.json` to the right one (e.g. `"COM3"`) |
| `could not reach the API` | Wrong `api_base`, no internet on this computer, or firewall | `curl` the same URL from this computer directly |
| `device key rejected` | Key wrong or revoked | Check `GET /api/admin/gate-devices` for `isRevoked`. Reissue if lost |
| `not allowed to enroll cards` | Key belongs to a barrier reader | Issue a separate key with `gate: 0` |
| `no answer from the bridge script` (on the reader) | `bridge.py` isn't running, or is talking to the wrong port | Start it; check it printed "Connected" |
| Card reads, panel shows nothing | Panel polls only while the Assign dialog is open | Open the dialog first, then tap |
| Same card fires repeatedly | Card left resting on the reader | Expected up to the 3 s cooldown; lift the card off |
