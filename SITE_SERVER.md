# AimPark — Site Server (the guard post's own server)

The **site server** is the AimPark API running on a PC at the school, in *Site mode*, with its own local database.

- **It makes every gate decision:** card check, suspension check, plate match, slot, entry/exit log and exit fee. It doesn't need the internet to do that.
- **The cloud (Render + Supabase) keeps everything else:** registration, user data, the mobile app, the admin panel, payments, email and push notifications.

```
 SCHOOL (one PC for the Comlab test)             INTERNET
 ESP32 card reader ──┐                          ┌──────────────────────┐
 ALPR camera app ────┼──► SITE SERVER ◄────────►│ CLOUD API (Render)   │
 Guard's browser ────┘    + local Postgres      │ + Supabase           │
                                                └──────────────────────┘
```

**Contents**
- [Part 1 — Set up and test at the Comlab](#part-1--set-up-and-test-at-the-comlab) ← start here
- [Part 2 — Moving to the real guard PC](#part-2--moving-to-the-real-guard-pc)
- [Part 3 — How it works](#part-3--how-it-works)

---

# Part 1 — Set up and test at the Comlab

Everything runs on **one PC** and talks over `localhost`, so there are no IP addresses or firewall rules to deal with. It takes about 1–2 hours the first time, most of it installing things.

> **Do not change anything in Render's Environment during this test.** In particular, don't set `Site__CloudGateEndpointsEnabled=false`. That is the final switch-over (Part 2). It would lock every Security account out of the Firebase panel.

## Step 0 — Before you leave (on your own PC)

- [ ] **Render has the latest code.** In the Render dashboard the latest deploy should say **Live** for the newest commit on `main`.
- [ ] **Bring the ALPR app.** Copy the folder `alpr-service\dist\AimParkALPR` (or `AimParkALPR.zip`) to a USB drive. It isn't in Git, so it won't come with the code.
- [ ] **Bring the JWT values.** Open Render → your service → **Environment** and copy the values of `Jwt__Key`, plus `Jwt__Issuer` and `Jwt__Audience` if they are set. Keep them private: anyone with `Jwt__Key` can make logins.
- [ ] **Bring:** the ESP32 reader + USB cable, a test RFID card, a webcam if the Comlab PC has none, and a photo of a real plate on your phone (for the camera).

## Step 1 — Install the tools

Install each of these. Use the default options unless a note says otherwise.

| Tool | Where to get it | Notes |
|---|---|---|
| **.NET 8 SDK** | https://dotnet.microsoft.com/download/dotnet/8.0 → *SDK 8.0.x, Windows x64* | |
| **PostgreSQL** (17 or 18) | https://www.postgresql.org/download/windows/ | **Write down the password** you give the `postgres` user. Keep port `5432`. pgAdmin is included. |
| **Git** | https://git-scm.com/download/win | |
| **Python 3.12+** | https://www.python.org/downloads/ | Tick **"Add python.exe to PATH"** on the first screen. Needed for the ESP32 bridge. |
| **ESP32 USB driver** | CP210x: https://www.silabs.com/developer-tools/usb-to-uart-bridge-vcp-drivers · CH340: https://www.wch-ic.com/downloads/CH341SER_EXE.html | Only if Windows doesn't show a COM port when the ESP32 is plugged in. |

Flutter is already on the Comlab PC.

Then open a **new** PowerShell window (so it sees the new tools) and run:

```bash
dotnet tool install --global dotnet-ef --version 8.0.11
```

**Check:** `dotnet --list-sdks` shows an `8.0.x` line, and `dotnet ef --version` prints a version.

## Step 2 — Get the code

```bash
git clone https://github.com/e-roz/Capstone.git C:\AimPark
```

If Git asks you to sign in to GitHub, sign in with the account that can see the repo.

These are the folders you'll use below:

| Folder | What's in it |
|---|---|
| `C:\AimPark\AimPark.API\AimPark.API` | The server |
| `C:\AimPark\aimpark_admin` | The admin web |
| `C:\AimPark\firmware\host_bridge` | The ESP32 bridge |

## Step 3 — Create the local database

1. Open **pgAdmin 4** from the Start menu.
2. On the left: **Servers → PostgreSQL** (enter your `postgres` password).
3. Right-click **Databases → Create → Database…**
4. Name: `AimParkSite` → **Save**.

Leave it empty. Step 6 creates the tables.

## Step 4 — Prepare the cloud side (in the Firebase admin panel, online)

Sign in to the normal admin panel (Firebase) with an **Admin** account.

### 4a. Create three device keys

Go to **Gate Devices → Add device**. Create these three, one at a time:

| Name | Gate number | Device type | Used by |
|---|---|---|---|
| `Comlab Site Server` | `0` | **Site Server** | The site server (Step 5) |
| `Comlab Gate 1 Reader` | `1` | **RFID Reader** | The ESP32 bridge (Step 10) |
| `Comlab Gate 1 Camera` | `1` | **ALPR Camera** | The ALPR app (Step 9) |

> ⚠️ **Each key is shown only once.** Copy it into Notepad right away, labelled. If you lose one, revoke it and create a new one.

The reader and the camera **must both be gate 1.** At entry, a card is only accepted if the camera at the *same gate* saw a matching plate in the last 8 seconds.

### 4b. Prepare the test accounts

| Account | What it needs |
|---|---|
| **A Security account** | A normal staff login with an email and password. The guard post signs in with it, and so does the ALPR app. |
| **A driver (User) account** | Registration approved (*Active*). Has a **vehicle** whose plate matches the photo on your phone, and the **test RFID card** assigned. |

**To get the card's number:** do Step 10 first. It prints `Card: 04A1B2C3` in the window when you tap. Then, in **User Management → the driver → Assign RFID**, **type** that number in and save.

## Step 5 — Fill in the settings file

1. Open `C:\AimPark\AimPark.API\AimPark.API` in File Explorer.
2. Copy `appsettings.Site.example.json` and name the copy **`appsettings.Site.json`**.
3. Open it in Notepad and replace it with this, filling in the `<...>` parts:

```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Host=localhost;Port=5432;Database=AimParkSite;Username=postgres;Password=<your postgres password>"
  },
  "Jwt": {
    "Key": "<Jwt__Key from Render>",
    "Issuer": "AimPark.API",
    "Audience": "AimPark.Client",
    "ExpiryInMinutes": 60
  },
  "Site": {
    "Mode": "Site",
    "CloudBaseUrl": "https://aimpark-api.onrender.com",
    "CloudApiKey": "<the Comlab Site Server key>",
    "AdminWebPath": "C:\\AimPark\\aimpark_admin\\build\\web"
  }
}
```

- If Render has `Jwt__Issuer` or `Jwt__Audience`, use those values instead of the defaults above.
- The `Jwt` values **must match Render exactly**. Otherwise the Notifications screen won't work at the guard post.
- Keep the **double backslashes** `\\` in `AdminWebPath`.
- This file holds secrets. It's git-ignored, so it won't be pushed to GitHub.

## Step 6 — Create the tables

In PowerShell:

```bash
cd C:\AimPark\AimPark.API\AimPark.API
```

```bash
dotnet ef database update -- --environment Site
```

The `-- --environment Site` part makes it use the settings file from Step 5, which points at **your local database**, not Supabase. The first run takes a minute because it builds the code.

**Check:** it ends with `Done.`, and in pgAdmin, **AimParkSite → Schemas → public → Tables** (right-click → Refresh) lists tables such as `Users`, `ParkingLogs` and `SyncOutbox`.

## Step 7 — Build the guard's admin web

```bash
cd C:\AimPark\aimpark_admin
```

```bash
flutter pub get
```

```bash
flutter build web --dart-define=API_BASE_URL=http://localhost:5041
```

**Check:** the folder `C:\AimPark\aimpark_admin\build\web` now exists and has an `index.html`. The server serves it straight from there, so there's nothing to copy.

## Step 8 — Start the site server

Keep this PowerShell window open the whole time. It's the server, and it shows the logs.

```bash
cd C:\AimPark\AimPark.API\AimPark.API
```

```bash
dotnet run --no-launch-profile --environment Site --urls http://0.0.0.0:5041
```

- Wait for `Now listening on: http://0.0.0.0:5041`.
- Keep `--no-launch-profile`. Without it, the server can load developer settings that point at Supabase.
- If Windows Firewall asks, click **Allow** for **private networks**.

**Check:** in a browser, open **http://localhost:5041/api/site/status**. Within about a minute it should show:

```
"mode": "Site",
"cloudConnected": true,
"lastSnapshotAt": "<a time>",
"waitingToSend": 0
```

If `cloudConnected` stays `false` for over a minute, see [Troubleshooting](#troubleshooting). Render's free tier can take about 50 seconds to wake up the first time.

Then open **http://localhost:5041/** and sign in with the **Security** account. This is the guard's admin panel, running from the site server.

## Step 9 — Start the ALPR camera app

1. Copy the `AimParkALPR` folder from your USB drive to `C:\AimParkALPR` and run **`AimParkALPR.exe`**.
2. The first-run window asks for three things:
   - **Device key:** the `Comlab Gate 1 Camera` key
   - **Gate label:** `Gate 1`
   - **Server address:** change it to **`http://localhost:5041`**
3. Sign in with the **Security** account.
4. Point the camera at the plate photo on your phone. The app should show the plate, and its status should say readings are reaching the server.

- **Run it while online the first time.** It may download its plate-reading model.
- **If it opens straight to sign-in with the wrong server** (it was set up on this PC before), delete `%LOCALAPPDATA%\AimParkAlpr\config.json` and start it again.

## Step 10 — Start the ESP32 bridge (the card reader)

Plug in the ESP32. In a **new** PowerShell window:

```bash
cd C:\AimPark\firmware\host_bridge
```

```bash
pip install -r requirements.txt
```

Copy `config.example.json` to **`config.json`**, open it in Notepad and set:

```json
{
  "api_base": "http://localhost:5041",
  "api_key": "<the Comlab Gate 1 Reader key>",
  "port": null,
  "mode": "entry"
}
```

Then start it:

```bash
python bridge.py
```

**Check:** it says `Connected in entry mode. Waiting for taps.`

- If it says **more than one port**, set `"port"` to the right one, e.g. `"COM5"`. Device Manager → *Ports (COM & LPT)* shows which one is the ESP32.
- Close the Arduino or PlatformIO serial monitor first. Only one program can use the port at a time.

`"mode"` decides what a tap means. The same ESP32 stands in for a barrier reader until the real gate firmware exists:

| `mode` | A tap means | Needs a key that is |
|---|---|---|
| `"entry"` | a car entering | RFID Reader, gate 1 or higher |
| `"exit"` | a car leaving | RFID Reader, gate 1 or higher |
| `"enroll"` | the admin's registration desk | RFID Reader, gate 0, with `api_base` set to Render |

The reader answers with **1 beep/green = barrier opens** and **3 beeps/red = stays shut**. The bridge window prints why.

---

## The tests

Tick each one off.

### Test 1 — Guard screens (no hardware)

In the guard panel at http://localhost:5041/, signed in as Security:

- [ ] **Gate Check:** log a manual entry for the test driver → it appears in **active sessions**. Then log the exit.
- [ ] **Visitor Passes:** issue a pass → it appears in the list.
- [ ] **Incidents:** report an incident → it appears in the list, and the **Overview** incident count goes up.
- [ ] Within a few seconds, the entry, exit, visitor pass and incident also appear in the **Firebase** admin panel.

### Test 2 — Camera + card at the "gate"

The bridge is in `"mode": "entry"`.

- [ ] Show the plate photo to the camera, then **tap the card within 8 seconds** → **1 beep**, and the bridge prints `OPEN: Entry logged. Slot …`.
- [ ] Tap again without showing the plate → **3 beeps**, `SHUT … already inside` (the car is already in).
- [ ] Change `"mode"` to `"exit"` in `config.json`, restart `python bridge.py`, and tap → **1 beep**, exit logged. Within a few seconds, the driver's **mobile app → history** shows the session and its fee.
- [ ] Back in `"entry"` mode, tap **without** showing the plate → **3 beeps**. That's correct: no plate read, no entry. The guard panel's **Gate Check** shows the flagged attempt.

### Test 3 — A card change in the cloud reaches the gate instantly

- [ ] In the **Firebase** admin panel: **User Management → the test driver → Revoke RFID**, reason **No longer needed**.
  > ⚠️ Don't pick *Lost* or *Stolen*. Those block the card for good, and you couldn't assign it again.
- [ ] Within about 2 seconds, plate + tap at the "gate" → **3 beeps**, `This card is not registered to an account or a visitor.`
- [ ] **Assign RFID** the same card number to the driver again → the next plate + tap gives **1 beep**.

> The **Suspend** button in User Management blocks the driver's *login*, not their card. The gate only checks the card's own suspension, which comes from violations and starts after the appeal window. So Suspend is not an instant gate test.

### Test 4 — Unplug the internet

1. [ ] Unplug the network cable, or turn off Wi-Fi.
2. [ ] Refresh http://localhost:5041/api/site/status → `cloudConnected` becomes `false`.
3. [ ] With the internet off, do all of these. **Each one works.** (The test car is still inside from Test 3.)
   - In the guard panel's **Gate Check**, log a manual **exit** for the test driver.
   - In the bridge's `"entry"` mode, plate + tap → **1 beep** (the car enters again).
   - Set `"mode": "exit"`, restart the bridge, tap → **1 beep** (the car leaves).
   - In the guard panel, report an incident.
4. [ ] The status page's `waitingToSend` goes **up**. In pgAdmin, the `SyncOutbox` table has rows.
5. [ ] Open **Notifications** in the guard panel → it says it needs the internet. That's expected.
6. [ ] Plug the internet back in. Within about 30 seconds, `cloudConnected` is `true` and `waitingToSend` is back to `0`.
7. [ ] The offline entries, exits and incident now appear in the Firebase admin panel and the driver's mobile app.

## After the test

- **Stop everything:** press `Ctrl+C` in the server window and the bridge window, and close the ALPR app.
- The **test entries, exits and incidents are real records in the cloud** now. Dismiss or clean up the test incident and fee in the Firebase panel if you don't want them in reports.
- **Optional:** to see it start with Windows, do [Part 2, step 1](#1-make-it-start-with-windows).

## Troubleshooting

| What you see | What to do |
|---|---|
| The status page doesn't open | The server isn't running. Look at the server window for a red error, then start it again (Step 8). |
| `cloudConnected: false` while online, for over a minute | 1) Open https://aimpark-api.onrender.com/api/site/status in the browser to wake Render. 2) Check `CloudApiKey` in the settings file is the **Site Server** key. 3) Check `CloudBaseUrl`. Restart the server after any change. |
| `lastSnapshotError` mentions **401** | The Site Server key is wrong or revoked. Make a new one (Step 4a). |
| `lastSnapshotError` mentions **403** | The key isn't a **Site Server** type. Make a new one with the right type. |
| Security login at localhost says *Invalid credentials* | The user copy hasn't arrived yet. Check `lastSnapshotAt` on the status page, and wait a few seconds. Only **staff** accounts can sign in here; drivers can't. |
| Notifications / Gate Devices screen fails **while online** | The `Jwt` values in the settings file don't match Render's exactly. |
| `dotnet ef` says *password authentication failed* | The Postgres password in `appsettings.Site.json` is wrong. |
| `dotnet ef` says *Site mode needs Site:CloudBaseUrl…* | `appsettings.Site.json` is missing or misnamed. It must be exactly that name, in `AimPark.API\AimPark.API`. |
| Bridge: *device key rejected* | Wrong key, or the key was made a few seconds ago and hasn't been copied down yet. Wait and tap again. |
| Bridge: *this key can't be used at a gate* | It's the gate-0 key or the camera key. Use the **Comlab Gate 1 Reader** key. |
| Entry always gives 3 beeps (*plate* or *ALPR* in the message) | Show the plate first, then tap within 8 seconds. The camera key and the reader key must both be **gate 1**, and the plate must be registered to the driver who holds the card. |
| Bridge: *No serial ports found* | Install the USB driver (Step 1) and replug. Try another cable, since some are power-only. |
| The guard panel at localhost is blank or 404 | Step 7 wasn't done, or `AdminWebPath` is wrong. Check the folder exists and restart the server. |

---

# Part 2 — Moving to the real guard PC

Same steps as Part 1, with these differences.

### 1. Make it start with Windows

Instead of `dotnet run`, install it as a service. Open PowerShell with **Run as administrator**:

```bash
powershell -ExecutionPolicy Bypass -File C:\AimPark\site-server\install-service.ps1
```

The script does four things:
- builds the server into `C:\AimPark\site-server-app`;
- installs the Windows service **AimPark Site Server**. It starts when the PC turns on (even with nobody logged in), starts after PostgreSQL, and restarts 5 seconds after a crash;
- allows port 5041 on **private** networks only;
- starts it and checks the status page.

Run it again after pulling new code or changing `appsettings.Site.json`, and it updates in place. `site-server\uninstall-service.ps1` removes it.

If something is wrong, look at:
- the status page;
- **services.msc** → *AimPark Site Server*;
- **Event Viewer** → Windows Logs → Application → source *AimParkSite*.

> Stop the service before running `dotnet run` by hand. Both use port 5041.

### 2. Use the PC's network address instead of `localhost`

The readers, the camera PC and other browsers reach the guard PC over the school network.

1. Run `ipconfig` and note the **IPv4 Address**, e.g. `192.168.1.10`. Ask whoever runs the network to **reserve** that address for this PC, so it never changes.
2. Build the admin web with that address: `flutter build web --dart-define=API_BASE_URL=http://192.168.1.10:5041`
3. Point each device at `http://192.168.1.10:5041`:
   - the ALPR app's *Server address*;
   - the bridge's `api_base`, or the gate readers' URL once their firmware exists.
4. The guard panel is at `http://192.168.1.10:5041/`.

The **enrollment desk reader** stays pointed at Render (`"mode": "enroll"`). Enrollment is registration, so it belongs to the cloud.

### 3. Switch the cloud's gate traffic off (the final switch-over)

Only after **every** reader and camera points at the guard PC, set these in Render → Environment:

```
Site__CloudGateEndpointsEnabled=false
Site__GuardPanelUrl=http://192.168.1.10:5041/
```

From then on, the cloud:
- refuses entry, exit and plate reads, with a message saying to use the guard post's server;
- refuses **Security** sign-ins on the Firebase panel, with "Security accounts sign in at the guard post: http://192.168.1.10:5041/". **Admin sign-in is unchanged.**

**If the guard PC is down:** set `Site__CloudGateEndpointsEnabled=true` again. Guards can then use the Firebase panel, and the cloud takes gate traffic until the guard PC is back.

---

# Part 3 — How it works

## How the two stay in step

| Direction | What | When |
|---|---|---|
| Cloud → site | Users, cards, suspensions, plates, visitor passes, device keys, slots, rates, incidents | **Instantly.** The site keeps a live connection open to the cloud. When the cloud says "changed", the site downloads a fresh full copy. It also downloads on reconnect and every 5 minutes. |
| Site → cloud | Entry/exit logs, plate reads, gate attempts, slot occupancy, exit fees, notifications, incidents reported by guards | **Right after each car moves.** They go through an outbox. If the internet is down, they wait and are sent when it's back. |

## When the internet is down

- Gates keep working from the last copy.
- A suspension made in the cloud during the outage takes effect when the line comes back.
- The guard's gate screens and the **incident queue** keep working. Guards can report incidents offline, and the reports are sent when the internet is back.
- These **need the internet:**
  - attaching photos to a report, and opening photos drivers attached. Offline, a report says how many attachments "can be viewed when the internet is back";
  - the **Gate Devices** and **Notifications** screens.

## Who owns what

- The cloud decides whether a bay is **in service**. The site decides whether a **car is in it**.
- For visitor passes and incidents, the newer edit wins. A guard edits a report while it's still *Submitted*; an admin reviews it in the cloud.
- Payments are created at the site on exit, then settled in the cloud.

## Where the data lives

| | Supabase (cloud) | Local Postgres (guard PC) |
|---|---|---|
| Role | **The main record.** Everything, kept long-term. | **The gate's working copy.** Just what a gate decision needs. |
| People data | Users, registrations, documents, vehicles, violations, payments, notifications | A copy of users, cards, suspensions, plates, visitor passes, slots, rates, incidents |
| Gate history | A full copy, arriving from the guard PC right after each car moves | Where it is first written |
| Read by | Mobile app, admin panel, reports | Gate readers, ALPR app, guard screens |
| If lost | Serious. Restore from backup. | Minor. Reinstall and it downloads everything again. Only records not yet sent are lost, and `/api/site/status` shows how many are waiting. |

Supabase Storage (document and photo files) is unchanged.

## Migration note

The migration `AddSyncOutbox` adds one table, `SyncOutbox`, used only on the site server. Applying it to Supabase creates an empty table the cloud never uses.
