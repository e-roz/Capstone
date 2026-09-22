# PRODUCT DISCOVERY — AimPark Mobile App

**Date:** September 2026  
**Project:** AimPark Mobile Application Redesign  
**Phase:** Discovery (NOT Design)

---

## 1. PRODUCT UNDERSTANDING

### What is AimPark?

AimPark is a **smart parking management system** designed for controlled parking facilities (parking lots, campus garages, institutional facilities). It combines hardware sensors, license plate recognition, RFID access, and a mobile application to automate parking entry/exit, slot allocation, violation tracking, and payment collection.

The mobile application serves **registered drivers** who park at the facility. It is one of three interfaces in the system:
- **Mobile app** (user-facing, this redesign)
- **Admin web panel** (facility management, violations, payments, reporting)
- **Hardware** (RFID gates, ultrasonic sensors, ALPR cameras, ESP32 barrier controllers)

### Core Problems Solved

1. **Finding available parking** — Users can see real-time slot availability instead of driving in circles
2. **Automated entry/exit** — RFID + ALPR eliminates manual barriers and reduces friction
3. **Transparent pricing** — Users know parking costs upfront; fees are calculated automatically at exit
4. **Violation management** — Policy violations are recorded, communicated, and can be appealed
5. **Payment tracking** — All parking fees and penalties are centralized and can be paid digitally

### System Architecture (from user's perspective)

- **Registration** — User provides email, driver's license photo, vehicle info, and plate number. Admin approves or rejects.
- **Entry** — User scans RFID tag at gate (or gate reads ALPR). System reserves a parking slot and tracks entry time.
- **Parking** — User sees available slots, current parking session, history, violations, and account balance in the app.
- **Exit** — User scans RFID tag at gate. System calculates parking fee based on duration and records exit. Payment is due immediately.
- **Payment** — User pays outstanding fees through the app (integrated payment gateway or simulated checkout).
- **Violations** — Admin can issue violations for policy breaches (parking violation, overtime, unauthorized vehicle). User sees violation, can appeal with evidence.

### Key Capabilities (Core to Secondary)

**Core:**
- Real-time parking slot availability
- Current parking session tracking
- Parking history (all entries/exits)
- Automatic fee calculation
- Digital payments
- Violation history and appeals
- Account standing/good standing meter

**Secondary:**
- Incident reporting (user-initiated complaints)
- Account management (profile, password, vehicles)
- Notifications and push alerts
- Gamification (points, streak, standing tiers)

---

## 2. USERS

### User Type 1: Student / Campus Parkers
**Who:** Students, staff, or regular patrons of a campus or institutional parking facility.

**Role:** End user. Drives a registered vehicle. Enters and exits the parking lot.

**Primary Goals:**
- Find a parking spot quickly
- Understand parking costs upfront
- Manage parking fees (pay on time)
- Maintain good standing to avoid violations

**Secondary Goals:**
- Track parking history for reimbursement or personal records
- Report incidents (theft, damage, trespassing)
- Manage multiple vehicles
- Receive notifications about violations or overdue fees

**Features Used:**
- Dashboard (home screen) — current parking status, availability, balance
- Parking slots — find and reserve a slot
- Payment — view fees, pay outstanding balance
- Violations — view violations, file appeals
- History — view past parking sessions
- Incidents — report a problem

**Information Needs:**
- "Am I parked right now?"
- "How many free slots are available?"
- "How much do I owe?"
- "What violations do I have?"
- "How much did my last parking session cost?"
- "Can I appeal this violation?"

**Critical Decisions:**
- Should I drive into the lot right now? (availability)
- Which slot should I park in? (recommendation)
- Should I pay now or later? (payment timing)
- Should I appeal this violation? (appeal)

---

### User Type 2: Security Personnel / Gate Guards
**Who:** Facility staff monitoring entry/exit points and access control.

**Role:** Secondary user. Monitors RFID scans, confirms vehicle identity, handles exceptions.

**Primary Goals:**
- Monitor real-time entry/exit
- Handle access violations (suspended RFID, unauthorized vehicle)
- Override the automated barrier when needed (guest vehicle, equipment, etc.)

**Secondary Goals:**
- View incident reports
- Communicate with users about access issues
- Log manual entries/exits

**Features Used:**
- Dashboard — recent access logs, current occupancy
- Monitoring — view entry/exit in real time
- Access control — manually override barriers

**Information Needs:**
- "Who just entered?"
- "Is this vehicle registered?"
- "Is this RFID suspended?"
- "How full is the lot right now?"

---

### User Type 3: Administrator
**Who:** Facility manager, parking administrator, finance staff.

**Role:** Admin user. Manages users, violations, payments, and facility configuration.

**Note:** Admin uses a separate **web panel**, not the mobile app. The mobile app does NOT have an admin mode.

---

## 3. USER GOALS

### Student/Parker User Goals (Major Workflows)

| Feature | Task | Goal | Underlying Need |
|---------|------|------|-----------------|
| Dashboard | View parking availability and current status | Know if a slot is free and if I'm parked | Reduce uncertainty; make a quick decision |
| Parking Slots | Find and reserve a slot | Get a recommended spot automatically | Reduce cognitive load; avoid driving in circles |
| Payments | View bill and pay fee | Settle parking costs | Maintain good standing; avoid late fees |
| Violations | View violation and file appeal | Contest an unfair charge | Preserve reputation/standing; seek fairness |
| History | Review past sessions | Track expenses, verify charges | Personal accountability; reimbursement |
| Incidents | Report damage or theft | Create a record with the facility | Seek recourse; document the problem |

---

## 4. CORE USER JOBS

### Job 1: Find Out If I Can Park Right Now

**Trigger:** User opens the app or arrives at the facility.

**Goal:** Know instantly if there is a free slot for my vehicle type.

**Information Needed:**
- Total available slots (by type, if different)
- Current occupancy
- Lot status (open, full, restricted)

**Actions:**
1. Open app
2. View home screen / parking hero card

**Decisions:**
- Do I have time to park? (if lot is full)
- Do I go now or wait? (if low availability)

**Expected Outcome:** User sees "15 slots free" or "Lot is full" within 1 second.

**Current Friction:**
- Availability data may be stale if not refreshed (app fetches once on launch)
- User must tap to see details; headline number is not prominent enough on first load

---

### Job 2: Park My Vehicle

**Trigger:** User has decided to enter the lot.

**Goal:** Get assigned a specific parking slot and enter the lot without confusion.

**Information Needed:**
- Recommended slot based on vehicle type and lot occupancy
- Gate location
- Slot location/directions (future)

**Actions:**
1. Open app / parking screen
2. View available slots (or tap "Find a slot")
3. See recommended slot assignment
4. Scan RFID at gate
5. Drive to assigned slot

**Decisions:**
- Accept the recommended slot or choose a different one?
- Which gate? (currently only one gate exists; will expand)

**Expected Outcome:** User drives to slot, scans RFID, system confirms entry.

**Current Friction:**
- Smart slot allocation is NOT YET IMPLEMENTED (major gap)
- User sees static list of all slots instead of a recommendation
- No feedback on which gate to use

---

### Job 3: Check My Balance and Pay

**Trigger:** User wants to settle outstanding parking fees or has received a notification about overdue payment.

**Goal:** Understand what is owed and pay quickly.

**Information Needed:**
- Total amount owed
- Breakdown by session (which sessions, which slots, how long)
- Due dates
- Payment method options

**Actions:**
1. Open app
2. Navigate to Payments
3. View list of unpaid sessions
4. Tap a session to see detail (amount, duration, slot, date)
5. Tap "Pay" to proceed to checkout
6. Complete payment

**Decisions:**
- Pay now or wait? (if not overdue)
- Pay one fee or all outstanding fees?

**Expected Outcome:** User can see all unpaid fees and complete payment in <2 minutes.

**Current Friction:**
- Payment list shows only totals; detail is one tap away
- No indication on home screen that money is owed (until the "Payment Due" card was added in Phase 1)
- Payment history is separate from unpaid list; user must switch tabs to compare

---

### Job 4: Handle a Violation

**Trigger:** User receives a push notification or sees a violation on the dashboard.

**Goal:** Understand the violation and decide whether to pay the penalty or appeal it.

**Information Needed:**
- What rule was violated? (policy, reason)
- When did it happen? (date, time, location)
- Penalty amount
- Appeal deadline
- Evidence (photos, if available)

**Actions:**
1. Open notification or navigate to Violations
2. View violation list
3. Tap violation to see detail
4. Read violation description and evidence
5. Decide: Pay or Appeal?
6. If appealing: Attach evidence, write explanation, submit
7. If paying: Navigate to Payments

**Decisions:**
- Is the violation justified? Should I appeal?
- Do I have evidence to support my appeal?
- Can I afford to pay the penalty?

**Expected Outcome:** User understands the charge and takes action within 24 hours.

**Current Friction:**
- Violation may never reach the user if they miss the push notification (root cause ①)
- Violation detail view exists in code but may not be visible (invisible affordances in admin)
- No "Pay this violation" button; user must cross-reference with Payments
- Appeal requires attaching evidence, but the field exists only on the backend; it's not exposed in the UI
- User may not receive confirmation that their appeal was submitted

---

## 5. USER MOTIVATIONS

### Dashboard (Availability Check)

**Why would the user begin this task?**
- Arriving at the facility; needs to decide whether to enter
- Opening the app to see general status

**What outcome do they expect?**
- One number: how many slots are free
- Secondary: my current parking status

**What would make them feel confident?**
- The number is updated live (not stale)
- A timestamp shows when it was last updated
- The number updates automatically when they leave the app and return

**What would make them hesitate?**
- Number is outdated (e.g., shows 15 slots free but they see a full lot at the gate)
- App crashes or shows an error
- Number is hard to find or hidden behind a tap

**What would make them abandon the task?**
- App takes >3 seconds to show availability
- They get an error and no fallback information
- They see the parking hero card is blank and the app looks broken

**Psychological principle (Psychology of UI/UX):**
- **Expectation alignment** — Users expect data to be live and match reality. A stale number breaks trust.
- **Feedback immediacy** — Users want to know instantly; even a 2-second delay causes anxiety.
- **Progressive disclosure** — Show the one number they need upfront; details are one tap away.

---

### Parking (Slot Assignment)

**Why would the user begin this task?**
- They have decided to park and need a slot assignment
- They are at the gate and the RFID reader is prompting them

**What outcome do they expect?**
- The app tells them which slot to use
- They drive there, scan again, the barrier opens

**What would make them feel confident?**
- The app shows "Gate 1, Slot M3" with a clear visual (floor plan or grid)
- The slot is guaranteed; they won't arrive to find it occupied
- They get a push notification confirming entry

**What would make them hesitate?**
- The app recommends a slot far away ("upstairs," "far corner")
- They are unsure whether the slot is actually free or reserved by someone else
- The app doesn't show where the gate is relative to their current location

**What would make them abandon the task?**
- The app crashes or fails to assign a slot
- They get assigned to a slot that is already occupied when they arrive
- The assignment times out and they have to restart

**Psychological principle (Psychology of UI/UX):**
- **Certainty** — Users want a guarantee, not a suggestion. Reserved slots should feel locked in.
- **Cognitive load** — Don't make the user choose; recommend the best option.
- **System status visibility** — Show the slot code, gate number, and a mini-map. Transparency builds confidence.

---

### Payment (Settling a Fee)

**Why would the user begin this task?**
- They received an overdue notice
- They want to settle their balance to maintain good standing
- They are checking whether a session cost them anything

**What outcome do they expect?**
- They see their total balance
- They can tap "Pay" and complete payment in <1 minute
- They receive confirmation that the payment succeeded

**What would make them feel confident?**
- The fee is explained ("Parking session at Slot B-14, 2 hours @ ₱50/hour = ₱100")
- They know the payment method is secure
- They see a receipt after paying

**What would make them hesitate?**
- The app shows ₱500 owed but they only parked twice; they don't understand the breakdown
- The payment button is disabled or missing
- They start the payment but the page hangs

**What would make them abandon the task?**
- The checkout page has errors or is confusing
- Their payment fails and the app doesn't explain why
- They have to re-enter their card info multiple times

**Psychological principle (Psychology of UI/UX):**
- **Transparency** — Break down the charge (date, duration, rate, total). Users want to verify the math.
- **Friction reduction** — Minimize steps to payment; use saved payment methods.
- **Confirmation** — Show success clearly; "Payment complete ✓" beats a silent redirect.

---

### Violation (Understanding and Appealing)

**Why would the user begin this task?**
- They received a push notification about a violation
- They see a violation badge on their dashboard
- They want to check their record

**What outcome do they expect?**
- They understand what rule was violated
- They know how much the penalty is
- They can decide whether to pay or appeal

**What would make them feel confident?**
- The violation states the rule, date, time, and location clearly
- They see evidence (photo, timestamp, sensor reading) if available
- There is a clear "Appeal" button with an explanation of how appeals work

**What would make them hesitate?**
- The violation is vague ("Policy violation") with no detail
- They are unsure whether they can appeal or whether appeals are reviewed fairly
- They don't know the deadline for appeal

**What would make them abandon the task?**
- The violation is phrased harshly or accusingly; they feel attacked
- The appeal form is complex and requires technical details they don't have
- They submit an appeal but hear nothing back; they assume it was ignored

**Psychological principle (Psychology of UI/UX):**
- **Clarity over judgment** — State facts, not interpretations. "You exited at 17:30 after 3 hours" not "You stayed too long."
- **Procedural transparency** — Explain how appeals are reviewed and what the timeline is.
- **Agency** — Give users a clear way to contest; make appeals feel like they will be heard.
- **Outcome communication** — Notify the user when their appeal is reviewed and what the decision was.

---

## 6. USER FRICTION

### Friction Point 1: Availability Data is Not Live

**Current behavior:** App fetches parking availability once on launch. If the user leaves the app for 5 minutes and comes back, the number is stale.

**User problem:** User sees "15 slots free" but arrives at a full lot. Availability changed while they were in the car or at the facility entrance.

**UX implication:** 
- User loses trust in the app ("the data is wrong")
- User wastes time driving to a lot that is full
- User has no way to refresh except by restarting the app

**Why it happens:** Root cause ② — the app uses `IndexedStack` to keep all tabs alive, so providers never dispose and never re-fetch.

---

### Friction Point 2: Smart Slot Allocation Does Not Exist

**Current behavior:** App shows a static list of all 20 slots with their occupancy status. User must manually choose one.

**User problem:** User is overwhelmed by 20 options or picks a slot far away. User has to scroll and compare, adding cognitive load.

**UX implication:**
- Decision paralysis ("which one should I pick?")
- Suboptimal choices (user picks a far slot when a closer one is available)
- No guarantee the chosen slot is still free when user arrives there

**Why it happens:** Phase 3 (Smart Slot Allocation) is not yet implemented. The backend has no `recommend` endpoint.

---

### Friction Point 3: Violations Never Reach the User

**Current behavior:** Admin issues a violation. User receives a push notification. If the user dismisses the notification or the phone is offline, the user never learns about the violation.

**User problem:** User's standing degrades. User is locked out of appeals. User has no idea why their card stopped working.

**UX implication:**
- User feels blindsided ("why am I suspended?")
- User cannot appeal because they never saw the violation
- User loses trust in the system

**Why it happens:** Root cause ① — violations are issued but not wired into the notification service. Push is the only delivery mechanism.

---

### Friction Point 4: Payment Information is Fragmented

**Current behavior:** 
- Home screen shows a summary balance (if owed)
- Payments tab shows a list of unpaid fees
- Each payment row shows amount and status; details require a tap

**User problem:** User wants to know "did my last session cost me anything?" but has to:
1. Open app
2. Navigate to Payments
3. Sort by date
4. Tap to see details

**UX implication:**
- User may not realize they owe money until they see a late-fee notification
- User cannot quickly verify charges

**Why it happens:** The dashboard card is new (Phase 1 addition); before that, payment info was completely hidden until the user navigated away from home.

---

### Friction Point 5: Violation Detail and Appeals Are Invisible

**Current behavior:** 
- Violations list screen exists and works
- Violation detail screen exists and works
- Admin incident & pending-registration lists have no visual "tap me" affordance; the row is clickable but not labeled

**User problem:** User sees the violations list but doesn't know the rows are tappable. User thinks the detail view is missing.

**UX implication:**
- Testers reported the violation detail view as a missing feature
- Feature already exists but is undiscoverable

**Why it happens:** Row click uses `onSelectChanged` with no visual cue (no trailing button, no chevron, no highlight).

---

### Friction Point 6: Appeal Form is Incomplete on the Mobile Client

**Current behavior:**
- `SubmitAppealDto` on the backend accepts `penaltyAmountOverride`, `SuspensionTypeOverride`, `SuspensionDaysOverride`, and evidence attachments
- Mobile app's appeal form is text-only; evidence field is not exposed

**User problem:** User wants to attach a photo (e.g., "my parking permit was visible") but has no way to do so. Appeal must go in without evidence.

**UX implication:**
- Appeals are less likely to be upheld without evidence
- User feels the appeal process is half-baked

**Why it happens:** Mobile client was built before the backend had evidence attachment support. The UI was never updated.

---

### Friction Point 7: Session Points Are Confusing

**Current behavior:** Parking history shows "+10 pts" for each session. User doesn't know what points are for or how they affect anything.

**User problem:** User sees "+10 pts" but the dashboard shows "250 points." Where did the rest come from? Is 250 good? What does it unlock?

**UX implication:**
- Gamification doesn't land because the system is unexplained
- User doesn't understand the good-standing meter

**Why it happens:** Points are computed client-side from parking history (10 per session + 50 per full week of streak) but the calculation is opaque.

---

### Friction Point 8: Incident Reporting Has Low Discoverability

**Current behavior:**
- Incident reporting is accessible via the Quick Actions grid on home
- There is a Report button on the profile/account screen
- User must navigate away from home to report

**User problem:** User witnesses damage or theft at the parking lot. User has to navigate through the app to report; by the time they find the button, they've forgotten details or the moment has passed.

**UX implication:**
- Incidents are under-reported
- User feels the app doesn't make it easy to help

**Why it happens:** Home screen is crowded; incident button is one of 6 equal actions.

---

## 7. USER UNCERTAINTY

For each critical workflow, the app should answer these questions:

### Parking (Finding a Slot)

- ❓ Will the user know what to do next? — **NO.** They see a list of 20 slots with occupancy; no guidance on which to choose.
- ❓ Will they know why they are doing it? — **YES.** They need a place to park.
- ❓ Will they know whether an action succeeded? — **MAYBE.** Slot shows as "occupied" after entry, but there's a 5-10 second delay.
- ❓ Will they know what is currently happening? — **PARTIALLY.** A "reserved" status exists on the backend but doesn't show on the client.
- ❓ Will they know what happens next? — **NO.** After selecting a slot, user is unclear whether the slot is locked in or just a suggestion.
- ❓ Will they know whether an action can be undone? — **NO.** There is no "cancel reservation" feature visible.
- ❓ Will they know what information is required? — **N/A** (no form).
- ❓ Will they understand errors and how to recover? — **NO.** If slot assignment fails (race condition), the error message is generic.

**UX needs:**
- Reduce choices (recommendation instead of list)
- Confirm selection ("Slot M3 is reserved for you until 14:30")
- Show countdowns (time remaining before reservation expires)
- Make errors actionable ("This slot was just taken. Try another?" with a retry button)

---

### Payment (Settling a Fee)

- ❓ Will the user know what to do next? — **MOSTLY.** Payments list is clear; tap to pay.
- ❓ Will they know why they are doing it? — **YES.** Balance is explained on the dashboard.
- ❓ Will they know whether an action succeeded? — **YES.** Checkout page shows a success screen.
- ❓ Will they know what is currently happening? — **PARTIALLY.** Payment processing spinner is shown, but no text explains the delay.
- ❓ Will they know what happens next? — **MOSTLY.** Success screen says "Payment complete" but doesn't confirm when the balance will update.
- ❓ Will they know whether an action can be undone? — **NO.** Once paid, no way to request a refund through the app.
- ❓ Will they know what information is required? — **MOSTLY.** Checkout page is from the payment provider; if payment details are needed, the provider's form is clear.
- ❓ Will they understand errors and how to recover? — **MAYBE.** Payment provider error messages are sometimes cryptic ("Declined" with no reason).

**UX needs:**
- Show order total before final commit
- Explain any delays ("Processing… this may take 10 seconds")
- Confirm the balance updated in near real-time
- Provide refund/dispute instructions

---

### Violation (Reading and Appealing)

- ❓ Will the user know what to do next? — **NO.** Violation detail exists but is not discoverable. Even if found, appeal form isn't clear.
- ❓ Will they know why they are doing it? — **SOMETIMES.** Violation text may be generic ("Policy violation").
- ❓ Will they know whether an action succeeded? — **NO.** Appeal submission shows no confirmation.
- ❓ Will they know what is currently happening? — **NO.** No indicator of whether the appeal is under review, accepted, or rejected.
- ❓ Will they know what happens next? — **NO.** No timeline for appeal review is communicated.
- ❓ Will they know whether an action can be undone? — **NO.** Appeals cannot be withdrawn.
- ❓ Will they know what information is required? — **NO.** Appeal form doesn't say whether evidence is required or optional.
- ❓ Will they understand errors and how to recover? — **NO.** No error handling for failed appeal submissions.

**UX needs:**
- Discoverable violation detail view (make rows obviously tappable)
- Clear violation description (rule, date, time, location, sensor data if available)
- Evidence view (photos, timestamps)
- Prominent "Appeal" button with expected outcome ("Submit evidence and explain your case; decision in 3–5 business days")
- Appeal submission confirmation
- Appeal status tracker (under review, approved, rejected, with reason)

---

## 8. PSYCHOLOGICAL USER JOURNEYS

### Journey 1: Deciding Whether to Park

```
Trigger ("I'm driving toward the facility")
    ↓
Motivation ("I need a parking spot")
    ↓
Expectation ("The app will tell me if there's space")
    ↓
Action (Open app, look at home screen)
    ↓
Uncertainty/Confidence ("I see '15 slots free'... is that true right now?")
    ↓
Feedback (No explicit timestamp; data may be stale)
    ↓
Progress (User is slightly reassured but not confident)
    ↓
Completion ("I'll drive in and see")
    ↓
Confirmation (User arrives and sees available slots match the app)
    
❌ FAILURE CASE: User arrives to find lot is full. Trust in app is broken.
```

**Psychological principles:**
- **Expectation-reality alignment** — Data must be fresh and match ground truth.
- **Transparency** — Show when data was last updated.
- **Immediate feedback** — Updates should reflect within 5 seconds of a change.

---

### Journey 2: Parking and Getting Assigned a Slot

```
Trigger ("I've decided to enter the lot")
    ↓
Motivation ("I need to find my slot quickly")
    ↓
Expectation ("The app will tell me which slot to use")
    ↓
Action (Open Parking Slots screen, see 20 options)
    ↓
Uncertainty/Confidence ("Which one should I pick? They all look the same.")
    ↓
Cognitive Load (User must compare occupancy, distance, vehicle type)
    ↓
Decision (User picks one that looks close)
    ↓
Progress (User drives to slot M3)
    ↓
Completion (User scans RFID, barrier opens, entry is logged)
    ↓
Confirmation (App shows "Currently Parked" at M3)
    
❌ FAILURE CASE: Slot was taken by another user. User must go back and pick again.
```

**Psychological principles:**
- **Cognitive load** — Don't make the user choose; recommend the best slot.
- **Certainty** — Reserve the slot so it's guaranteed when user arrives.
- **Feedback immediacy** — Confirm entry with a visual indicator within 2 seconds.

---

### Journey 3: Handling a Violation

```
Trigger (Push notification: "Violation issued")
    ↓
Motivation ("What happened? Did I do something wrong?")
    ↓
Expectation ("The app will explain the violation")
    ↓
Action (Tap notification or open Violations tab)
    ↓
Uncertainty/Confidence ("I see a list of violations but no detail")
    ↓
Confusion ("Can I tap on this row? Is there a detail view?")
    ↓
Action (User taps row, detail screen appears... or nothing happens)
    ↓
Frustration/Relief (If detail appears: user reads violation. If not: user gives up.)
    ↓
Decision ("Should I pay or appeal?")
    ↓
Action (User appeals, submit button is hit)
    ↓
Uncertainty/Confidence ("Did my appeal go through? When will I hear back?")
    ↓
Abandonment (No confirmation shown; user assumes it worked or failed)

❌ FAILURE CASE: Violation never reached user because they missed push notification.
❌ FAILURE CASE: Appeal submitted but no confirmation; user resubmits or gives up.
```

**Psychological principles:**
- **Feedback visibility** — Every action (tap, submit) should have a clear result.
- **Transparency** — Explain the violation fairly; don't make it sound like accusation.
- **Procedural clarity** — Tell the user what happens next and when.
- **Agency** — Make appeals feel like they will be heard, not ignored.

---

## 9. MOMENTS THAT MATTER

### 1. First Open (Splash → Login → Dashboard)

**Why it matters:** User's first impression of the app's responsiveness and polish.

**Current state:** Splash screen is fast; login form is clear. Dashboard loads the parking hero card first, then fills in profile/stats.

**Opportunity:** Make the hero card (availability) load even faster. If the card is slow, the app feels broken.

---

### 2. Arrival at Facility (Checking Availability)

**Why it matters:** User is in the car; they need to make a decision in <5 seconds.

**Current state:** Availability is shown, but it's not live-updating. User may see stale data.

**Opportunity:** Make availability refresh-on-resume (when user opens the app from their car). Show a timestamp to signal freshness.

---

### 3. Entering the Lot (Slot Assignment at RFID Gate)

**Why it matters:** User is at the barrier; the gate is opening/closing. Timing is critical.

**Current state:** User taps "Find a slot" on home, sees list, picks one, scans RFID. Slot assignment happens server-side after RFID scan.

**Opportunity:** Assign the slot before the RFID scan (pre-reserve) or immediately after scan (within 1 second). Show clear confirmation: "Slot M3 reserved" with a mini-map.

---

### 4. Receiving a Violation Notification

**Why it matters:** User's emotional reaction to the notification sets the tone for whether they will appeal or just pay.

**Current state:** Push notification arrives. If the user taps it, they navigate to violations list. If they dismiss, they may never see the violation.

**Opportunity:** Notification should link directly to violation detail, not just the list. Violation detail should be discoverable and should explain the charge clearly.

---

### 5. Deciding to Pay an Outstanding Fee

**Why it matters:** User is at a decision point: pay now, wait until deadline, or ignore. The app should make the choice easy.

**Current state:** Payment due card on home shows balance; Payments tab shows list. User can tap "Pay" from either place.

**Opportunity:** Add a "Pay now" button to the payment due card and to each payment row. Make checkout <1 tap from dashboard.

---

### 6. Filing an Appeal on a Violation

**Why it matters:** User is in a vulnerable state (they may feel wrongly charged). The app should feel fair and empowering.

**Current state:** Appeal form is text-only; no evidence field. Form may not be discoverable.

**Opportunity:** Make the form discoverable and prominent on the violation detail screen. Add evidence upload. Show what happens next ("Appeal under review; you'll hear back in 3–5 days").

---

### 7. Completion of Registration (Waiting for Admin Approval)

**Why it matters:** User is in limbo; they don't know if they can use the app yet.

**Current state:** User is redirected to an "Account Status" screen that shows pending or rejected.

**Opportunity:** Make the status screen more prominent on home dashboard. Show what's missing if rejected (resubmit docs). Show ETA for approval.

---

## 10. UX OPPORTUNITIES

### Opportunity 1: Live Availability Refresh

**Problem:** Availability data is stale when user leaves the app and returns.

**User impact:** User cannot trust the app's data. User wastes time driving to a full lot.

**Psychological consideration:** Expectation-reality alignment. Users expect app data to reflect the real world.

**UX opportunity:** Implement `WidgetsBindingObserver` to refresh availability when the app resumes from background. Show a refresh timestamp or "Updated just now" on the hero card.

---

### Opportunity 2: Smart Slot Recommendation

**Problem:** User is overwhelmed by 20 choices and must manually pick a slot.

**User impact:** Decision paralysis. Suboptimal parking choices. No guarantee slot is still free when user arrives.

**Psychological consideration:** Cognitive load reduction. Users prefer a confident recommendation over an open choice.

**UX opportunity:** Implement the `POST /api/parking/recommend` endpoint (Phase 3). Show one recommended slot prominently ("We recommend Slot M3 — Gate 1, close to you"). Show runners-up below. Pre-reserve the slot for 10 minutes. Show countdown before hold expires.

---

### Opportunity 3: Violation Notification That Actually Reaches Users

**Problem:** Violations issued by admin do not trigger notifications. User only learns about violations if they happen to open the Violations tab.

**User impact:** User's standing degrades invisibly. User cannot appeal. User loses trust in the system.

**Psychological consideration:** System transparency. Users expect to be notified when something bad happens to their account.

**UX opportunity:** Wire the notification service into `ViolationService.IssueAsync` (Phase 5). Send a push notification the moment a violation is issued. Include a deep link directly to the violation detail screen.

---

### Opportunity 4: Discoverable Violation Detail and Appeals

**Problem:** Violation detail view exists but is not discoverable. Appeal form is text-only and lacks evidence field.

**User impact:** User doesn't know violations are tappable. User tries to appeal but has no way to attach evidence.

**Psychological consideration:** Agency and procedural clarity. Users want to feel they can contest a charge fairly.

**UX opportunity:** Make violation rows obviously tappable (add trailing arrow, highlight on tap). Show the detail screen prominently. Add an "Appeal" button with a form that accepts evidence uploads. Show appeal status and timeline.

---

### Opportunity 5: Payment Clarity and Fast Checkout

**Problem:** Payment info is scattered across the home card, Payments list, and detail screens. User must tap multiple times to pay.

**User impact:** User may not realize they owe money until after the deadline. User takes too long to check out.

**Psychological consideration:** Transparency and friction reduction. Users want to quickly understand and settle charges.

**UX opportunity:** Show the most recent unpaid session prominently on the home dashboard. Add a "Pay" button directly on the home card (not just a link to Payments). Show a clear checkout flow with order review and confirmation.

---

### Opportunity 6: Explain Points and Gamification

**Problem:** Points, streak, and standing are shown but not explained. User doesn't know what they unlock or whether they matter.

**User impact:** Gamification doesn't land. User doesn't feel motivated to maintain standing.

**Psychological consideration:** Clarity of purpose. Users want to know why they're being tracked and rewarded.

**UX opportunity:** Add a "How It Works" section to the dashboard or a dedicated "Gamification" screen. Explain: "+10 pts per parking session," "+50 pts per full week of streak," "Gold standing = no violations," "Silver = 1 violation," "Bronze = 2+." Show what happens if standing drops (e.g., temporary RFID suspension).

---

### Opportunity 7: Incident Reporting Accessibility

**Problem:** Incident reporting is accessible but not prominent. User has to navigate away from home to report.

**User impact:** Incidents are under-reported. User feels the app doesn't make it easy to help.

**Psychological consideration:** Accessibility and perceived control. Users want to feel they can quickly address a problem.

**UX opportunity:** Add a floating action button (FAB) for "Report Incident" or move the incident button to the header. Keep the form short (title, description, photo). Show confirmation that the report was received.

---

### Opportunity 8: Appeal Evidence and Outcome Communication

**Problem:** Appeal form is text-only. No confirmation after appeal is submitted. No status update on outcome.

**User impact:** User feels the appeal was ignored. Appeal is less likely to be upheld without evidence.

**Psychological consideration:** Agency and outcome communication. Users want to know their appeal is being heard and when they'll get an answer.

**UX opportunity:** Add evidence upload to appeal form. Show appeal submission confirmation. Add an "Appeal Status" view that shows: "Under Review" (with ETA), "Approved" (with reason), "Rejected" (with reason and retry option).

---

## 11. INITIAL UX PRINCIPLES

Based on the discovery analysis, these principles should guide the redesign:

1. **Make System Status Visible** — Users should always know: "Am I parked?" "How much do I owe?" "What happened to my appeal?" Avoid invisible state; surface key information on the home screen.

2. **Reduce Uncertainty Through Transparency** — Violations, fees, and appeals should be explained clearly and fairly. Show data freshness (timestamps). Explain how the system works (points, standing, appeal timeline).

3. **Minimize Cognitive Load** — Don't make users choose between 20 slots; recommend one. Don't make users hunt for the payment button; surface it on home. Don't hide features behind undiscoverable taps.

4. **Provide Immediate Feedback** — Actions should have visible results within 2 seconds. Tap to park → "Slot M3 reserved." Submit appeal → "Appeal received; status pending." Tap pay → redirect to checkout.

5. **Preserve User Control and Agency** — Users should always feel they can undo, change their mind, or get help. Violations should feel fair, not punitive. Appeals should feel like they will be heard, not ignored.

6. **Prioritize the Critical Path** — Home screen should answer the three questions that bring users back: "Can I park?" "Do I owe money?" "Do I have a violation?" Everything else is secondary.

7. **Design for Speed** — Users access the app in the car or at the gate. Pages should load in <2 seconds. Forms should be completable in <1 minute. Checkout should be completable in <30 seconds.

8. **Explain the Gamification** — Points, streak, and standing should be earned, visible, and meaningful. Users should understand what they're working toward.

---

## 12. CONFIRMED INFORMATION

✅ **Authentication & Access**
- Login via email/password or OAuth (Google, Microsoft)
- Role-based access: Students, Security Personnel, Admins
- RFID tag is issued after registration is approved
- Multi-vehicle registration per user

✅ **Parking Core**
- Parking facility has 20 slots (2 gates, 10 slots each: 2 car slots + 8 motorcycle slots per gate)
- Ultrasonic sensors detect occupancy in real-time
- RFID reader at gate logs entry/exit
- ALPR camera captures license plates

✅ **Payment**
- Fees are calculated automatically at exit (based on duration)
- Payment method: integrated gateway (or simulated for testing)
- Payment is required immediately but deadline is enforced via backend

✅ **Violations**
- Admin can issue violations with a penalty and category
- Violations appear on user dashboard and Violations tab
- User can appeal violations with text explanation (evidence field exists on backend but not exposed on mobile)

✅ **Gamification**
- Points: +10 per parking session, +50 per full week of streak
- Streak: consecutive days with parking + no violations
- Standing: Gold (0 violations), Silver (1 violation), Bronze (2+ violations)
- Standing affects RFID access (Bronze tier = temporary suspension possible)

✅ **Design System**
- Color palette: Indigo (brand), Sky (secondary), Mint (tertiary), Green (success), Amber (warning), Red (danger)
- Typography: Inter for body, Inter Display for headlines
- Shape: Flat, modern, minimal shadows
- No dark mode yet

---

## 13. ASSUMPTIONS

⚠️ **Assumption 1: Availability is Real-Time**
The app displays "15 slots free" but doesn't say when that was measured. Assumed that this number updates as users enter/exit, but not confirmed. DEPENDS ON: backend polling frequency, ultrasonic sensor latency.

⚠️ **Assumption 2: Smart Slot Allocation Will Go Into Production**
The build plan allocates 1.5 days for allocation v1. Assumed this will launch before or shortly after the mobile redesign. If delayed, the redesign should not assume recommendation endpoint exists.

⚠️ **Assumption 3: Notifications Will Be Wired In**
Phase 5 adds notification service to violations. Assumed this will ship. If delayed, violations will remain invisible to users.

⚠️ **Assumption 4: Appeals Will Accept Evidence**
The backend API accepts evidence attachments. Assumed the mobile UI will be updated to expose the field. If not, appeals will remain text-only.

⚠️ **Assumption 5: The Facility is Small (20 Slots)**
The design is optimized for a miniature / scale-model lot with 20 slots. Assumptions about density and walking distance do not apply to a real 1000-slot lot. If this scales, slot recommendation will need rethinking.

⚠️ **Assumption 6: Regulatory/Compliance is Out of Scope**
The product discovery does not cover legal obligations (data retention, payment PCI compliance, accessibility standards). Assumed these are handled separately.

---

## 14. UNKNOWNS

❓ **Unknown 1: What is the Actual Cost Structure?**
The app shows fees but the build plan mentions "flat rate for now" and "per-type parking rates pending professor's guidance." The actual fee model is undecided. NEED TO VALIDATE: Are motorcycle rates different from car rates?

❓ **Unknown 2: How Long is a Slot Reservation Valid?**
The build plan says "reserve for 10 minutes." Assumed this is the hold duration before a slot is released if the user doesn't enter. NEED TO VALIDATE: Is 10 minutes appropriate for the facility?

❓ **Unknown 3: What is the Appeal Review SLA?**
The discovery mentions "3–5 business days" as a guideline. Not confirmed. NEED TO VALIDATE: What is the actual timeline?

❓ **Unknown 4: Can Users Request Manual Refunds?**
The app has no refund flow. Assumed refunds are handled by admin. NEED TO VALIDATE: Should users be able to request refunds through the app?

❓ **Unknown 5: How Does Security Personnel Use This App?**
Security Personnel have a separate dashboard, but their mobile app is not in scope for this redesign. NEED TO VALIDATE: Should the user mobile app have a "I'm Security" toggle?

❓ **Unknown 6: What Happens if RFID Suspension Expires?**
The build plan mentions lazy reactivation. User doesn't know when they're unsuspended. NEED TO VALIDATE: Should the app notify the user when suspension is lifted?

❓ **Unknown 7: Are Incidents Reviewed Before Being Shared with Admins?**
The incident reporting feature exists. User files incident. Does admin see it immediately? NEED TO VALIDATE: Should incidents be moderated or auto-published?

---

## 15. QUESTIONS FOR VALIDATION

### Strategic Questions

**Q1. What is the primary goal of the mobile app redesign?**
- Is it to increase user engagement (more parking sessions)?
- Is it to reduce support burden (fewer payment disputes)?
- Is it to prepare for scale (handle 100+ concurrent users)?
- Is it to improve accessibility (serve users with low data connections)?

**Q2. Who is the primary user?**
- Campus students, institutional staff, or general public?
- Are they tech-savvy or do they need hand-holding?
- Do they expect a game-like experience (points, tiers) or just utility (park, pay, go)?

**Q3. What is the biggest pain point users face today?**
- Is it "I can't find a parking spot" or "I don't understand my fee" or "I can't appeal a violation"?
- Have you surveyed users or just read support tickets?

---

### Design Questions

**Q4. Should slot recommendation be automatic or optional?**
- Does the user always get a "best" slot, or do they have the option to choose?

**Q5. How should the app handle "lot full"?**
- Should the user be able to join a queue?
- Should they see nearby alternative lots?
- Should they just see "Try again later"?

**Q6. How much gamification is desired?**
- Should points/streak/standing be prominent or hidden?
- Do users actually care about these, or are they just noise?

**Q7. Should the app include navigation/wayfinding?**
- "Slot M3 is in the north section, upstairs, second row"?
- Is this in scope or should it be a future phase?

---

### Business Questions

**Q8. What is the monetization model?**
- Is the app free-to-use?
- Are there premium features (faster checkout, priority slots)?
- Is the revenue from parking fees or some other model?

**Q9. What is the SLA for appeal review?**
- 1 day? 5 days? 30 days?
- Should the app show the user a countdown?

**Q10. How many concurrent users should the app support?**
- 50 students? 500? 5000?
- Does this affect the design (e.g., notification load)?

---

### Technical Questions

**Q11. What data is already available on the backend?**
- Occupancy history (can we show trends)?
- User location (can we show distance from slots)?
- Payment history (can we show spending trends)?

**Q12. What integrations are already in place?**
- Which payment provider is live?
- Which push notification service?
- Which analytics platform?

**Q13. What is the deployment timeline?**
- Is this a redesign of the existing app or a rewrite?
- Do we need to support both old and new versions in parallel?

---

## SUMMARY & NEXT STEPS

### What We Know

AimPark is a **smart parking management system** that solves a real problem: helping drivers find parking, pay automatically, and maintain accountability through a modern mobile app. The system is technically sophisticated (IoT sensors, RFID, ALPR, real-time dashboard, gamification) but the UX has friction points that prevent users from trusting and enjoying the app.

The three biggest issues are:

1. **System state is invisible** — Users don't know if availability is live, whether violations reached them, whether appeals are being reviewed.
2. **Cognitive load is high** — Users must choose between 20 slots. Payment info is scattered. Appeals are hard to find.
3. **Key features are under-implemented** — Smart slot allocation doesn't exist. Violations don't send notifications. Appeals don't accept evidence.

### What We Need to Do Next

This discovery phase is **complete**. The next phase should:

1. **Validate assumptions** — Ask the product owner the 15 questions above. Confirm fee structure, appeal SLA, target user, and strategic goal.

2. **Research UX patterns** — Look at similar apps (parking, payments, appeals) to understand how comparable products handle slot recommendation, violation appeals, and good-standing tiers.

3. **Define success metrics** — What would good design look like? Faster checkout time? Lower support tickets? Higher appeal success rate?

4. **Design high-fidelity mockups** — Only after questions are answered and patterns are researched should the actual UI be designed.

### What This Discovery Enables

A designer can now answer:

- **"Who are we designing for?"** → Parkers who need fast, trustworthy parking and payment
- **"What do they need?"** → Real-time availability, quick slot recommendation, clear fee explanation, easy appeals
- **"What frustrates them?"** → Stale data, invisible state, unclear affordances, low agency
- **"What psychological principles matter?"** → Certainty, transparency, feedback, agency, speed
- **"What should we prioritize?"** → Live availability, smart slot recommendation, notification of violations, discoverable appeals

---

**This document is a discovery artifact, not a design specification.**

The next phase will separately research UX patterns, products, visual inspiration, interaction patterns, animation, and design directions.

**Do not begin design without validating the questions in section 15.**
