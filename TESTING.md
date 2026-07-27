# AimPark v1 — Testing Guide

**Status:** deployed for internal group testing
**Admin panel:** https://aim-park.web.app
**Mobile app:** APK link in the group chat
**Backend:** hosted on Render (nothing to install)

---

## 1. What v1 includes

Everything below is built and working end to end.

### Accounts
- Register with email + password (6-digit code sent by email), or Google Sign-In
- Admin approves or rejects each registration; rejected users can re-apply after a cooldown
- Forgot password by email code
- Three roles exist: Administrator, Security Personnel, User

### Mobile app (User)
- Dashboard, parking availability, parking history
- Violations: view, and submit an appeal
- Payments: view charges, pay (simulated), see history
- Incidents: report one with photo evidence, track its status
- Notifications with real push — arrives even when the app is closed
- Account: edit profile, change password, see RFID status

### Admin panel (web)
- Pending registrations: review documents, approve/reject
- User management: search, suspend, archive, restore, assign/revoke RFID tag
- Parking: manage slots, log vehicle entry and exit
- Payments: all transactions, set hourly rates per vehicle type
- Violations: issue, dismiss, and decide appeals
- Policy rules: define offences, penalty amounts, suspension lengths
- Incidents: review reports, set status, add notes
- Notifications: broadcast to all users or a specific role
- Reports: occupancy, peak hours, revenue, violation breakdown
- Audit log: every admin action, with who did it and when

---

## 2. Known gaps — **do NOT report these as bugs**

Read this first. These are already known and deliberately not in v1.

| Not built | Why |
|---|---|
| **Security Personnel dashboard is blank** | Role exists, screens not built yet |
| **Admin screen on mobile is blank** | Admin is intended to be used on the web |
| **No physical RFID / barrier gate / sensors / plate camera** | Hardware phase comes later. Entry/exit is logged manually in the admin panel as a stand-in |
| **One vehicle per user** | Multi-vehicle is planned, not built |
| **No visitor accounts** | Planned |
| **No automatic slot recommendation** | Admin picks the slot manually |
| **No CSV/PDF report export** | Planned |
| **Payment is simulated** | No real payment gateway; "Pay" just marks it paid |

### Also expected, not bugs
- **First action after idle takes ~50 seconds.** The free server sleeps and has to wake up. Only the first request is slow.
- **Verification emails may land in spam.** Mark "not spam" once and later ones behave.
- **You must be approved before logging in.** Register, then ask the admin to approve you.

---

## 3. Who tests what

So we don't all test the same screen and miss everything else. Test your area
deeply, then poke at anything else you like.

| Tester | Focus |
|---|---|
| 1 | Registration + login: email signup, Google signup, wrong passwords, forgot password, re-applying after rejection |
| 2 | Parking + payments: entry/exit logging, fee calculation, paying, history matching between admin and mobile |
| 3 | Violations + incidents: issuing, appealing, deciding appeals, reporting incidents with photos, review flow |
| 4 | Admin panel overall: user management, policy rules, notifications, reports, audit log |
| Everyone | Usability, wording, layout, anything confusing or ugly |

---

## 4. Kinds of testing to do

**1. Does it work (functional).** Follow a flow start to finish and confirm the result is correct in *both* apps. Example: admin logs an exit → mobile should show the completed session *and* a new pending payment with the right amount.

**2. Does it break (negative).** Deliberately do the wrong thing. Empty fields, wrong password five times, a plate number already registered, a huge photo, an expired code, hitting Submit twice fast. Nothing should crash or show a raw error.

**3. Is it confusing (usability).** The important one, and the easiest to under-report. If you paused, hesitated, or guessed — write it down. "I didn't know what this button did" is a real finding, not a complaint.

**4. Does it look right (UI).** Overlapping text, cut-off labels, misalignment, unreadable colours, weird spacing. Note your phone model — screens differ.

**5. Is it slow.** Anything that takes noticeably long *after* the first wake-up.

**6. Is it consistent.** Same wording, date format, and peso format everywhere? Does the admin panel agree with the mobile app?

---

## 5. How to report

One shared **Google Sheet**, one row per finding. Columns:

| # | Date | Tester | Area | What I did | What happened | What I expected | Severity | Device | Screenshot | Status |
|---|---|---|---|---|---|---|---|---|---|---|

**Severity:**
- **Critical** — can't proceed at all, data lost, app crashes
- **High** — major feature wrong, but there's a workaround
- **Medium** — works, but wrong or confusing
- **Low** — cosmetic
- **Suggestion** — idea for improvement, not a defect

**A good report:**
> Tapped "Pay" on a ₱25 parking fee. Spinner ran ~3s then nothing. Went back and reopened — it showed Paid. Expected instant confirmation. Severity: Medium. Redmi Note 13, Android 14. [screenshot]

**A bad report:**
> payments not working

The difference is that the first one can be fixed without a follow-up conversation. **Always include: what you tapped, what happened, what you expected, and a screenshot.**

---

## 6. Suggestions and new features

Log these too, marked **Suggestion**, in the same sheet. Include *why* — "add a search box on violations, I had to scroll a lot to find one user" is far more actionable than "add search."

We can't build everything before October, so we'll rank suggestions by impact
against effort. Log it anyway — an unbuilt idea we deliberately deferred is still
worth writing up in the capstone documentation.
