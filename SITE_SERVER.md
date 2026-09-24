# AimPark — Site Server (the guard post's own server)

Every gate decision runs on a server at the school. It checks the card, suspension, plate match and slot, logs the entry and exit, and computes the fee. The cloud keeps registration, user data, the mobile app, the admin panel, payments, email and push notifications.

```
 SCHOOL NETWORK                                   INTERNET
 ESP32 gate readers ─┐                            ┌──────────────────────┐
 ALPR guard PC ──────┼──► SITE SERVER ◄──────────►│ CLOUD API (Render)   │
 Guard's admin web ──┘    same API, Site mode     │ + Supabase           │
                          own local Postgres      └──────────────────────┘
```

## How the two stay in step

| Direction | What | When |
|---|---|---|
| Cloud → site | Users, cards, suspensions, plates, visitor passes, device keys, slots, rates, incidents | **Instantly.** The site keeps a live connection open to the cloud. When the cloud says "changed", the site downloads a fresh full copy. It also downloads on reconnect and every 5 minutes. |
| Site → cloud | Entry/exit logs, plate reads, gate attempts, slot occupancy, exit fees, notifications, incidents reported by guards | **Right after each car moves.** They go through an outbox. If the internet is down they wait and are sent when it's back. |

**When the internet is down**
- Gates keep working from the last copy.
- A suspension made in the cloud during the outage takes effect when the line comes back.
- The guard's gate screens and the **incident queue** keep working. Guards can report incidents and read the queue offline, and reports are sent when the internet is back.
- These need the internet: attaching photos to a report, and opening photos drivers attached. Offline, a report says how many attachments "can be viewed when the internet is back".
- The Gate Devices and Notifications screens show "needs the internet".

**Who owns what**
- The cloud decides whether a bay is **in service**. The site decides whether a **car is in it**.
- For visitor passes and incidents, the newer edit wins. A guard edits a report while it's still *Submitted*; an admin reviews it in the cloud.
- Payments are created at the site on exit, then settled in the cloud.

## Where the data lives

| | Supabase (cloud) | Local Postgres (guard PC) |
|---|---|---|
| Role | **The main record.** Everything, kept long-term. | **The gate's working copy.** Just what a gate decision needs. |
| People data | Users, registrations, documents, vehicles, violations, payments, notifications | A copy of users, cards, suspensions, plates, visitor passes, slots, rates |
| Gate history | A full copy, arriving from the guard PC right after each car moves | Where it is first written |
| Read by | Mobile app, admin panel, reports | Gate readers, ALPR PC, guard screens |
| If lost | Serious. Restore from backup. | Minor. Reinstall and it downloads everything again. Only records not yet sent are lost, and `/api/site/status` shows how many are waiting. |

Supabase Storage (document and photo files) is unchanged.

## One-time setup

### 1. Issue the site server's key (from the cloud)

Log in to the cloud admin to get a JWT, then:

```
curl -X POST https://aimpark-api.onrender.com/api/admin/gate-devices \
  -H "Authorization: Bearer <admin JWT>" -H "Content-Type: application/json" \
  -d '{ "name": "Guard Post Server", "gate": 0, "deviceType": 2 }'
```

`2` means `SiteServer`. The API reads enums as numbers. Keep the `apiKey` from the reply: it is only shown once.

### 2. Prepare the PC

1. Install PostgreSQL and the .NET 8 SDK.
2. Create an empty database, e.g. `AimParkSite`.
3. Copy `AimPark.API/AimPark.API/appsettings.Site.example.json` to `appsettings.Site.json` in the same folder and fill it in:
   - the local Postgres password;
   - **the same `Jwt` values as the cloud.** A guard who logs in at the site must also be accepted by the cloud for the screens that get forwarded;
   - the key from step 1.
4. Create the tables in the **local** database. Check the connection string before running this — it must not point at Supabase:
   ```
   cd AimPark.API/AimPark.API
   dotnet ef database update --connection "Host=localhost;Port=5432;Database=AimParkSite;Username=postgres;Password=..."
   ```

### 3. Build the guard's admin web against the site server

Use the site PC's LAN address, e.g. `192.168.1.10`:

```
cd aimpark_admin
flutter build web --dart-define=API_BASE_URL=http://192.168.1.10:5041
```

Copy `build/web` to the folder named in `Site:AdminWebPath`.

### 4. Run it (it starts by itself with the PC)

Open PowerShell with **Run as administrator**, then:

```
powershell -ExecutionPolicy Bypass -File C:\AimPark\site-server\install-service.ps1
```

The script:
- builds the server into `C:\AimPark\site-server-app`;
- installs it as the Windows service **AimPark Site Server**. The service starts when the PC turns on, even if nobody logs in, starts after PostgreSQL, and restarts itself 5 seconds after a crash;
- allows port 5041 on **private** networks only, so the readers can reach it;
- starts it and checks the status page.

Run the same script again after pulling new code or changing `appsettings.Site.json`; it updates in place. To remove the service, run `site-server\uninstall-service.ps1`.

Open `http://192.168.1.10:5041/api/site/status`. After a few seconds it should show `cloudConnected: true` and a `lastSnapshotAt` time.

**If something is wrong, look here:**
- the status page above;
- **services.msc** → *AimPark Site Server* (see if it's running, start or stop it);
- **Event Viewer** → Windows Logs → Application → source *AimParkSite*.

**To run it by hand instead**, stop the service first, then run this inside `AimPark.API/AimPark.API`:

```
dotnet run --no-launch-profile --environment Site --urls http://0.0.0.0:5041
```

`--no-launch-profile` matters: without it the Development profile loads `appsettings.Development.json`, which points at Supabase, not the local database.

The guard's admin panel is at `http://192.168.1.10:5041/`.

### 5. Point the hardware at it

| Device | Change |
|---|---|
| ALPR guard PC | `alpr-service/config.json` → `"api_base": "http://192.168.1.10:5041"` |
| ESP32 gate readers | Their API URL → `http://192.168.1.10:5041`. Keep the same keys: the site already has them. |
| Enrollment desk reader | No change needed. Enrollment is registration, so it stays with the cloud. |

### 6. Switch the cloud's gate traffic off

After **every** reader points at the site, set this in Render → Environment:

```
Site__CloudGateEndpointsEnabled=false
Site__GuardPanelUrl=http://192.168.1.10:5041/
```

From then on the cloud:
- refuses entry, exit and plate reads, with a message saying to use the guard post's server;
- refuses **Security** sign-ins on the Firebase admin panel, with the message "Security accounts sign in at the guard post: http://192.168.1.10:5041/". Admin sign-in is unchanged.

Before that switch, both places accept gate traffic, so nothing breaks while you move devices over one by one.

**If the guard PC is down:** set `Site__CloudGateEndpointsEnabled=true` again. Guards can then sign in on the Firebase panel and the cloud takes gate traffic until the guard PC is back.

## Migration note

This adds one table, `SyncOutbox`, in migration `AddSyncOutbox`. It is additive: applying it to the shared Supabase database creates an empty table the cloud never uses, and the deployed `main` keeps working.
