# Pay-before-exit: getting it onto the hardware test

Branch: `feat/pay-before-exit` (3 commits, already pushed).
Checked on 2026-10-28: API builds with 0 errors, new admin and mobile code has no analyzer issues. Tests were **not** run.

No database migrations, so the shared Supabase DB is safe.

## What changed, and where it runs

| Part | What it does now | Runs on |
|---|---|---|
| Gate | Exit tap raises the bill and the barrier stays shut (402 `PAYMENT_DUE`) until it is paid | **Guard PC (site server)** |
| Guard cash / let-out | `api/site/payments/{id}/cash`, `/release`, `cash-summary` | **Guard PC (site server)** |
| Pay to leave screen | Mobile asks the driver to pay when held at the exit | Mobile app + cloud API |
| "Waiting to leave" card | Admin lists held drivers with cash and let-out buttons | Admin web + cloud API |

If the guard PC is not updated, the barrier opens at exit as before. The test will look like nothing changed.

## Do it in this order

### 1. Build the guard PC installer (dev PC)

The last guard PC installer published is **1.9.2**, so use **1.9.3**. If you have since built a higher one, use the next number above it.

From the repo root, on the branch `feat/pay-before-exit`:

```powershell
powershell -ExecutionPolicy Bypass -File site-server\installer\build-installer.ps1 -Version 1.9.3
```

Needs the .NET 8 SDK, Flutter and Inno Setup 6. The result is `site-server\installer\output\AimParkSetup-1.9.3.exe` (about 390 MB).

### 2. Install it on the guard PC

1. Copy `AimParkSetup-1.9.3.exe` to the guard PC.
2. Run it over the old install: **Next**, **Install**, **Finish**.
3. Settings (`C:\ProgramData\AimPark`), reader links, photos and the database are kept.
4. The gate is down for about 30 seconds. Do it when no car is tapping.
5. Open the guard panel and check the version shows 1.9.3.

Do **not** run `publish-release.ps1` for tomorrow. Publishing sends the update to every guard PC (they install at 1 to 5 AM or after a day), and this branch is not tested on hardware yet.

### 3. Cloud API and admin panel

Both deploy from `main` (`deploy-api.yml` to Render, `deploy-admin.yml` to Firebase Hosting). The branch is not merged, so:

- Open the PR for `feat/pay-before-exit` and merge it to `main`. Wait for both workflows to go green.
- Merging is the moment the live cloud gets this. If you would rather not touch live before the test, tell me and we will find another way.
- After the admin deploy, hard refresh the admin site (Ctrl+Shift+R) or clear site data. An old cached copy will not show the "Waiting to leave" card.

### 4. Mobile app

Push a tag like `v1.0.15` (`release-apk.yml` builds the APK), or run the **Release APK** workflow by hand. Install it over the old app on the test phone.

## Quick test on the day

1. Enter with a registered card.
2. Tap out. Expected: barrier stays shut, the app asks to pay, and the driver shows in **Waiting to leave** in the admin panel.
3. Pay in the app. Tap out again. Expected: barrier opens.
4. Repeat, but take cash from the admin panel instead. Expected: next tap opens.
5. Repeat, but use **let out**. Expected: barrier opens and the bill stays owing.
6. A fee of zero should open on the first tap.

## If something goes wrong

- Barrier opens without payment: the guard PC is still on the old version.
- Nothing in "Waiting to leave": the admin site is a cached old copy, or the cloud API is not deployed yet.
- Guard PC problems: see `C:\ProgramData\AimPark\updates\install.log` and `MD files/SITE_SERVER.md`.
