"""AimPark enrollment reader — host bridge.

Runs on whatever computer the reader is plugged into. The reader itself holds
no WiFi credentials or API key anymore (see ../aimpark_enroll_reader.cpp) — it
just reads cards and prints "UID:<uid>" over USB-serial. This script watches
that serial port, POSTs each UID to the cloud API using this computer's own
network connection, and writes back "RESULT:<value>" so the reader can light
up and beep.

Config (api_base, api_key) lives in config.json next to this script (or next
to aimpark_rfid_bridge.exe, when running as the packaged build), which is
git-ignored — copy config.example.json and fill it in once per computer.
"""

import json
import sys
import time
from pathlib import Path

import requests
import serial
from serial.tools import list_ports

# Python fully buffers stdout/stderr whenever they aren't an interactive
# console (piped to a log file, a scheduled task, etc.) — without this, output
# only appears in chunks whenever the buffer fills, not as each line happens.
sys.stdout.reconfigure(line_buffering=True)
sys.stderr.reconfigure(line_buffering=True)

# PyInstaller's --onefile build unpacks to a temp dir at runtime, so __file__
# points there, not at the .exe's own folder. sys.executable is the .exe
# itself in that case, so config.json is found next to whichever one the
# person actually has on disk.
APP_DIR = Path(sys.executable).parent if getattr(sys, "frozen", False) else Path(__file__).parent
CONFIG_PATH = APP_DIR / "config.json"

# USB-serial chips typically found on ESP32 dev boards, used to pick the
# reader automatically when more than one serial device is plugged in.
KNOWN_CHIP_HINTS = ("cp210", "ch340", "silicon labs", "usb-serial", "usb2.0-serial")


def load_config():
    if not CONFIG_PATH.exists():
        sys.exit(
            f"Missing {CONFIG_PATH}.\n"
            "Copy config.example.json to config.json next to this script and fill in "
            "api_base and api_key."
        )
    config = json.loads(CONFIG_PATH.read_text())
    for key in ("api_base", "api_key"):
        if not config.get(key):
            sys.exit(f'config.json is missing "{key}"')
    return config


def find_port(preferred=None):
    ports = list(list_ports.comports())

    if preferred:
        for p in ports:
            if p.device == preferred:
                return p.device
        sys.exit(f"Configured port {preferred} not found. Available: {[p.device for p in ports]}")

    if not ports:
        sys.exit("No serial ports found. Is the reader plugged in?")

    likely = [p for p in ports if any(hint in (p.description or "").lower() for hint in KNOWN_CHIP_HINTS)]
    candidates = likely or ports

    if len(candidates) > 1:
        print("Multiple serial devices found:")
        for p in candidates:
            print(f"  {p.device}  {p.description}")
        sys.exit('More than one candidate port — set "port" in config.json to pick one.')

    return candidates[0].device


def scan_card(api_base, api_key, uid):
    """POSTs one UID to the cloud. Returns the RESULT value to send back to the reader."""
    try:
        response = requests.post(
            f"{api_base}/api/admin/rfid/scan",
            json={"rfidTagId": uid},
            headers={"X-Api-Key": api_key},
            timeout=45,
        )
    except requests.RequestException as exc:
        print(f"  -> could not reach the API: {exc}")
        return "ERROR"

    if response.status_code == 401:
        print("  -> device key rejected (wrong, or revoked)")
        return "ERROR"
    if response.status_code == 403:
        print("  -> this key is not allowed to enroll cards")
        return "ERROR"
    if not response.ok:
        print(f"  -> HTTP {response.status_code}")
        return "ERROR"

    try:
        body = response.json()
    except ValueError:
        print("  -> bad JSON from API")
        return "ERROR"

    result = body.get("result", "")
    message = body.get("message", "")
    if not result:
        print(f"  -> HTTP {response.status_code}, no result in the reply")
        return "ERROR"

    print(f"  -> {result}: {message}")
    return result


def run(config):
    port = find_port(config.get("port"))
    print(f"Connecting to {port} ...")

    with serial.Serial(port, 115200, timeout=1) as ser:
        # The board resets when the serial port opens; give it a moment to boot
        # so its startup banner doesn't get mistaken for a stale UID line.
        time.sleep(2)
        ser.reset_input_buffer()
        print("Connected. Waiting for taps. Ctrl+C to stop.")

        while True:
            line = ser.readline().decode("utf-8", errors="replace").strip()
            if not line:
                continue

            if not line.startswith("UID:"):
                print(f"[reader] {line}")
                continue

            uid = line[len("UID:"):]
            print(f"Card: {uid}")
            result = scan_card(config["api_base"], config["api_key"], uid)
            ser.write(f"RESULT:{result}\n".encode("utf-8"))


def main():
    config = load_config()
    while True:
        try:
            run(config)
        except serial.SerialException as exc:
            print(f"Serial error ({exc}); retrying in 3s ...")
            time.sleep(3)
        except KeyboardInterrupt:
            print("\nStopped.")
            break


if __name__ == "__main__":
    main()
