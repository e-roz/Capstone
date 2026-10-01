// Copy this file to `secrets.h` in the same folder and fill in the four values.
//
// `secrets.h` is git-ignored: it holds a WiFi password and a device key, and
// this repository is public. This example file is the committed half, so the
// shape of what is needed stays documented without the values leaking.

#pragma once

// ── WiFi ─────────────────────────────────────────────────────────────────────
// The ESP32 is 2.4 GHz only. A 5 GHz network — which most phone hotspots
// default to — will never appear to it, however correct the password is.
#define WIFI_SSID     "your-ssid"
#define WIFI_PASSWORD "your-password"

// ── API ──────────────────────────────────────────────────────────────────────
// The deployed API's URL. Point this at a local machine's LAN address only
// for dev against a locally-run API (e.g. "http://192.168.1.50:5041") — the
// board just needs whatever network has internet, not one matching this
// machine's.
#define API_BASE "https://your-api.onrender.com"

// From POST /api/admin/gate-devices with { "name": "Enrollment Desk", "gate": 0 }.
// Returned once at creation and never again — only its hash is stored.
#define API_KEY "aimpark_PASTE_YOUR_KEY_HERE"
