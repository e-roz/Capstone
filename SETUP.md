# Setting up AimPark on another computer

For moving to a new machine — the lab PC, a reformatted laptop, a teammate's
desktop. Written for Windows, which is what the project is developed on.

Once this is done, use [HOW_TO_RUN.txt](HOW_TO_RUN.txt) for the day-to-day
"how do I start everything" steps.

**The short version:** install the tools, clone the repo, copy over the secrets
(they are deliberately not in the repo), apply the database migrations, point
the mobile app at the new machine's IP address. Budget about an hour, most of it
downloading Android Studio.

---

## 1. What to install

| Tool | Version | Notes |
|---|---|---|
| Git | any recent | |
| .NET SDK | 8.0 or newer | The API targets `net8.0`. A newer SDK (10.x) runs it fine. |
| Flutter | 3.38.5 stable | Needs Dart 3.10.4 or newer — both apps require `sdk: ^3.10.4`. |
| Android Studio | latest | For the Android SDK, the emulator, and `adb`. |
| JDK | 21 | Android Studio ships one. Only install separately if Gradle complains. |
| Chrome | any | The admin panel is a Flutter web app. |

Then one command-line tool for database migrations:

```
dotnet tool install --global dotnet-ef
```

An editor: VS Code or Visual Studio 2022 for the API, either for Flutter.

**Check the install before going further:**

```
dotnet --version
flutter doctor
```

`flutter doctor` must show ticks for Flutter, the Android toolchain, and
Android Studio. Ignore complaints about Visual Studio (that is for Windows
desktop builds, which this project does not use) and about Xcode.

---

## 2. Get the code

```
git clone https://github.com/e-roz/Capstone.git
cd Capstone
git checkout feat/payment-gateway
```

`main` is what is deployed. `feat/payment-gateway` is the latest work — the
payment checkout, the registration back-button fix, and document deletion.
Check `git branch -a` for what else is there.

---

## 3. The secrets — the part that is not in the repo

**This is the step that will stop you.** Everything else is a download.

API credentials are kept out of Git on purpose. They live in .NET *user
secrets*, which is a file outside the project folder, so nothing sensitive can
be committed by accident.

### Copy them from the old machine

On the **old** machine the file is here:

```
C:\Users\<you>\AppData\Roaming\Microsoft\UserSecrets\9a0857be-3a82-4509-aa0c-bfa8bbd7b8a2\secrets.json
```

Copy that whole folder to the same path on the **new** machine. That is the
entire step — the ID `9a0857be-…` is stored in `AimPark.API.csproj`, so .NET
will find it.

Move it on a USB stick. Do not email it, do not put it in a chat, and do not
commit it — it contains the database password and the Supabase service key,
which together give full access to the live data.

### Or set them one by one

If you cannot get to the old machine, from `AimPark.API/AimPark.API`:

```
dotnet user-secrets set "ConnectionStrings:DefaultConnection" "Host=...;Port=5432;Database=postgres;Username=...;Password=..."
dotnet user-secrets set "Jwt:Key" "<long random string>"
dotnet user-secrets set "Otp:Pepper" "<the same value as before>"
dotnet user-secrets set "Supabase:Url" "https://<project>.supabase.co"
dotnet user-secrets set "Supabase:ServiceRoleKey" "<service role key>"
dotnet user-secrets set "Brevo:ApiKey" "<brevo api key>"
dotnet user-secrets set "Brevo:SenderEmail" "<verified sender>"
dotnet user-secrets set "GoogleAuth:ClientId" "<web client id>.apps.googleusercontent.com"
dotnet user-secrets set "Firebase:CredentialsPath" "C:\\path\\to\\firebase-adminsdk.json"
```

Where each one comes from:

- **ConnectionStrings:DefaultConnection** — Supabase dashboard → Project
  Settings → Database → Connection string (URI). Same database as before; see
  section 4.
- **Jwt:Key** — signs login tokens. Any long random string works, but copying
  the old one means logins issued before the move keep working.
- **Otp:Pepper** — mixed into stored OTP hashes. **Must** be the old value, or
  any registration OTP already sent out will stop verifying.
- **Supabase:Url / ServiceRoleKey** — Supabase dashboard → Project Settings →
  API. Used for document photos and database backups.
- **Brevo** — sends the registration OTP emails. Without it, registration
  cannot get past the email step.
- **GoogleAuth:ClientId** — Google Cloud console, the *Web* OAuth client. The
  API verifies Google sign-in tokens against it.
- **Firebase:CredentialsPath** — see just below.

### The Firebase key file

Push notifications need a Firebase service-account JSON. It is git-ignored
(`firebase-adminsdk*.json`), so copy the file across too, put it anywhere
sensible outside the repo, and point `Firebase:CredentialsPath` at it.

Skip it if you like — the API starts without it and simply sends no
notifications. Everything else works.

### What you do *not* need to copy

- `aimpark_mobile/android/app/google-services.json` **is** in the repo. Nothing
  to do for the mobile app's Firebase setup.
- PayMongo keys. Payments default to the built-in simulator, which needs no
  account. See section 8.

---

## 4. The database

Nothing to install. The database is **hosted on Supabase**, and the connection
string in your secrets points at it.

It is also **shared** — your machine, your teammates' machines, and the deployed
API on Render all read and write the same database. Two consequences:

- You will see real data immediately. No seeding needed.
- A migration you apply here hits everyone, including the live site.

Apply any migrations the code needs but the database has not got yet:

```
cd AimPark.API/AimPark.API
dotnet ef database update
```

On `feat/payment-gateway` this is **required** — that branch adds columns for
the payment gateway, and without them every payments screen returns a 500.
The migration only adds columns, so the deployed API keeps working on it.

> **The seeder** (`AimPark.Seeder`) creates staff logins on an empty database:
> `dotnet run -- admin` makes `admin@gmail.com` / `admin123!`, and
> `dotnet run -- security` makes the guard account. You should not need it — the
> shared database already has them. It also has a "delete all data" option, so
> be careful in there.

---

## 5. Run the API

```
cd AimPark.API/AimPark.API
dotnet restore
dotnet run
```

It listens on `http://localhost:5041` and `https://localhost:7124`.

Check it: open `http://localhost:5041/swagger` in a browser. The API reference
appears when running in Development, which is the default for `dotnet run`.

---

## 6. Run the admin panel

```
cd aimpark_admin
flutter pub get
flutter run -d web-server --web-port 5000
```

**Port 5000 is not optional.** The API's CORS policy only trusts
`http://localhost:5000`, so on any other port every request is blocked by the
browser.

Log in with the admin account from the shared database.

---

## 7. Run the mobile app

```
cd aimpark_mobile
flutter pub get
```

### Point it at this machine

The phone or emulator cannot reach your PC's `localhost` — it needs the PC's
address on the network.

1. Run `ipconfig` and find **IPv4 Address** under your active Wi-Fi or Ethernet
   adapter, e.g. `192.168.1.24`.
2. Either edit the default in
   [api_constants.dart](aimpark_mobile/lib/core/constants/api_constants.dart),
   or leave the file alone and pass the address when you run:

```
flutter run --dart-define=API_BASE_URL=http://192.168.1.24:5041
```

On the Android emulator you can use `http://10.0.2.2:5041` instead — that is
the emulator's alias for the host machine, and it does not change when the
Wi-Fi does.

**This has to be redone whenever the network changes.** A lab PC on DHCP can get
a different IP after a reboot.

### Then run it

```
flutter emulators --launch Pixel_6
flutter run
```

For a real phone over Wi-Fi, HOW_TO_RUN.txt section 3B has the `adb pair` /
`adb connect` steps.

If the app installs but cannot reach the API, allow inbound connections to port
5041 through Windows Firewall.

---

## 8. Payments

Nothing to set up. `Payments:Provider` defaults to `Simulated`, and the API
serves its own checkout page in place of a real provider — tapping "Pay" opens
it in the phone's browser, and paying there settles the bill exactly the way a
real provider's callback would.

If a PayMongo account is ever registered, add three secrets and change nothing
else:

```
dotnet user-secrets set "Payments:Provider" "PayMongo"
dotnet user-secrets set "Payments:PayMongo:SecretKey" "sk_test_..."
dotnet user-secrets set "Payments:PayMongo:WebhookSecret" "whsk_..."
```

---

## 9. Two things that break specifically because it is a new computer

### Google Sign-In stops working

Android signs debug builds with a keystore that is **unique to each machine**.
Google only accepts sign-ins from fingerprints it knows, so on a new PC the
Google button will fail with a vague error while everything else works.

Fix it by registering the new machine's fingerprint:

```
cd aimpark_mobile/android
./gradlew signingReport
```

Copy the **SHA1** under `Variant: debug`, then in the Firebase console →
Project Settings → Your apps → the Android app → **Add fingerprint**. Paste it
and save.

Then download the refreshed `google-services.json` and replace
`aimpark_mobile/android/app/google-services.json`. That file is tracked by Git,
so commit the change — it now carries the OAuth clients for both machines, and
Google Sign-In keeps working on the old one too.

Email-and-password registration and login are unaffected while you sort this
out.

### The API address is wrong

Covered in section 7, and it is the single most common reason the app shows
"Could not reach the server" on a machine that was working yesterday.

---

## 10. Check everything works

Run all three, then walk through this:

1. **API** — `http://localhost:5041/swagger` loads.
2. **Admin** — log in at `http://localhost:5000`, open Users, see real accounts.
3. **Mobile** — log in as a student, open a pending payment, tap Pay. The
   browser opens the checkout page, and after paying the bill shows **Paid**
   with a reference number.
4. **Admin again** — Payments, and the bill you just paid is there with the
   method and reference against it.

If step 3 fails at the browser, the API URL is wrong or the firewall is
blocking. If the payments screen 500s, run the migration in section 4.

---

## 11. Rules about the secrets

- Never commit `secrets.json`, the Firebase JSON, or `appsettings.Development.json`.
  All three are git-ignored — keep it that way.
- The service role key and the database password give full access to live
  student data, including scanned IDs. Treat them like the keys to the building.
- If a key ever ends up in a commit or a chat, rotate it in Supabase or Brevo
  rather than hoping nobody saw it.
