# AimPark Mobile — In-app updates

The mobile app checks for a newer version on launch and offers to download
and install it in place — no reinstalling by hand, no re-sending the APK file
every time. This doc covers how it works, how to publish a new version, and
what to do when it breaks.

**Contents**
- [How it works](#how-it-works)
- [Signing key](#signing-key)
- [The manifest](#the-manifest)
- [Hosting: GitHub Releases, not Google Drive](#hosting-github-releases-not-google-drive)
- [Publishing a new version](#publishing-a-new-version)
- [Testing](#testing)
- [Data safety](#data-safety)
- [Troubleshooting](#troubleshooting)

---

## How it works

On every launch of a **release** build, the splash screen fires a background
check (`lib/features/splash/presentation/screens/splash_screen.dart`) that:

1. Fetches `release/update.json` from this repo's `main` branch (via
   `raw.githubusercontent.com`) — see [The manifest](#the-manifest).
2. Compares its `version`/`build` against the running app's own
   (`PackageInfo.fromPlatform()`), using proper numeric comparison
   (`1.0.9 < 1.0.10`, never string comparison) — see
   `lib/core/update/app_version.dart` and `update_policy.dart`.
3. If newer: shows an "Update available" dialog with the version and release
   notes. An **optional** update can be dismissed ("Later") and is re-offered
   after 24h or on the next version bump, whichever comes first. A
   **mandatory** update (`"mandatory": true`, or the local version is below
   `min_supported_version`) only offers "Update now" and can't be dismissed.
4. On "Update now": downloads the APK (progress shown), verifies it (ZIP
   signature, and size/SHA-256 if given in the manifest), then opens Android's
   system installer — the same confirmation screen as any other app update,
   never a silent install.

The check is **best-effort and silent**: a failed check (no internet, a
broken manifest, GitHub being slow) never shows an error and never blocks the
app — it just tries again next launch. It's also **rate-limited**: a cached
result is reused for 12h so a flaky connection doesn't retry every launch.
Debug and profile builds never run this automatic check at all
(`kReleaseMode` gate in `UpdateChecker.checkOnLaunch`) — only a release build
checks on launch.

Anyone can also trigger a check by hand from **Help & support → About →
Check for updates**, which ignores the cooldown and works in every build
mode — useful for testing (see [Testing](#testing)).

All of this lives under `lib/core/update/`:

| File | Responsibility |
|---|---|
| `update_config.dart` | Manifest URL, cooldown/remind durations, pref keys |
| `app_version.dart` | `1.0.9 < 1.0.10` — numeric, not string, comparison |
| `update_manifest.dart` | Parses + validates the remote JSON |
| `update_policy.dart` | Decides "is this actually newer, and is it mandatory" |
| `update_repository.dart` | Fetches the manifest, downloads + verifies the APK |
| `apk_installer.dart` | Talks to `MainActivity.kt` to open the system installer |
| `update_provider.dart` | Riverpod providers/notifiers wiring the above together |
| `update_dialog.dart` | The "Update available" / "Update required" UI |

The install step needs a `content://` URI (never a raw `file://`) and the
`REQUEST_INSTALL_PACKAGES` permission dance — there's no pure-Dart way to do
that, so `MainActivity.kt` has a small hand-written `MethodChannel`
(`com.aimpark.aimpark_mobile/updater`) rather than a dependency on one of the
handful of niche install-apk plugins on pub.dev.

---

## Signing key

**This is the one thing that actually makes self-update possible, and it's
the easiest part to get wrong.** Android only lets an app update itself in
place — install a new APK over an existing install, keeping all its data —
when the new APK is signed with the **same certificate** as the one already
installed. Sign a release with a different key and Android refuses the
install outright (`INSTALL_FAILED_UPDATE_INCOMPATIBLE`); the only way out is
for the user to uninstall first, losing their local data.

This app releases signed with the **debug key** on purpose (see the comment
in `android/app/build.gradle.kts`) — because that same key's SHA-1 is already
the one registered in Firebase for Google Sign-In, so sticking with it keeps
sign-in working with zero extra setup, at the cost of a well-known keystore
password (`android`). That's an acceptable trade for a capstone project, as
long as the keystore *file* itself stays private.

As of this feature, that key is pinned to a specific file rather than
"whichever debug key this machine happens to have" — `android/app/build.gradle.kts`
loads `android/key.properties` (gitignored) and **fails the release build
loudly** if it's missing, instead of silently falling back to a debug key
that could differ machine to machine.

**One-time local setup** (already done on this machine as of this feature):

1. The keystore lives at `C:\Users\ADMIN\keys\aimpark-release.jks` — a copy
   of `%USERPROFILE%\.android\debug.keystore`, *not* a newly generated key.
   **Back this file up** (cloud + a USB drive). If it's ever lost, no
   installed copy of the app can be updated again without a manual
   uninstall.
2. `android/key.properties` (gitignored, never commit it):
   ```
   storeFile=C:/Users/ADMIN/keys/aimpark-release.jks
   storePassword=android
   keyAlias=androiddebugkey
   keyPassword=android
   ```
3. Fingerprint check, if you ever need to re-confirm it matches Firebase:
   ```powershell
   keytool -list -v -keystore "C:\Users\ADMIN\keys\aimpark-release.jks" -alias androiddebugkey -storepass android
   ```

**CI** (`.github/workflows/release-apk.yml`) does the equivalent automatically:
it restores the same keystore from the `ANDROID_DEBUG_KEYSTORE_BASE64` secret
(already set up per `DEPLOYMENT.md`) and writes its own `key.properties`
pointing at it, so a release built by the workflow is signed identically to
one built locally. Nothing extra to configure there.

If this project ever moves to a real, separate release keystore later: that
new key's SHA-1 has to be registered in Firebase *first* (or Google Sign-In
breaks), and every device that already has the app installed needs a manual
uninstall once before it can receive updates again.

---

## The manifest

`aimpark_mobile/release/update.json`, committed to `main`, fetched from:

```
https://raw.githubusercontent.com/e-roz/Capstone/main/aimpark_mobile/release/update.json
```

```json
{
  "version": "1.0.1",
  "build": 2,
  "apk_url": "https://github.com/e-roz/Capstone/releases/download/v1.0.1/app-release.apk",
  "apk_sha256": "<64 lowercase hex chars, optional>",
  "apk_size_bytes": 63123456,
  "mandatory": false,
  "min_supported_version": "1.0.0",
  "release_notes": ["Faster gate check-in", "Fixed payment history dates"]
}
```

| Field | Required | Notes |
|---|---|---|
| `version` | yes | `MAJOR.MINOR.PATCH`. Must be strictly newer than the app's `pubspec.yaml` version to offer an update. |
| `build` | yes | Must also be strictly newer than the installed build number — if only `version` goes up but not `build`, nothing is offered (that combination means the manifest was edited wrong, since Android itself keys off `versionCode`/`build`, not the semver string). |
| `apk_url` | yes | Must be `https://` — a plain `http://` URL is rejected even though the app's manifest allows cleartext traffic elsewhere. |
| `apk_sha256` | no | If present, the download is hashed and must match, or it's treated as a failed download. |
| `apk_size_bytes` | no | If present, the downloaded file's size must match. Also shown in the dialog ("Version 1.0.1 · 63 MB"). |
| `mandatory` | no, default `false` | `true` removes the "Later" button — only "Update now". |
| `min_supported_version` | no | If the installed version is below this, the update becomes mandatory even if `mandatory` is `false`. |
| `release_notes` | no | Shown as a bullet list in the dialog. Capped at 8 entries. |

Unknown keys are ignored, so the schema can grow without needing a new APK
just to read a new field. This manifest URL is the *only* thing hardcoded in
the app about where to look — nothing about "what's the latest version" is
ever baked into a build, which is the whole point: editing this one file is
how a release gets announced.

---

## Hosting: GitHub Releases, not Google Drive

The APK itself is hosted as a GitHub Release asset, not on Google Drive.

**Why not Drive:** a Drive "share" link
(`drive.google.com/file/d/<id>/view`) is an HTML page, not the file. The
`uc?export=download` workaround works for small files, but above Google's
virus-scan size threshold Drive serves an HTML "can't scan this for viruses"
interstitial *instead of* the APK — which, without the ZIP-signature check
`update_repository.dart` does, would look like a successful download of a
broken file. Drive links can also rate-limit, omit `Content-Length` (no
download percentage), or stop working if sharing permissions change.

**Why GitHub Releases:** free, direct, versioned binary URLs that work with
no login and send a proper `Content-Length`. The repo already publishes this
way — `.github/workflows/release-apk.yml` builds and attaches the APK to a
GitHub Release automatically whenever a `v*` tag is pushed (see
`DEPLOYMENT.md`'s "Mobile → APK" section).

**Moving hosts later:** the app only ever reads `apk_url` out of the
manifest. Switching to Supabase Storage or anywhere else is a one-line edit
to `update.json`, never a code change.

---

## Publishing a new version

1. Bump `aimpark_mobile/pubspec.yaml`'s `version:` — **both** numbers
   (`1.0.0+1` → `1.0.1+2`). Only bumping the semver part and not the build
   number means the update policy won't offer it (see [The manifest](#the-manifest)).
2. Commit and push to `main`.
3. Tag and push the tag — this is what triggers the existing CI build:
   ```powershell
   git tag v1.0.1
   git push origin v1.0.1
   ```
   `release-apk.yml` builds the signed release APK and attaches it to the
   GitHub Release it creates for that tag, as `app-release.apk`.
4. Once the workflow finishes, edit `aimpark_mobile/release/update.json`:
   `version`, `build`, `apk_url` (pointing at the tag just pushed), and
   `release_notes`. Fill in `apk_sha256`/`apk_size_bytes` if you want the
   extra integrity check — download the release asset and run
   `Get-FileHash -Algorithm SHA256` / check its size.
5. Commit and push that edit to `main`. **This push is the actual publish
   step** — nobody gets offered the update until `update.json` says so, even
   though the APK itself has existed since step 3.
6. Smoke test: on a device with the previous version installed, open
   Help & support → Check for updates, and walk through the whole flow.
   Allow a few minutes — `raw.githubusercontent.com` caches for about 5
   minutes, so a just-pushed manifest edit may not be visible immediately.

---

## Testing

- **Don't want to wait for a real release?** Point a debug run at a test
  manifest without touching the production one:
  ```
  flutter run --dart-define=UPDATE_MANIFEST_URL=<url to a test update.json>
  ```
  (A gist's raw URL works fine for this.) The automatic launch check is still
  gated to release builds, but **Check for updates** on the Support screen
  works in every build mode and will use whatever URL was passed in.
- A debug-installed copy of the app can only be *updated* by an APK signed
  with the same key — which, per [Signing key](#signing-key), is the shared
  debug key, so a debug build and a CI-built release both install over each
  other fine.
- Installing a sideloaded APK — including through this updater — triggers
  Android's normal "unknown sources" prompt and, often, a Play Protect scan
  warning. Both are expected and something the user has to tap through;
  nothing in the app can or should suppress them.

---

## Data safety

An update that keeps the same `applicationId` (`com.aimpark.aimpark_mobile`)
and the same signing certificate, with a higher `versionCode`/`build`, only
replaces the app's code — it never touches `/data/data/<package>`. That means
`shared_preferences`, `flutter_secure_storage` (Android Keystore-backed, tied
to the app's UID) and any other local data all survive, and the signed-in
user stays signed in. This is ordinary Android update behavior, not something
this feature had to build — it's only *available* because the signing key is
now pinned (see [Signing key](#signing-key)) rather than accidentally
machine-dependent.

---

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| `INSTALL_FAILED_UPDATE_INCOMPATIBLE` when installing | The new APK was signed with a different key than the installed one, or has a lower/equal `versionCode` than what's installed. Check `android/key.properties` matches [Signing key](#signing-key). |
| Dialog never appears even though `update.json` is newer | Check `build` also went up, not just `version` (see [The manifest](#the-manifest)); check it's a release build (`kReleaseMode`); check the 12h cooldown hasn't cached an older manifest — use "Check for updates" to bypass it. |
| Download fails immediately with "isn't a valid APK" | The host returned something other than the file — classic Google Drive virus-scan page. Switch hosts or re-check the URL (see [Hosting](#hosting-github-releases-not-google-drive)). |
| "Install now" does nothing | The user hasn't granted "allow installs from this app" yet — the dialog should show a settings prompt for this; if it doesn't, check `REQUEST_INSTALL_PACKAGES` is still declared in `AndroidManifest.xml`. |
| Manifest edit doesn't show up for a few minutes | `raw.githubusercontent.com` caches responses briefly — this is expected, not a bug. |
