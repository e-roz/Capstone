# AimPark — Troubleshooting Runbook

Written so you can debug this project **without asking anyone**. Read section 1
and 2 once; the rest you look up when something breaks.

---

## 1. The map — where everything actually lives

Nothing about AimPark runs on one machine. Five separate hosted services, four
different dashboards. Knowing which one owns which problem is 80% of debugging.

| Piece | Runs on | Address / ID | Dashboard |
|---|---|---|---|
| **Backend API** (.NET 8) | Render, as a Docker container | `https://aimpark-api.onrender.com` | [dashboard.render.com](https://dashboard.render.com) |
| **Database** (Postgres) | Supabase | project ref `zgeqdpwgthwwvjblhcks`, host `aws-0-ap-southeast-1.pooler.supabase.com:5432`, db `postgres` | [supabase.com/dashboard](https://supabase.com/dashboard) |
| **Document/photo storage** | Supabase Storage | bucket `documents` | same Supabase project → Storage |
| **Email** (OTP codes) | Brevo | `api.brevo.com`, 300 emails/day free | [app.brevo.com](https://app.brevo.com) |
| **Push notifications** | Firebase Cloud Messaging | project `aim-park` (number `1083185026916`) | [console.firebase.google.com](https://console.firebase.google.com) |
| **Admin web app** (Flutter web) | Firebase Hosting | `https://aim-park.web.app` | same Firebase project → Hosting |
| **Mobile app** | An APK file you build and share | — | none |
| **Source code** | GitHub | `e-roz/Capstone`, branch `main` | github.com |

**How the backend deploys:** Render watches the `main` branch of
`e-roz/Capstone`. Push to `main` → Render rebuilds using [Dockerfile](Dockerfile)
at the repo root → new version goes live in a few minutes. There is no GitHub
Actions workflow; Render *is* the pipeline.

**Where the secrets live:** `C:\Users\ADMIN\.aimpark\`

- `render-env-vars.txt` — every environment variable Render needs, ready to paste
- `gen-render-env.ps1` — regenerates that file when a secret changes
- `firebase-service-account.json` — the FCM push key

None of these are in git (correctly). **If that folder is lost, the deployed
backend still runs, but you cannot recreate it.** Back the folder up somewhere.

Locally the API reads secrets from .NET user-secrets instead
(id `9a0857be-3a82-4509-aa0c-bfa8bbd7b8a2`, stored at
`%APPDATA%\Microsoft\UserSecrets\9a0857be-.../secrets.json`). That's why
[appsettings.json](AimPark.API/AimPark.API/appsettings.json) has empty strings
everywhere — it's a template, not a config.

---

## 2. The 60-second triage

Before touching anything, find out **which layer** is broken. Do these in order.

### Step 1 — Is the backend alive?

```
curl -i https://aimpark-api.onrender.com/api/parking/slots
```

| Result | Meaning |
|---|---|
| `401 Unauthorized` | ✅ **Correct.** The API is up and auth works. The problem is elsewhere. |
| Takes 30–60s then 401 | ✅ Normal. Render free tier was asleep. Run it again — should be instant. |
| `502` / `503` | Backend crashed or failed to start → **Render logs** |
| Connection timeout / no response | Deploy is broken or the service was suspended → **Render dashboard** |
| `500` | The app started but something inside is failing, usually the DB → step 2 |

### Step 2 — Is the database alive?

Supabase dashboard → your project. If the project is **paused**, everything
DB-backed returns 500. Free Supabase projects pause after ~7 days of no
activity. Click **Restore**, wait ~2 minutes.

Then Supabase → **SQL Editor** and run:

```sql
select count(*) from "Users";
```

Works → the DB is fine. Errors with *relation does not exist* → see landmine #1
in section 8 (migrations weren't applied).

### Step 3 — Which client is broken?

If the API and DB are both fine, the fault is in one app:

- **Admin web only** → almost always CORS or a stale build. Open the browser
  **DevTools → Console + Network tab**. That's where the real error is.
- **Mobile only** → almost always the wrong `API_BASE_URL` baked into the APK.
- **Both** → it's a backend bug after all; check Render logs.

That's the whole method: *API → DB → which client*. Don't guess; each step is
one command.

---

## 3. Google Sign-In doesn't work

The scenario you asked about. It's the most fragile part of the system because
it involves four things that all have to agree.

### How it actually works (know this or you're guessing)

1. Mobile app calls Google with a **serverClientId**, hardcoded at
   [login_screen.dart:20-24](aimpark_mobile/lib/features/auth/presentation/screens/login_screen.dart#L20-L24):
   `396722417831-3ldllppvag9pccpk9vupf20829f6be4h.apps.googleusercontent.com`
2. Android's Play Services checks the app's **package name**
   (`com.aimpark.aimpark_mobile`) and **signing certificate SHA-1** against an
   Android OAuth client registered in Google Cloud. If no match → it fails
   *before ever reaching your backend*.
3. On success Google returns an **ID token** whose audience is that serverClientId.
4. App POSTs it to `/api/auth/google/signin`.
5. Backend reads `GoogleAuth:ClientId` from config and validates the token's
   audience matches — [AuthController.cs:126-137](AimPark.API/AimPark.API/Controllers/AuthController.cs#L126-L137).
6. Match → user is found or created. Mismatch → `401 Invalid or expired Google token`.

So the chain is: **app's serverClientId** = **backend's `GoogleAuth__ClientId`**,
and **package + SHA-1** must be registered in Google Cloud.

### Diagnose by the symptom

| What you see | What it means | Fix |
|---|---|---|
| Account picker opens, you choose an account, it closes and nothing happens. Log shows `PlatformException(sign_in_failed, ... ApiException: 10)` | **DEVELOPER_ERROR.** The SHA-1 of the key that signed this APK isn't registered in Google Cloud. This is *the* most common Google Sign-In failure. | Get the SHA-1 (below) and register it |
| Works on your build, fails for a teammate | Same thing — their debug keystore has a different SHA-1 | Build the APK yourself and share that one file. Never let teammates build their own. |
| Backend returns `401 "Invalid or expired Google token. Please sign in again."` | The token reached the server but the audience didn't match — app's serverClientId ≠ `GoogleAuth__ClientId` on Render | Compare the two strings character by character |
| Backend returns `500 "Google authentication is not configured."` | `GoogleAuth__ClientId` env var is missing/empty on Render | Render → Environment → re-add it from `render-env-vars.txt` |
| `409 Conflict — "This email is already registered. Please log in with your password instead."` | **Not a bug.** That email signed up with email+password first. The code deliberately refuses to auto-link accounts ([AuthController.cs:154](AimPark.API/AimPark.API/Controllers/AuthController.cs#L154)) | Log in with the password |
| `403 — "Your account is waiting for admin approval."` | **Not a bug.** Google signup still requires admin approval | Approve it in the admin panel |
| `403 — "Your registration was rejected."` | **Not a bug.** Rejected accounts have a re-apply cooldown | Wait, or clear it in the DB |
| Picker doesn't open at all / instant error | No network, or Google Play Services missing/outdated (common on emulators without Play Store) | Use an emulator image that says "Google Play", not just "Google APIs" |

### Getting the SHA-1 and registering it

```
cd aimpark_mobile/android
gradlew.bat signingReport        # on Windows; ./gradlew elsewhere
```

Look for the `debug` variant's **SHA1** (for debug builds) or your release
keystore's SHA1 (for `flutter build apk --release`). **These are different
fingerprints** — a release APK needs its own SHA-1 registered, which is why an
app that works in `flutter run` can fail as a distributed APK.

Register at [console.cloud.google.com](https://console.cloud.google.com) →
**APIs & Services → Credentials → OAuth 2.0 Client IDs** → the Android client
for `com.aimpark.aimpark_mobile` → add the SHA-1. Changes take a few minutes.

> ⚠️ **Which Google project?** Your Firebase project `aim-park` is number
> `1083185026916`, but the sign-in client ID starts with `396722417831` — a
> *different* Google Cloud project. When you open the Cloud Console, make sure
> the project selector is on the one matching `396722417831`, or you'll stare at
> an empty credentials list and conclude something is deleted when it isn't.

### Reading the actual mobile error

Don't debug from the UI message. Get the raw exception:

```
cd aimpark_mobile
flutter run            # errors print in this terminal
```

or on an installed APK:

```
adb logcat | grep -i "flutter\|GoogleSignIn\|ApiException"
```

### One stale file to know about

[google-services.json](aimpark_mobile/android/app/google-services.json) has an
empty `oauth_client: []` array. That file was downloaded before any OAuth client
existed. It doesn't break sign-in — `google_sign_in` uses the hardcoded
`serverClientId` and Play Services resolves the Android client server-side — but
it means **you can't learn anything about your OAuth setup by reading that
file.** Check the Cloud Console instead. If you ever re-download it from
Firebase, don't be alarmed that the contents change.

---

## 4. Other scenario playbooks

### Admin panel loads, but every action fails

Open **DevTools → Console**. If you see *"blocked by CORS policy"*:

Render → Environment → confirm `Cors__AllowedOrigins__0=https://aim-park.web.app`

Must match **exactly** — `https` not `http`, no trailing slash. The backend
merges this with `localhost:5000` at
[Program.cs:59-66](AimPark.API/AimPark.API/Program.cs#L59-L66). CORS only ever
affects browsers, so if mobile works and web doesn't, this is your first suspect.

If instead you see 401s everywhere: your JWT expired (they last **60 minutes**).
Log out and back in.

If the admin panel is missing a feature you know you built: you deployed a stale
build. Rebuild *with* the API URL and redeploy:

```
cd aimpark_admin
flutter build web --dart-define=API_BASE_URL=https://aimpark-api.onrender.com
firebase deploy --only hosting
```

Forgetting `--dart-define` produces a site that loads fine and can't call
anything — it falls back to a localhost URL.

### Mobile app can't reach anything

- **A distributed APK:** built without `--dart-define=API_BASE_URL`, so it's
  pointing at `http://192.168.100.95:5041`
  ([api_constants.dart:16](aimpark_mobile/lib/core/constants/api_constants.dart#L16))
  — your PC on your Wi-Fi. Works for you, dead for everyone else. Rebuild:
  ```
  flutter build apk --release --dart-define=API_BASE_URL=https://aimpark-api.onrender.com
  ```
- **Running locally on an emulator/phone:** your PC's LAN IP changed. Run
  `ipconfig`, update `api_constants.dart`, re-run. Also check Windows Firewall
  isn't blocking inbound port 5041.

### Verification / OTP email never arrives

Codes expire after **10 minutes** ([OtpService.cs:16](AimPark.API/AimPark.API/Services/OtpService.cs#L16)).

1. Check spam. Tell the user to mark "not spam" once.
2. Brevo dashboard → **Statistics/Logs**. If the email isn't listed at all, the
   API never sent it — check Render logs for
   *"Brevo:ApiKey and Brevo:SenderEmail must be configured"*.
3. Brevo free tier is **300 emails/day**. During a group test day you can hit
   this. The dashboard shows the counter.
4. Brevo requires a **verified sender**. If the sender address was un-verified,
   every send fails silently from the app's point of view.

### Push notifications stopped

Push is optional by design — if Firebase credentials are missing, the API still
boots and just silently doesn't send ([Program.cs:35-52](AimPark.API/AimPark.API/Program.cs#L35-L52)).
So *no push and no errors* is exactly what a missing credential looks like.

1. Render → Environment → is `Firebase__CredentialsJson` present and complete?
   It's a whole JSON blob; it gets truncated or mangled easily on paste.
   Regenerate with `gen-render-env.ps1` and re-paste.
2. Render logs at startup — a malformed JSON throws on boot.
3. The device must have registered its token. Reinstall the app, log in again
   (registration happens after login), check the `DeviceTokens` table in Supabase.
4. iOS-style "app is closed" issues don't apply; on Android, aggressive battery
   optimisation on Xiaomi/Oppo/Vivo phones can kill delivery. Real behaviour, not
   your bug.

### Photo / document upload fails

Storage is Supabase bucket `documents`
([FileStorageService.cs:9](AimPark.API/AimPark.API/Services/FileStorageService.cs#L9)).

- Uploads are capped at **10 MB** ([Program.cs:146](AimPark.API/AimPark.API/Program.cs#L146)).
  A modern phone photo can exceed this. Symptom: `413` or a generic failure.
- `Supabase__ServiceRoleKey` wrong/expired → 401 from Supabase, surfaced as a 500.
- Bucket renamed or deleted in the Supabase dashboard → 404. Check Storage.

### Everything is slow / first request takes ~50 seconds

Render free tier sleeps after 15 minutes idle. Expected. Only the first request
pays it. Before your defense, upgrade to a paid instance so a demo never stalls
on stage.

If it's slow *after* warm-up: Supabase free tier is a small instance and you're
connecting through the pooler from Singapore. Check Render logs for slow queries.

### A deploy "worked" but the app is broken

Render → your service → **Logs** and **Events**. Read the log from the *top* of
the latest deploy. Two distinct failures:

- **Build failed** — Docker/compile error. The old version stays live, so the
  app keeps working and you think the deploy succeeded. Always check Events.
- **Started then crashed** — usually a missing env var or a bad connection
  string. The exception text is in the log.

To roll back: Render → Events → find the last good deploy → **Rollback**.

---

## 5. Reading errors: what each status code means *in this API*

| Code | In AimPark it almost always means |
|---|---|
| `400` | Your request body was wrong/missing a field. Check the DTO. |
| `401` | No token, expired token (>60 min), or an invalid Google ID token |
| `403` | Account state: pending approval, rejected, suspended, or wrong role |
| `404` | Route typo, or the record genuinely doesn't exist |
| `409` | Deliberate conflict — duplicate email, duplicate plate, Google-vs-password clash. **Usually intended behaviour, not a bug.** |
| `413` | File over 10 MB |
| `500` | Unhandled exception. **Always go to Render logs** — the message there is the real one. Most common cause: database. |
| `502` / timeout | Container down, crashed, or asleep |

Rule: a `4xx` is usually the *client* or the *user's account state*. A `500` is
always *you*, and the answer is always in the Render log.

---

## 6. Your four debugging tools

You never need more than these.

**1. Render → Logs** (the single most useful one). Live tail of every request and
every exception from the backend. `Console.WriteLine` output shows up here too —
e.g. the Google token failure logs its exact reason at
[AuthController.cs:141](AimPark.API/AimPark.API/Controllers/AuthController.cs#L141).

**2. Supabase → SQL Editor / Table Editor.** Ground truth for data questions.
"Did the registration save?" "Is this user actually approved?" Look, don't guess:

```sql
select "Id","Email","AccountStatus","RegistrationStep","AuthProvider","IsDeleted"
from "Users" order by "Id" desc limit 20;
```

Also the fastest way to unstick yourself in testing — flip your own
`AccountStatus` to approved instead of doing the whole flow again.

**3. Browser DevTools (F12) → Console + Network.** For anything admin-web. The
Network tab shows the actual request, the actual status, and the actual response
body. A red CORS message in Console is unmistakable.

**4. `flutter run` / `adb logcat`.** For anything mobile. The UI message is a
friendly summary; the terminal has the real exception.

Plus **Swagger** for testing the API in isolation: it's enabled only in
Development ([Program.cs:186-190](AimPark.API/AimPark.API/Program.cs#L186-L190)),
so run the API locally (`dotnet run` in `AimPark.API/AimPark.API`) and open
`https://localhost:7124/swagger`. Great for proving "is this a backend bug or an
app bug" — if Swagger works and the app doesn't, it's the app.

---

## 7. Reproducing production locally

When you can't figure out a deployed bug, run the backend on your machine
against the **real** Supabase database:

```
cd AimPark.API/AimPark.API
dotnet user-secrets set "ConnectionStrings:DefaultConnection" "<the string from render-env-vars.txt>"
dotnet run
```

Now you get a debugger, breakpoints, and Swagger against live data. **Be
careful — that's the real database.** Do read-only investigation, and set the
connection string back when done.

---

## 8. Landmines — things that will bite you eventually

**1. Migrations do not run automatically.** There is no `Database.Migrate()`
call anywhere in the app. If you add an EF migration and push, Render deploys
happily and then *every* query 500s with `relation/column does not exist`. You
must apply it yourself:

```
cd AimPark.API/AimPark.API
dotnet ef database update --connection "<connection string from render-env-vars.txt>"
```

Do this **before** or immediately after the deploy. This will look like a
catastrophic outage and it's a one-command fix.

**2. Changing `Jwt__Key` on Render logs everyone out instantly.** Every issued
token becomes invalid. Never rotate it mid-test-session.

**3. There is no login rate-limiting or account lockout.** Unlimited password
attempts are allowed. Not a bug you're seeing — a feature you haven't built.
Worth mentioning in your capstone's security section before a panelist asks.

**4. Supabase free projects pause after ~7 days idle.** If you come back from a
break and *everything* is 500, this is why. Restore takes ~2 minutes.

**5. Render's free instance sleeps at 15 minutes.** Plan around it for the demo.

**6. `C:\Users\ADMIN\.aimpark\` is not in git and not backed up.** Losing that
folder means losing every secret. Copy it to a password manager or an encrypted
drive today.

**7. The admin web build bakes in the API URL at build time.** Changing the
backend URL means rebuilding *and* redeploying the admin app and rebuilding the
APK. Same for the mobile app.

---

## 9. Quick command reference

```
# Is the backend up? (401 = healthy)
curl -i https://aimpark-api.onrender.com/api/parking/slots

# Run backend locally
cd AimPark.API/AimPark.API && dotnet run          # http://localhost:5041

# Run admin locally (port 5000 required — CORS allows only that)
cd aimpark_admin && flutter run -d web-server --web-port 5000

# Deploy admin
cd aimpark_admin
flutter build web --dart-define=API_BASE_URL=https://aimpark-api.onrender.com
firebase deploy --only hosting

# Build the shareable APK
cd aimpark_mobile
flutter build apk --release --dart-define=API_BASE_URL=https://aimpark-api.onrender.com
#  → build/app/outputs/flutter-apk/app-release.apk

# Deploy backend
git push origin main        # Render rebuilds automatically

# Get signing SHA-1 for Google Sign-In (on Windows use gradlew.bat)
cd aimpark_mobile/android && gradlew.bat signingReport

# Mobile logs
adb logcat | grep -i flutter

# Regenerate Render env vars after a secret change
powershell -ExecutionPolicy Bypass -File C:\Users\ADMIN\.aimpark\gen-render-env.ps1
```

---

See also: [DEPLOYMENT.md](DEPLOYMENT.md) for first-time setup,
[HOW_TO_RUN.txt](HOW_TO_RUN.txt) for local dev, [TESTING.md](TESTING.md) for
what testers should and shouldn't report.
