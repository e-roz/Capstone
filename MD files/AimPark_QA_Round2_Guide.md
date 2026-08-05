# AimPark — QA Round 2 Testing Guide

**For the next round of group testing.**
Covers everything built after the first round of feedback (Phases 1–6).

> ⚠️ **Nothing in this build has been run yet.** Every change passed static
> compile checks only — `dotnet build` for the API, `flutter analyze` for both
> apps. This round is the first time any of it executes.

---

## 1. Before you start — REQUIRED

### Apply the database migrations

Five migrations are pending. **Nothing below works until they run.**

```bash
cd "AimPark.API/AimPark.API"
dotnet ef database update
```

| Migration | What it does |
|---|---|
| `VehicleTypeAsEnum` | Unifies vehicle type spelling |
| `SmartSlotAllocation` | Adds gates, renames all 20 slots |
| `GateDeviceAuth` | Adds gate hardware table |
| `PerUserNotifications` | Lets notifications target one person |
| `TermsEvidenceAndDueDates` | Terms consent, appeal evidence, payment due dates |

### ⚠️ Every slot code has changed

`A1`–`A20` are gone. The lot is now:

| Gate | Codes | Type |
|---|---|---|
| 1 | `G1-C1`, `G1-C2` | Four-wheel |
| 1 | `G1-M1` … `G1-M8` | Motorcycle |
| 2 | `G2-C1`, `G2-C2` | Four-wheel |
| 2 | `G2-M1` … `G2-M8` | Motorcycle |

Any labels on the miniature need redoing.

### Test accounts you need

Slot allocation matches your **registered vehicle** against slot types. Before
testing, register and approve:

- at least one account with a **Car**
- at least one account with a **Motorcycle**

Without a registered vehicle, every allocation request returns
`NO_VEHICLE_REGISTERED`. That is correct behaviour, not a bug.

---

## 2. What was fixed — mapped to your original reports

### 🔴 Must-fix items

| Your report | Status | What to expect now |
|---|---|---|
| No logout confirmation | ✅ Fixed | Profile → Log Out asks first. Cancel keeps you in |
| Pending account: locked out with no explanation | ✅ Fixed | A real status screen — pending, rejected with the reason quoted, or suspended, plus when you may re-apply |
| No terms and conditions | ✅ Fixed | Required checkbox on the profile step, full terms readable in-app |
| Only "Other" incident category works | ✅ Fixed | All six categories submit |
| No photo attachment for evidence | ✅ Fixed | Appeals now take two photos. *(Incident reports already had three — they were unreachable because of the category bug)* |
| Need restart to see recent updates | ✅ Fixed | Pull-to-refresh on Home, auto-refresh on app resume, live refresh on push |
| Violations not immediately visible | ✅ Fixed | A violation now pushes to the phone with a badge, within seconds |

### 🟡 UX items

| Your report | Status | What to expect now |
|---|---|---|
| "+" next to the fee is confusing | ✅ Fixed | Reads `+10 pts` — it was always gamification points, never money |
| Tapping a fee should open payment | ✅ Fixed | Completed sessions show a chevron and open the payment screen |
| No deadline for paying | ✅ Fixed | "Due in 3 days" / "Due tomorrow" / "Overdue by 2 days", red when overdue |
| No way to edit or cancel a report | ✅ Fixed | Edit and Withdraw buttons, while the report is still unreviewed |
| Confusing how to pay | ◐ Partly | Faster route in and clear deadlines. Payment itself is still the mock flow |

### 🟢 Suggestions

| Your report | Status |
|---|---|
| Move logout out of the home header | ✅ Done — the header icon is gone; it lives in the profile menu |
| Dark mode | ❌ Deferred — every screen uses fixed colours, it is a large refactor |
| Help / tutorial section | ❌ Deferred |

### Admin panel round

| Your report | Status | What to expect now |
|---|---|---|
| Parking should be a visual layout, not a list | ✅ Fixed | A map of the lot: one card per gate, colour-coded bays, tap to change status |
| Slot assignment should be automatic | ✅ Fixed | Log Entry has "Assign automatically" and a "Scanning at gate" selector |
| Payments need a details / receipt button | ✅ Fixed | "Receipt" button on every row |
| Admin can't update violation data | ✅ Fixed | Edit button on issued violations; penalty and suspension can be corrected |
| Incidents need a details button | ✅ Fixed | "View" button. *The detail screen already existed — nothing indicated the row was clickable* |
| Registration filters | ⏸ Parked | Set aside pending a decision on what to filter by |

---

## 3. Bugs we found that nobody reported

These were discovered while fixing the above. Worth testing because they were
never on anyone's radar.

| Bug | Why it mattered |
|---|---|
| Logging out from the home icon left the device registered for push | The **next person** to log in on that phone could receive the previous user's notifications |
| Vehicle type was stored two different ways | Registration wrote `Car`/`Motorcycle`, slots used `Motor`/`4 Wheels`. Slot allocation would have matched nothing |
| Notification icons never matched their type | Every notification showed the same generic megaphone |
| The same vehicle could log entry twice | Orphaned the first session and left a bay stuck as occupied forever |
| Penalty/suspension overrides were unreachable | The API supported them; the admin dialog never sent them, so every violation silently took the rule default |
| Exit gate had no usable API call | Exit required an ID the hardware has no way of knowing |

---

## 4. New features to test

### Smart slot allocation

The system now picks a bay for you instead of an operator choosing one.

**How it decides:**
1. Your vehicle type filters what you can use. A car can never take a motorcycle bay. A motorcycle can take a car bay, but **only** once all 16 motorcycle bays are gone
2. It picks the gate you are standing at, if known
3. If that gate is full for your vehicle, it sends you to the other one
4. Within a gate: lowest slot code, skipping any bay freed in the last 2 minutes

Every answer comes with a plain-language reason, e.g.
*"Gate 1 is full for your vehicle — proceed to Gate 2."*

**To demo it:** set all 8 motorcycle bays at Gate 1 to Occupied in the admin
grid, then log a motorcycle entry with **Scanning at gate = Gate 1** and slot on
**Assign automatically**. You should be routed to Gate 2.

There is **no reservation** — the app's "Find me a slot" is advice only. The bay
is taken when the vehicle actually scans in.

### Per-user notifications

Notifications now fire automatically on: violation issued, violation dismissed,
appeal approved or denied, parking fee raised at exit, and registration approved
or rejected.

### Gate hardware support (ESP32)

The API is ready for the RFID reader. Not testable without hardware, but the flow
can be exercised with curl or Postman — see `ESP32_Gate_Integration.md`.

---

## 5. Test checklist

### Highest risk — test this first

**Open the app and check History and Home load at all.** A change to how parking
history is fetched is the single most likely thing to fail at runtime. If those
two screens load, the riskiest change is fine.

### Registration
- [ ] Terms checkbox blocks Continue until ticked
- [ ] Tapping "Terms & Conditions" opens the full text
- [ ] Vehicle step offers only Car and Motorcycle *(Van and Truck were removed — the lot has no bays for them)*
- [ ] Register, then try logging in before approval → status screen, not a toast
- [ ] Reject an account from admin → login shows the reason and the re-apply wait

### Home
- [ ] No logout icon in the header
- [ ] Pull down refreshes the parking card, activity and standing meter together
- [ ] Recent activity reads `+10 pts`
- [ ] A completed session has a chevron and opens the payment screen
- [ ] A session you are still parked in has no chevron and does not tap

### Incidents
- [ ] Submit a report in **each of the six** categories — all should succeed
- [ ] Attach photos
- [ ] Open your report → Edit, change the text, save
- [ ] Withdraw a report → confirmation, then marked Withdrawn
- [ ] Set the report to "Under Review" in admin → Edit and Withdraw disappear

### Violations and appeals
- [ ] Issue a violation from admin → **it should reach the phone as a notification** with a badge on Alerts
- [ ] Open it, appeal it, attach a photo
- [ ] Evidence shows back on the violation afterwards
- [ ] Approve or deny the appeal → the user is notified of the outcome
- [ ] Edit an issued violation, change the penalty → check the payment amount follows

### Payments
- [ ] Log an exit → fee notification arrives
- [ ] Payment shows a due date and days remaining
- [ ] Set a due date in the past in the database → shows red "Overdue"
- [ ] Admin → Payments → Receipt shows the full breakdown

### Parking / allocation
- [ ] Admin Parking shows two gate cards with colour-coded bays
- [ ] Tap a bay to change its status
- [ ] "Find me a slot" in the app returns a gate, slot and reason
- [ ] Fill Gate 1's motorcycle bays → a motorcycle gets routed to Gate 2
- [ ] Fill all 16 motorcycle bays → a motorcycle overflows into a car bay
- [ ] Fill all 4 car bays → a car gets "lot full"

### Notifications
- [ ] Badge appears on the Alerts tab and clears when read
- [ ] Background the app, issue a violation, reopen → the change is there
- [ ] Icons differ by notification type

---

## 6. Things that look like bugs but are not

| Behaviour | Why |
|---|---|
| A slot you just freed isn't offered again immediately | Bays vacated under 2 minutes ago sort last — the previous car may still be reversing out |
| Cars hit "lot full" quickly | There are only **4** four-wheel bays in the whole facility. That is the real layout |
| `NO_VEHICLE_REGISTERED` | That account has no vehicle on file |
| Existing accounts show no terms acceptance | Only new registrations record it. Nobody is locked out |
| Motorcycle put in a car bay | Correct once all 16 motorcycle bays are taken |

---

## 7. Known limitations

- **Payment is a mock.** "Pay Now" flips a status; there is no real payment gateway
- **Dark mode** not implemented
- **No help or tutorial** section
- **Registration filters** not implemented
- **Points and streaks** are computed in the app from real parking data — there is no scoring system in the backend
- **Gate hardware** not yet built; the admin panel is the stand-in

---

## 8. What we most want from this round

1. **Anything that crashes or shows a spinner forever** — highest priority
2. **Notifications that don't arrive.** This was the biggest fix; we need to know if it holds on real devices
3. **Allocation picking something odd** — tell us the slot it gave you and what was free at the time
4. **Wording that confuses people.** The reason messages, status screens and due-date phrasing are all new and unread by anyone outside the team
5. **Anything from the last round that is still broken** — that would mean a fix missed

Please note **which account and which gate** when reporting anything about
parking, since allocation depends on both.
