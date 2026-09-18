# AimPark firmware

Sketches for the ESP32 units, built with [PlatformIO](https://platformio.org/)
in VS Code. One folder per unit, one `[env:...]` in `platformio.ini` per folder.

| Sketch | PlatformIO env | Job |
|---|---|---|
| `aimpark_enroll_reader/` | `enroll_reader` | The reader on the admin's desk. Reads a card during registration so the UID is never typed by hand. |

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

## 3. Host bridge (once per computer the reader plugs into)

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

## 4. When it does not work

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
