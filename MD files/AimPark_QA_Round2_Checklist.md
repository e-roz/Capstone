# AimPark — Round 2 Verification Checklist

**Work top to bottom.** Each step names the bug that existed before, so you know
exactly what you are confirming is gone.

Mark each: ✅ fixed · ❌ still broken · ⚠️ different problem

---

## STEP 0 — Setup (do first)

- [ ] **0.1** Run the migrations
  ```bash
  cd "AimPark.API/AimPark.API"
  dotnet ef database update
  ```
- [ ] **0.2** API starts with no errors
- [ ] **0.3** Slot codes are now `G1-C1`, `G1-M1`, `G2-C1`, `G2-M1`… — **not** `A1`–`A20`
- [ ] **0.4** Register + approve one **Car** account and one **Motorcycle** account

> Allocation matches your registered vehicle. Without 0.4, everything in Part I
> returns "no vehicle registered" — correct, but it looks like a failure.

---

## PART A — Registration

| | Step | Was broken | Should now |
|---|---|---|---|
| ☐ | **A.1** Start registration, reach the Profile step | — | — |
| ☐ | **A.2** Try Continue **without** ticking the terms box | 🔴 No terms existed at all | Blocked, with a message |
| ☐ | **A.3** Tap "Terms & Conditions" | 🔴 Nothing to read | Full 10-section terms opens |
| ☐ | **A.4** Tick the box, Continue | — | Proceeds to Vehicle |
| ☐ | **A.5** Look at the vehicle type options | — | **Only Car and Motorcycle.** Van and Truck removed — the lot has no bays for them |
| ☐ | **A.6** Finish registration, submit documents | — | "Pending review" |

---

## PART B — Login and blocked accounts

| | Step | Was broken | Should now |
|---|---|---|---|
| ☐ | **B.1** Try to log in with the account from Part A, **before** approving it | 🔴 **A toast flashed and vanished — user just appeared locked out with no explanation** | A **full status screen**: "Waiting for approval", explaining an admin is reviewing and there is nothing to do |
| ☐ | **B.2** Tap "Back to login" | — | Returns to login |
| ☐ | **B.3** In admin, **reject** that account with a reason | — | — |
| ☐ | **B.4** Try to log in again | 🔴 Same silent lockout | "Registration not approved", **the reason quoted**, and "You can re-apply in N day(s)" |
| ☐ | **B.5** Check the re-apply text | 🔴 Showed a raw timestamp like `2026-08-01T12:00:00.0000000Z` | Plain wording — "in 1 day", never a raw timestamp |
| ☐ | **B.6** Approve the account, log in | — | Reaches Home |

---

## PART C — Home screen

| | Step | Was broken | Should now |
|---|---|---|---|
| ☐ | **C.1** Look at the top-right of Home | 🟢 Logout icon sat in the header | **No logout icon.** It lives in the profile menu |
| ☐ | **C.2** Pull down on Home | 🔴 **Nothing happened — this is why the app felt frozen** | Refreshes the parking card, recent activity and standing meter together |
| ☐ | **C.3** Look at Recent Activity rows | 🟡 Read `+10`, looked like money next to a fee | Reads **`+10 pts`** |
| ☐ | **C.4** Tap a **completed** parking row | 🟡 Nothing happened | Chevron shown, opens the payment screen |
| ☐ | **C.5** Tap a row you are **currently parked** in | — | No chevron, does not tap *(no fee exists yet)* |
| ☐ | **C.6** Profile → Log Out | 🔴 Logged out instantly, no confirmation | Confirmation dialog. **Cancel keeps you logged in** |
| ☐ | **C.7** Log out, then log in as a **different** user on the same phone | ⚫ *Unreported:* the old home-icon logout left the device registered — **the new user could receive the previous user's notifications** | New user only ever gets their own notifications |

---

## PART D — Incident reports

| | Step | Was broken | Should now |
|---|---|---|---|
| ☐ | **D.1** Report an incident — category **Vandalism** | 🔴 **"Invalid" — only "Other" worked** | Submits |
| ☐ | **D.2** Same for **Theft** | 🔴 Invalid | Submits |
| ☐ | **D.3** Same for **Accident** | 🔴 Invalid | Submits |
| ☐ | **D.4** Same for **Blocked Slot** | 🔴 Invalid | Submits |
| ☐ | **D.5** Same for **Suspicious Activity** | 🔴 Invalid | Submits |
| ☐ | **D.6** Same for **Other** | ✅ Worked before | Still works |
| ☐ | **D.7** Attach photos to a report | 🔴 Reported as missing *(they existed — nobody reached them because of D.1–D.5)* | Three photo slots, upload works |
| ☐ | **D.8** Open your report → **Edit** | 🟡 **No way to fix a mistake** | Edit screen opens, changes save |
| ☐ | **D.9** Open your report → **Withdraw** | 🟡 No way to cancel | Confirmation, then marked Withdrawn |
| ☐ | **D.10** In admin set a report to "Under Review", then reopen it in the app | — | Edit and Withdraw **gone**, with a line explaining why |

---

## PART E — Violations and appeals

| | Step | Was broken | Should now |
|---|---|---|---|
| ☐ | **E.1** Issue a violation from admin against a test user | — | — |
| ☐ | **E.2** **Watch the user's phone** | 🔴 **Nothing ever arrived — the user never learned they were penalised** | Push notification within seconds, badge on Alerts |
| ☐ | **E.3** Open the violation, tap Submit Appeal | — | Appeal sheet opens |
| ☐ | **E.4** Attach photos to the appeal | 🔴 **No attachment option existed** | Two photo slots |
| ☐ | **E.5** Submit, then reopen the violation | — | Your evidence shown back under the appeal |
| ☐ | **E.6** Approve or deny the appeal in admin | — | User notified of the outcome, with admin notes |

---

## PART F — Payments

| | Step | Was broken | Should now |
|---|---|---|---|
| ☐ | **F.1** Log an entry then an exit for a test user | — | — |
| ☐ | **F.2** Watch the phone | — | Fee notification: duration and amount |
| ☐ | **F.3** Open the payment | 🟡 **No deadline anywhere — a fee read as optional** | Shows **"Due in 7 days"** and a "Due by" date |
| ☐ | **F.4** For a violation penalty, check the window | 🟡 None | **14 days** |
| ☐ | **F.5** Edit `DueAt` in the database to a past date, reopen | 🟡 No concept of overdue | **Red "Overdue by N day(s)"** on both the list and detail |
| ☐ | **F.6** Reach a payment from Home's Recent Activity | 🟡 Buried under Profile → My Payments | One tap from Home |

---

## PART G — Notifications and refresh

**This is the biggest fix in the build. Test it hardest.**

| | Step | Was broken | Should now |
|---|---|---|---|
| ☐ | **G.1** Leave the app **open on Home**. Issue a violation from admin | 🔴 **Required force-closing and reopening the app** | Arrives on its own, no manual action |
| ☐ | **G.2** **Background** the app. Issue another violation. Reopen | 🔴 Stale until restart | Data is current on reopen |
| ☐ | **G.3** Check the Alerts tab | 🔴 No indicator anywhere | **Red badge with a count** |
| ☐ | **G.4** Open and read them | — | Badge clears |
| ☐ | **G.5** Compare icons across notification types | ⚫ *Unreported:* every notification showed the same megaphone | Violation, payment, account each have their own icon |
| ☐ | **G.6** Approve a pending registration | — | That user is notified in-app, not only by email |

---

## PART H — Admin panel

| | Step | Was broken | Should now |
|---|---|---|---|
| ☐ | **H.1** Open Parking | Flat table of 20 rows | **Visual map** — one card per gate, colour-coded bays, free count |
| ☐ | **H.2** Tap a bay | — | Status picker |
| ☐ | **H.3** Open Incidents | "No button to view details" | **"View" button** on each row *(the screen existed — nothing showed the row was clickable)* |
| ☐ | **H.4** Open Pending Registrations | Same invisible-row problem | **"Review" button** on each row |
| ☐ | **H.5** Open Payments | "No button for details or receipt" | **"Receipt" button** → full breakdown |
| ☐ | **H.6** Violations → **Edit** an issued violation | 🔴 **Admin could not correct anything — only dismiss and re-issue, leaving a bogus record** | Edit dialog: description, penalty, suspension |
| ☐ | **H.7** Change the penalty amount and save | — | Payment amount follows the change; user notified |
| ☐ | **H.8** Try to Edit an **appealed** violation | — | No Edit button *(it is what both sides are arguing about)* |
| ☐ | **H.9** Issue Violation dialog — scroll down | ⚫ *Unreported:* penalty and suspension overrides existed in the API but **were unreachable**, so every violation silently took the rule default | Penalty amount, suspension type and days fields present |

---

## PART I — Smart slot allocation (new feature)

| | Step | Expected |
|---|---|---|
| ☐ | **I.1** App → Parking Availability → **"Find me a slot"** | Returns gate + slot + a plain-language reason |
| ☐ | **I.2** Admin Log Entry, slot left on **"Assign automatically"** | System picks the bay. Success message names it |
| ☐ | **I.3** Set all 8 motorcycle bays at **Gate 1** to Occupied. Log a motorcycle entry with **Scanning at gate = Gate 1** | Routed to **Gate 2**, reason says Gate 1 is full |
| ☐ | **I.4** Fill **all 16** motorcycle bays. Log a motorcycle entry | Overflows into a **car bay** — correct only at this point |
| ☐ | **I.5** Fill all **4** car bays. Log a car entry | "Lot full" — there really are only four |
| ☐ | **I.6** Log an entry for a user **already inside** | ⚫ *Unreported bug:* used to log a second entry, orphaning the first and jamming a bay forever. Should now refuse with "already inside" |
| ☐ | **I.7** Log an exit, immediately request a slot | The just-freed bay is **not** offered first *(2-minute cool-off — the previous car may still be reversing out)* |

---

## Regression sweep

Anything from round 1 that should still work:

- [ ] Register → OTP → profile → vehicle → documents, end to end
- [ ] Google sign-in
- [ ] Forgot password
- [ ] Admin approve / reject registration
- [ ] Parking history lists entries and exits
- [ ] RFID assign / revoke
- [ ] Admin broadcast notification reaches users

---

## Confirmed NOT fixed — do not file these

| Item | Why |
|---|---|
| 🟢 Dark mode | Deferred — every screen uses fixed colours, large refactor |
| 🟢 Help / tutorial section | Deferred |
| Registration filters | Parked pending a decision on what to filter by |
| Real payment gateway | "Pay Now" is still a mock that flips a status |

---

## If something fails

Note down:
1. **Which step number**
2. **Which account** (and its vehicle type)
3. **Which gate**, for anything parking-related
4. Screenshot if there is a message on screen

Allocation depends on account, vehicle type and gate — without those three, a
report cannot be reproduced.
