# AimPark — Deployment

Three pieces deploy separately:

| Piece | Where | Notes |
|---|---|---|
| `AimPark.API` | Render (Docker) | The only server-side piece |
| `aimpark_admin` | Firebase Hosting | Static web build |
| `aimpark_mobile` | APK download link | Built locally, shared as a file |

The database (Supabase Postgres), file storage (Supabase Storage), email (Brevo),
and push (Firebase) are already hosted — nothing to deploy for those.

---

## 1. Backend → Render

### First time

1. Push `main` to GitHub.
2. [dashboard.render.com](https://dashboard.render.com) → **New** → **Web Service**.
3. Connect the `e-roz/Capstone` repo.
4. Settings:
   - **Language / Runtime:** `Docker`
   - **Dockerfile Path:** `./Dockerfile`
   - **Branch:** `main`
   - **Instance Type:** Free
5. **Environment variables** — open `C:\Users\ADMIN\.aimpark\render-env-vars.txt`
   and paste the whole contents into Render's bulk env-var editor.

   Regenerate that file any time secrets change:
   ```
   powershell -ExecutionPolicy Bypass -File C:\Users\ADMIN\.aimpark\gen-render-env.ps1
   ```

   > Do **not** set `PORT` — Render injects it, and the app reads it in `Program.cs`.

6. **Create Web Service.** Watch the build log; the Docker build takes a few minutes.
7. Note the URL it gives you, e.g. `https://aimpark-api.onrender.com`.

### Verify

```
curl https://<your-render-url>/api/parking/slots
```
`401 Unauthorized` is the **correct** result — it means the API is up and auth is
working. A timeout or 502 means the deploy failed; check the Render log.

### Free tier caveat

The service sleeps after 15 minutes idle. The next request takes ~50s to wake it.
Fine for testing; upgrade to a paid instance before the defense so a demo never stalls.

---

## 2. Admin web → Firebase Hosting

```
cd aimpark_admin
flutter build web --dart-define=API_BASE_URL=https://<your-render-url>
```

Then, once per machine:
```
npm install -g firebase-tools
firebase login
firebase init hosting      # public dir: build/web ; single-page app: Yes ; don't overwrite index.html
firebase deploy --only hosting
```

Subsequent deploys are just the `flutter build web ...` line followed by `firebase deploy --only hosting`.

### Then close the CORS loop

Firebase gives you a URL like `https://aim-park.web.app`. The API rejects browser
calls from unknown origins, so add it in Render → Environment:

```
Cors__AllowedOrigins__0=https://aim-park.web.app
```

Render redeploys automatically. **Until this is done the admin app will load but
every API call will fail** — that's the expected symptom of a missing CORS origin.

---

## 3. Mobile → APK

```
cd aimpark_mobile
flutter build apk --release --dart-define=API_BASE_URL=https://<your-render-url>
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

Upload to Google Drive, set the link to "anyone with the link", share it.

> **Always pass `--dart-define`.** Without it the build falls back to
> `http://192.168.100.95:5041`, which only works on your Wi-Fi — the APK would
> appear completely broken to everyone else.

> **Build the APK yourself and share that one file.** If teammates build from
> source, each machine signs with a different debug key, and Google Sign-In will
> fail for them because the signature won't match the registered OAuth client.

---

## Instructions for testers

Nothing to install but the app.

1. Open the admin site: `https://<admin-url>` (browser, any device)
2. Install the APK: enable "Install from unknown sources" when Android asks
3. Register in the mobile app — email/password or the Google button
4. **Check spam** for the verification code. Mark it "not spam" so later ones land properly.

No laptop, Flutter SDK, .NET SDK, database, or Docker required.

---

## Troubleshooting

| Symptom | Cause |
|---|---|
| Admin loads, every request fails | `Cors__AllowedOrigins__0` missing or doesn't exactly match the admin URL (scheme included, no trailing slash) |
| First request takes ~50s | Render free tier waking from sleep — expected |
| Mobile can't reach the API | APK built without `--dart-define=API_BASE_URL` |
| No verification email | Check Brevo sender is still verified and the daily 300 cap isn't hit |
| Push notifications stop | `Firebase__CredentialsJson` missing or malformed in Render env vars |
| Google Sign-In fails for teammates only | They built their own APK instead of using yours |
