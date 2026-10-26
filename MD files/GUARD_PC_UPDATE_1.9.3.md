# Updating the guard PC to 1.9.3 (com lab)

For the day you are at the com lab with the real guard PC, the gate reader and the sensors. Nothing here has been done yet: **1.9.3 is not built or published**, and the guard PC is still on **1.9.2**.

Written 2026-10-26. The full background is in `SITE_SERVER.md` ("The easy way: AimParkSetup.exe").

## Do you actually need this?

Not for the bay-confirm feature. That runs in the cloud (API, phone app and admin site), which are already live. Update the guard PC when you want it to carry everything else merged since 1.9.2 (14 Oct), listed below.

## What 1.9.3 contains that 1.9.2 does not

Merged to `main` since the `site-installer-v1.9.2` tag:

- **E-bike registration, document expiry tracking, renewals, and flagged gate blocking** (#65). The gate block for expired documents is **off by default**: `Gate:EnforceExpiredDocuments` is `false`.
- Expiring and expired documents in Users and on the Overview (#68, #69, #70).
- Faculty and staff no longer send an ID at registration (#71).
- Nightly automatic backup, and 9 tables that were missing from backup (#73).
- OCR reads the licence and receipt by position (#75).
- Admin QA fixes: date picker, Gate Taps, Payments (#77); notifications, parking rates, "Paid by", read-only Gate Readers (#79).
- **The app shows no free bays while the guard post is offline** (#78).
- Admin: email a password-reset code to a user (#85).
- Admin: slot history, bulk archive, user history tabs, clearer incident review (#87).
- **Drivers confirm the bay they parked in** (#88): "Confirmed", "Confirmed late" and "Bay confirmed X of Y" now show in the guard panel too, because the guard panel is the admin app.

**New database tables and columns** (migrations) come with it. They are added automatically when the server starts. Your settings, reader links, photos and database are kept.

**Not included:**
- **Firmware: no change.** Nothing under `firmware/` differs from 1.9.2, so the gate reader and sensor boards need no reflash.
- **ALPR camera app: no change.** `alpr-service` is the same as 1.9.2, so there is no need to rebuild it.
- PR #27 (move S1 slot 3 off damaged pins, cap echo at 60 cm) is **still open and not merged**, so that sensor fix is not in 1.9.3.
- PR #34 (refuse entry to users who owe money; remove slot-watch) and PR #10 (all gate cameras at once) are also still open.

## Before you go (on the developer PC)

You need the installer file. It does not exist yet.

1. Make sure you have the latest code: `main` should include the merge of PR #90.

```bash
git checkout main
git pull
```

2. Build the installer. It needs .NET, Flutter and Inno Setup 6 (all on the developer PC) and takes a while:

```bash
powershell -ExecutionPolicy Bypass -File site-server\installer\build-installer.ps1 -Version 1.9.3
```

3. The result is `site-server\installer\output\AimParkSetup-1.9.3.exe` (about 390 MB). Copy it to a USB drive.

## At the com lab

**Warning:** the gate is down for about 30 seconds while it installs. Do it when nobody is tapping in.

1. Note what the guard panel shows before you start (the version, and that the reader and cameras are connected), so you can compare afterwards.
2. Copy `AimParkSetup-1.9.3.exe` to the guard PC.
3. Run it **over** the old install: **Next → Install → Finish**. Do not uninstall first.
4. Open the **AimPark Guard Panel** desktop shortcut. Hard refresh the page (Ctrl+Shift+R) so it does not show the old cached panel.

## Test it with the real hardware

1. **Server up.** The panel opens and the Gate Readers page lists both gates as connected. If it does not open, see "If it goes wrong" below.
2. **Sensors.** Put a hand or an object over a bay sensor. That bay shows occupied on the map, then free again when you remove it.
3. **Gate tap.** Tap a registered RFID card at the gate. The barrier opens and a parking session appears (inside, no bay confirmed yet).
4. **Confirm the bay.** On a phone with app 1.0.14, open the Parking tab, tap the bay you parked in and confirm it.
5. **Check the panel.** The same session now shows **Confirmed** next to its bay in the bay's history, and your user page shows "Bay confirmed 1 of N".
6. **Reminder.** Tap in again and do not confirm. After about 10 minutes the phone gets "Where did you park?". This runs in the cloud, so the phone needs internet.
7. **Exit.** Tap out. The session closes and the bill is created as before.

If any step behaves differently from before the update, write down which step and what you saw.

## Making the guard PC update by itself afterwards

The guard PC (1.2.0 and later) checks GitHub every 30 minutes for releases tagged `site-installer-v*`, and installs a newer one by itself when no car has tapped for 5 minutes and it is between 1 and 5 AM. It only does this for a release that has been **published**.

**Do not publish 1.9.3 until you have tested the installer by hand as above.** Publishing sends it to every guard PC. When you are happy, publish from the developer PC:

```bash
powershell -ExecutionPolicy Bypass -File site-server\installer\publish-release.ps1 -Version 1.9.3 -SkipBuild
```

`-SkipBuild` publishes the installer you already built and tested. It asks you to type the version again to confirm.

## If it goes wrong

- The installer runs over the old version, and if the install fails the old version keeps running.
- The install log is `C:\ProgramData\AimPark\updates\install.log`.
- To go back to 1.9.2, download `AimParkSetup-1.9.2.exe` from the GitHub release `site-installer-v1.9.2` and run it over the new one.
- Do not uninstall unless you have to. Uninstalling keeps PostgreSQL, the database and `C:\ProgramData\AimPark`, but a plain reinstall is simpler.
