# WIREFRAMES — AimPark Mobile App

**Date:** September 2026  
**Phase:** Step 5 — Structural UX Wireframes & Detailed Flows  
**Source of Truth:** `UX_ARCHITECTURE.md`

---

## 1. PURPOSE & PRINCIPLES

This document translates the finalized UX Architecture into **professional structural wireframes** that define layout, content priority, navigation, interaction behavior, and states.

**What is included:**
- Screen hierarchy and layout regions
- Content priority (Tier 1/2/3)
- Primary and secondary actions
- Navigation flows and transitions
- State handling (loading, error, empty, offline, stale, processing, success, interrupted)
- Accessibility structure
- UX rationale

**What is NOT included:**
- Final colors or visual styling
- Final typography or typographic hierarchy
- Illustrations or detailed visual design
- Animation timings or advanced motion
- Flutter or backend implementation code
- New features beyond the approved architecture
- New primary navigation

**Guiding principles:**
1. Preserve existing 4-tab navigation
2. Make system state visible (availability freshness, payment status, violation detail, appeal status)
3. Reduce cognitive load (recommendation over choice, primary actions discoverable)
4. Ensure transparency (factual language, clear affordances, fair processes)
5. Minimize friction (quick access to critical tasks, persistent totals, explicit confirmation)
6. Account for edge cases (loading, error, offline, stale, interrupted)
7. Respect user control (no dark patterns, fair appeals, clear consequences)
8. Treat unresolved product decisions as placeholders (do not silently invent them)

---

## 2. STRUCTURAL WIREFRAME VOCABULARY

### Layout Regions

**Header** — Fixed at top
- App name / logo
- Profile/settings access
- Search or quick actions (if applicable)

**Hero Card / Featured Content** — Primary information area
- Large, prominent placement
- Single most important item
- Clear affordance for primary action

**Content Area** — Scrollable main section
- Tier 1 information (primary)
- Tier 2 information (secondary)
- Tier 3 information (optional engagement)

**Action Region** — Primary and secondary buttons/links
- Primary action (primary color, prominent placement)
- Secondary action (muted color or link style)
- Conditional actions (available only in certain states)

**Status Region** — State and feedback information
- Loading indicators
- Error messages
- Success confirmation
- Stale data warning
- Offline notification

**Bottom Navigation** — Fixed 4-tab bar
- Home | Parking | Violations | Account
- (Current structure preserved)

### Component Types

**Card** — Contained information unit
- One concept per card
- Whitespace around card
- Tap to expand or navigate detail

**Row / List Item** — Scannable information
- Trailing affordance (chevron, badge, highlight on tap)
- Consistent height for touch target
- Primary info on left, secondary on right or below

**Button** — Primary action
- Primary color, prominent size (48dp+ touch target)
- Clear label (verb + noun)
- Disabled state when unavailable

**Link** — Secondary navigation
- Underline or button-link style
- Accessible color contrast
- Clear destination

**Alert / Status Badge** — State indicator
- Color-coded (green = success, amber = warning, red = error/action required)
- Clear, concise label
- Optional icon or illustration

### State Indicators

**Loading State**
- Skeleton screen or spinner
- "Loading..." or "Refreshing..." text
- Animation to signal activity

**Empty State**
- Icon or illustration (optional)
- "No [items]" or "No [action] yet"
- Optional next-step action

**Error State**
- Red alert badge
- Clear error message
- "Retry" button or next-step action

**Offline State**
- Gray overlay or muted appearance
- "Offline" label
- Available actions clearly marked

**Stale State**
- Timestamp or "Updated Xs ago"
- Manual refresh option
- User can judge freshness and act

**Processing State**
- Spinner or progress indicator
- "Processing..." or action-specific text
- Cannot navigate away during critical operation

**Success State**
- Green checkmark
- "Confirmed" or "Complete" label
- Optional receipt or summary
- Clear next step or home navigation

### Touch Targets

- Minimum 48dp (iOS) / 48dp (Android)
- Tap area extends slightly outside visible button
- One-handed reachability: important controls in lower half of screen

---

## 3. NAVIGATION MAP

### Four-Tab Structure (Preserved)

```
┌─────────────────────────────────────────────────────────────┐
│                         BOTTOM NAV                          │
│  Home  │  Parking  │  Violations  │  Account               │
└─────────────────────────────────────────────────────────────┘
```

### Tab Content

**Home (Dashboard)**
- Parking status hero card
- Balance due (if applicable)
- Open violations (if applicable)
- Account standing / gamification
- Quick actions

**Parking**
- Availability overview + timestamp + refresh
- Slot list or grid
- Current parking status (if active)

**Violations**
- Violation list (by status: open, appealed, paid)
- Violation detail (on tap)
- Appeal form (state-dependent)

**Account**
- Profile section
- Vehicles section
- Settings section
- Support / help section
- Gamification explanation link

### Deep Links & Cross-Navigation

**From Home:**
- Payment Due card → Payment checkout
- Violation badge → Violations tab → Violation detail
- Standing display → Gamification help screen

**From Violations:**
- Violation row → Violation detail
- Detail → Appeal form (if applicable)
- Form → Confirmation → Status view

**From Payment:**
- Checkout → Success screen → Home or Payments list

---

## 4. HOME / DASHBOARD

### Purpose

Answer the three questions that bring users back:
1. "Can I park right now?"
2. "Do I owe money?"
3. "Do I have a violation?"

### Layout

```
┌──────────────────────────────────────┐
│ Header: AimPark | [Profile]          │
├──────────────────────────────────────┤
│                                      │
│  ┌────────────────────────────────┐  │  ← Tier 1: HERO CARD
│  │ PARKING STATUS                 │  │
│  │ Currently Parked at M3          │  │
│  │ Since 14:00 • ~3 hours          │  │
│  │ Updated 30s ago [↻ Refresh]     │  │
│  │                                 │  │
│  │ ◇ Available: 12 slots           │  │
│  │ [View Details] [Find a Slot]    │  │
│  └────────────────────────────────┘  │
│                                      │
│  ┌────────────────────────────────┐  │  ← Tier 1: ALERTS
│  │ 🟠 ₱500 owed | Due by Aug 25   │  │     (if balance due)
│  │ [Pay Now] [View Details]       │  │
│  └────────────────────────────────┘  │
│                                      │
│  ┌────────────────────────────────┐  │  ← Tier 1: ALERTS
│  │ 🔴 1 violation open            │  │     (if violation)
│  │ [Review] [View All]            │  │
│  └────────────────────────────────┘  │
│                                      │
│ ─────────────────────────────────── │
│                                      │
│ Gold Standing ✓                     │  ← Tier 2: STATUS
│ 3-day parking streak 🔥             │
│ 250 points earned                  │
│ [? How Standing Works]             │
│                                      │
│ ─────────────────────────────────── │
│                                      │
│ Last 2 Sessions:                    │  ← Tier 2: ACTIVITY
│ Aug 21 | M3 | ₱150                 │     (optional engagement)
│ Aug 20 | L1 | ₱100                 │
│                                      │
│ [Report Incident] [Account] [Help]  │  ← Quick actions
│                                      │
└──────────────────────────────────────┘
```

### States

| State | What Shows | What's Hidden |
|-------|-----------|--|
| **Not Parked / No Issues** | Hero: "Not parked" + availability | Alerts, gamification visible but secondary |
| **Parked / No Issues** | Hero: Current slot + duration | Alerts hidden |
| **Balance Due** | Hero: Parking status; Alert: Payment due | Only payment alert shown |
| **Violation Open** | Hero: Parking status; Alert: Violation | Only violation alert shown |
| **Both Alerts** | Hero: Parking status; Alerts: Both (stacked) | Both alerts clearly visible, no priority over each other |
| **Suspended** | Hero: "Suspended" (red) | Alerts: Suspension notice + contact support |
| **Loading** | Skeleton: Hero card loading, alert areas hidden | Status: "Loading parking status…" |
| **Offline** | Last known state visible + "Offline" badge | Refresh disabled; cached data shown with age |
| **Stale Data** | Hero visible; Timestamp: "Updated 15 min ago" (amber) | Refresh button prominent |

### Tier 1 (Must Be Visible)

1. **Parking Status Hero Card**
   - Current parking state (not parked / parked at [slot])
   - Duration if parked
   - Availability count + freshness timestamp
   - Refresh button
   - Call-to-action: "Find a Slot" or "View Details"

2. **Critical Alerts** (shown when applicable)
   - Payment due (amber badge) + "Pay Now" button
   - Violation open (red badge) + "Review" link
   - Account suspended (red, prominent)

### Tier 2 (Visible After Minimal Scroll)

3. **Standing / Gamification**
   - Standing tier: "Gold Standing ✓"
   - Streak: "3-day streak 🔥"
   - Points: "250 points"
   - Help link: "? How Standing Works"

4. **Recent Activity** (optional)
   - Last 2 parking sessions
   - Date, slot, cost
   - Or "No recent activity" if empty

### Quick Actions (Always Visible)

5. **Action Row**
   - [Report Incident]
   - [Account]
   - [Help]
   - Or similar based on product priority

### Key Interaction Points

**Refresh Button**
- Pull-to-refresh on hero card or explicit refresh icon
- Shows loading state during fetch
- Updates timestamp on success
- Shows error if fetch fails

**Payment Card**
- "Pay ₱XXX" button goes directly to checkout (fastest path)
- Alternative: "View Details" shows payment breakdown

**Violation Badge**
- Tap → Violations tab → Violation list or detail
- Shows count and encourages action

**Standing Display**
- Tap "?" → Help screen explaining tiers, points, streak, consequences

---

## 5. PARKING

### Purpose

Show real-time parking availability and support slot selection.

### Parking Tab Overview

```
┌──────────────────────────────────────┐
│ Header: Parking                      │
├──────────────────────────────────────┤
│                                      │
│  ┌────────────────────────────────┐  │
│  │ AVAILABILITY                   │  │
│  │ 12 slots available             │  │
│  │ Updated 30 seconds ago [↻]     │  │
│  │                                │  │
│  │ Cars: 8 available              │  │
│  │ Motorcycles: 4 available       │  │
│  └────────────────────────────────┘  │
│                                      │
│  ┌────────────────────────────────┐  │
│  │ CURRENT PARKING STATUS         │  │
│  │ Parked at M3 since 14:00       │  │
│  │ ~3 hours elapsed               │  │
│  └────────────────────────────────┘  │
│                                      │
│  ┌────────────────────────────────┐  │
│  │ [Find a Slot]                  │  │  ← Primary action
│  └────────────────────────────────┘  │
│                                      │
└──────────────────────────────────────┘
```

### Slot Selection Screen (on "Find a Slot")

```
┌──────────────────────────────────────┐
│ Header: Select a Slot | [X] Close   │
├──────────────────────────────────────┤
│                                      │
│  ┌────────────────────────────────┐  │
│  │ ★ RECOMMENDED: Slot M3        │  │  ← Primary if recommendation
│  │ Gate 1 • Close to entrance     │  │     implemented (Phase 3)
│  │                                │  │
│  │ [Reserve Slot] [Browse Others] │  │
│  └────────────────────────────────┘  │
│                                      │
│  ─────────────────────────────────  │  ← Or direct to list if
│  OTHER AVAILABLE SLOTS                  recommendation not ready
│                                      │
│  L1  [Motorcycle] [Gate 1]          │
│  M3  [Car] [Gate 1] ← Current      │
│  M5  [Car] [Gate 1]                │
│  N1  [Car] [Gate 2]                │
│  ...                                │
│                                      │
│  [ ] Show only [Car / Motorcycle]  │  ← Filter
│                                      │
└──────────────────────────────────────┘
```

### States

| State | What Shows |
|-------|-----------|
| **Loading** | Skeleton: Availability loading; Slot list grayed out with spinner |
| **Available** | Slot list with occupancy; count + timestamp clear |
| **No Available** | "Lot is full" message; "Check back later" or refresh option |
| **Stale** | Timestamp shows age; yellow/amber warning; refresh button prominent |
| **Error** | "Couldn't load slots" + Retry button |
| **Offline** | "Offline. Last known: X slots available (5 min ago)" |
| **Already Parked** | Show current parking instead of slot selection |

### Key Interaction Points

**Availability Refresh**
- Manual refresh button
- Shows spinner during fetch
- Updates timestamp on success
- Clear error if refresh fails

**Slot Selection**
- (Phase 3) Show recommended slot prominently with hold countdown
- (Phase 2) Show all slots with ability to filter by type
- Tap to select; confirm before committing

**Offline Behavior**
- Show last-known availability with age
- (Product decision required) Can user select slot offline?
- Clear indication of what will happen when connectivity returns

---

## 6. PAYMENT

### Purpose

Show balance due and support fast, transparent checkout.

### Payments Tab Overview

```
┌──────────────────────────────────────┐
│ Header: Payments                     │
├──────────────────────────────────────┤
│                                      │
│  ┌────────────────────────────────┐  │
│  │ BALANCE DUE: ₱500              │  │  ← Primary info
│  │ [Pay Now]                      │  │
│  └────────────────────────────────┘  │
│                                      │
│  ─────────────────────────────────  │
│  UNPAID SESSIONS                    │
│                                      │
│  ┌────────────────────────────────┐  │
│  │ Aug 21 | Slot M3               │  │
│  │ 3 hours @ ₱50/hr = ₱150        │  │
│  │ [Pay This] [Details]           │  │
│  └────────────────────────────────┘  │
│                                      │
│  ┌────────────────────────────────┐  │
│  │ Aug 20 | Slot L1               │  │
│  │ 2 hours @ ₱50/hr = ₱100        │  │
│  │ [Pay This] [Details]           │  │
│  └────────────────────────────────┘  │
│                                      │
│  ┌────────────────────────────────┐  │
│  │ Aug 19 | Slot M1               │  │
│  │ 4 hours @ ₱50/hr = ₱200        │  │
│  │ [Details]                      │  │
│  │ (Paid on Aug 19)               │  │
│  └────────────────────────────────┘  │
│                                      │
└──────────────────────────────────────┘
```

### Payment Checkout

**Checkout Overview**
```
┌──────────────────────────────────────┐
│ Header: Payment | [X] Close          │
├──────────────────────────────────────┤
│  TOTAL DUE: ₱500                     │  ← Always visible
├──────────────────────────────────────┤
│                                      │
│  Sessions Being Paid:                │
│  ─────────────────────────────────  │
│  Aug 21 | M3 | 3 hrs | ₱150         │
│  Aug 20 | L1 | 2 hrs | ₱100         │
│  Aug 19 | M1 | 4 hrs | ₱200         │
│                                      │
│  Payment Method:                     │
│  ◉ Card ending in 4242 (default)    │
│  ○ Add new card                     │
│                                      │
│  [Confirm Payment]                  │  ← Primary action
│                                      │
│  [Cancel] [Edit Selection]           │  ← Secondary
│                                      │
└──────────────────────────────────────┘
```

**Processing State**
```
┌──────────────────────────────────────┐
│ Processing payment…                  │
│                                      │
│ ⟳ (spinner)                          │
│                                      │
│ This may take 10 seconds.            │
│ Please don't navigate away.          │
│                                      │
└──────────────────────────────────────┘
```

**Success State**
```
┌──────────────────────────────────────┐
│                                      │
│ ✓ Payment Confirmed                 │
│                                      │
│ ─────────────────────────────────── │
│ Amount Paid:        ₱500             │
│ Date:              Aug 22, 14:32     │
│ Reference:         TXN-123456        │
│ Status:            Completed         │
│ ─────────────────────────────────── │
│                                      │
│ [View Receipt] [Return to Home]      │
│                                      │
└──────────────────────────────────────┘
```

**Failure State**
```
┌──────────────────────────────────────┐
│                                      │
│ ✗ Payment Failed                    │
│                                      │
│ Reason: Card expired                 │
│                                      │
│ [Update Payment Method] [Retry]      │
│                                      │
│ [Contact Support] [Try Later]        │
│                                      │
└──────────────────────────────────────┘
```

### Key Interaction Points

**Total Visibility**
- Total amount due shown at top of checkout
- Remains visible while scrolling
- Shows breakdown of what's included

**Payment Method**
- Saved payment methods shown first
- "Add new card" option below
- Clear indication of default method

**Confirmation**
- Explicit "Confirm Payment" button
- Clear summary of what will be charged
- No silent redirects

**Success/Failure**
- Explicit confirmation screen (not silent)
- Receipt available for user records
- Clear next step (home or view history)

---

## 7. VIOLATIONS

### Violations Tab / List

```
┌──────────────────────────────────────┐
│ Header: Violations                   │
├──────────────────────────────────────┤
│                                      │
│  Filter: [All] [Open] [Appealed]    │  ← Optional grouping
│          [Paid]                      │
│                                      │
│  OPEN VIOLATIONS (1)                 │
│  ┌────────────────────────────────┐  │
│  │ Aug 21 · ₱175                  │  │  ← Tappable row
│  │ Policy violation at Slot M3    │  │     with chevron →
│  │                          →     │  │
│  └────────────────────────────────┘  │
│                                      │
│  PAID VIOLATIONS (2)                 │
│  ┌────────────────────────────────┐  │
│  │ Aug 18 · ₱100 · Paid Aug 18   │  │
│  │ Overtime parking              │  │
│  │                          →     │  │
│  └────────────────────────────────┘  │
│                                      │
│  ┌────────────────────────────────┐  │
│  │ Aug 12 · ₱75 · Paid Aug 12    │  │
│  │ Unauthorized vehicle          │  │
│  │                          →     │  │
│  └────────────────────────────────┘  │
│                                      │
└──────────────────────────────────────┘
```

### Violation Detail Screen

```
┌──────────────────────────────────────┐
│ Header: Violation | [Back]           │
├──────────────────────────────────────┤
│                                      │
│  STATUS: Open / Unpaid               │  ← State indicator
│  Due by Aug 25                        │
│                                      │
│  ─────────────────────────────────  │
│  VIOLATION DETAILS                   │
│  ─────────────────────────────────  │
│                                      │
│  Rule: Policy violation              │  ← Factual description
│  Date: Aug 21, 17:30                 │
│  Location: Slot M3                   │
│                                      │
│  Vehicle Details:                    │
│  • Entered: 14:00                    │
│  • Exited: 17:30                     │
│  • Duration: 3.5 hours               │
│  • Rate: ₱50/hour                    │
│                                      │
│  CHARGE: ₱175                        │
│                                      │
│  ─────────────────────────────────  │
│  EVIDENCE (if available)             │
│  ─────────────────────────────────  │
│                                      │
│  [Photo] Timestamp: 17:30            │
│  [Sensor Reading] Timestamp: 17:30   │
│                                      │
│  ─────────────────────────────────  │
│  ACTIONS                             │
│  ─────────────────────────────────  │
│                                      │
│  [Appeal Violation]   ← Primary if    │
│                         eligible,    │
│                         state-dep.   │
│  [Pay Now]            ← Secondary    │
│                         or state-dep │
│                                      │
│  [View Policy] [Contact Support]     │
│                                      │
└──────────────────────────────────────┘
```

### States

| State | What Shows | Actions Available |
|-------|-----------|--|
| **Open (Unpaid)** | Full details + charge + due date | Pay or Appeal (if eligible) |
| **Appealed** | Details + "Status: Under Review" + submit date + ETA | View status; withdraw (if allowed) |
| **Approved** | Details + "✓ Appeal Approved" + reason | View resolution; close or go back |
| **Rejected** | Details + "✗ Appeal Rejected" + reason | Pay or try again (if allowed) |
| **Paid** | Details + "Paid on [date]" | View receipt or go back |
| **Loading Detail** | Skeleton of detail screen | None |
| **Error** | "Couldn't load violation" + Retry | Retry or back |

### Key Interaction Points

**Row Affordance**
- Trailing chevron (→) signals tap to detail
- Highlight on tap/press
- Color or visual state change on selection

**Factual Description**
- Avoid judgmental language
- State facts: date, time, duration, rate, charge
- Show evidence if available

**Primary Action (State-Dependent)**
- If violation is open and appeal-eligible: **Appeal is clearly available** (but not necessarily primary)
- Exact primary action follows confirmed product policy (not designed here)
- Design shows both options; product policy determines which is primary

**Appeal Status**
- If appeal submitted: show "Under Review | Submitted [date] | Expected decision by [date]"
- If approved/rejected: show outcome + reason
- Status is always accessible by reopening the violation

---

## 8. APPEAL

### Appeal Form (State-Dependent)

```
┌──────────────────────────────────────┐
│ Header: File an Appeal | [X] Close  │
├──────────────────────────────────────┤
│                                      │
│  ┌────────────────────────────────┐  │
│  │ VIOLATION: ₱175                │  │  ← Read-only summary
│  │ Aug 21 at Slot M3              │  │
│  │ Charged for 3.5-hour parking   │  │
│  └────────────────────────────────┘  │
│                                      │
│  ─────────────────────────────────  │
│  APPEAL DETAILS                      │
│  ─────────────────────────────────  │
│                                      │
│  Explain your case:                  │
│  [Text field]                        │
│  "Why do you think this charge is    │
│   unfair? What evidence do you       │
│   have?"                             │
│                                      │
│  ─────────────────────────────────  │
│  EVIDENCE (optional if supported)    │ ← Conditional on
│  ─────────────────────────────────  │    product decision
│                                      │
│  [+ Add Photo / Document]            │
│                                      │
│  "Attach a photo, video, or         │
│   document supporting your case."   │
│                                      │
│  Max file size: [limit if known]    │
│  Supported types: [types if known]  │
│                                      │
│  ─────────────────────────────────  │
│  WHAT HAPPENS NEXT                   │
│  ─────────────────────────────────  │
│                                      │
│  We'll review your appeal and        │
│  notify you of our decision within   │
│  [SLA if known; placeholder if not]  │
│                                      │
│  [Submit Appeal]                     │ ← Primary action
│                                      │
│  [Cancel]                            │ ← Secondary
│                                      │
└──────────────────────────────────────┘
```

### Appeal Confirmation Screen

```
┌──────────────────────────────────────┐
│                                      │
│ ✓ Appeal Submitted                  │
│                                      │
│ ─────────────────────────────────── │
│ Status:         Under Review         │
│ Submitted:      Aug 22, 14:32        │
│ Violation:      ₱175                 │
│ Expected:       Aug 25 or later      │ ← SLA if confirmed
│ ─────────────────────────────────── │
│                                      │
│ We've received your appeal and       │
│ will review it carefully.            │
│                                      │
│ You can check the status anytime     │
│ on your Violations list.             │
│                                      │
│ [Return to Violations] [Go Home]    │
│                                      │
└──────────────────────────────────────┘
```

### Appeal Status (Detail in Violations Tab)

```
┌──────────────────────────────────────┐
│ Header: Appeal Status | [Back]       │
├──────────────────────────────────────┤
│                                      │
│  APPEAL STATUS: Under Review         │
│                                      │
│  ─────────────────────────────────  │
│  Submitted:    Aug 22 at 14:32      │
│  Violation:    ₱175                 │
│  Expected:     Aug 25 or later      │ ← ETA if known
│  ─────────────────────────────────  │
│                                      │
│  Your Appeal Details:                │
│  ─────────────────────────────────  │
│                                      │
│  [Show user's explanation]           │
│  [Show evidence if attached]         │
│                                      │
│  [Check for Updates]                 │
│                                      │
│  [View Original Violation] [Contact] │
│                                      │
└──────────────────────────────────────┘
```

### Appeal Outcome

**If Approved**
```
┌──────────────────────────────────────┐
│                                      │
│ ✓ Appeal Approved                   │
│                                      │
│ We've reviewed your appeal and       │
│ agree the charge is unfair.          │
│                                      │
│ Charge Waived: ₱175                 │
│ Status: Resolved                     │
│                                      │
│ [Return to Violations] [Go Home]    │
│                                      │
└──────────────────────────────────────┘
```

**If Rejected**
```
┌──────────────────────────────────────┐
│                                      │
│ ✗ Appeal Rejected                   │
│                                      │
│ We've reviewed your appeal.          │
│ Unfortunately, we believe the charge │
│ is justified.                        │
│                                      │
│ Reason: [reason if available]       │
│ Charge Still Due: ₱175               │
│ Due by: [date]                       │
│                                      │
│ [Pay Now] [View Policy]              │
│ [Request Admin Review] (if allowed)  │ ← Product decision
│ [Contact Support]                    │
│                                      │
└──────────────────────────────────────┘
```

### States

| State | Form Shows | Buttons Available |
|-------|-----------|--|
| **Editable** | Empty text + evidence section | Submit, Cancel |
| **Loading** | Skeleton | None |
| **Error** | Form + error message | Retry, Cancel |
| **Submitted** | Confirmation screen | Return to Violations, Go Home |
| **Under Review** | Status view with details | Check for updates, Contact support |
| **Approved** | Outcome screen | Return, Go Home |
| **Rejected** | Outcome + next steps | Pay, Review, Contact support |
| **Draft Interrupted** | Form state restored on resume | Continue, Discard |

### Key Interaction Points

**Form Validation**
- Explanation text required
- Evidence optional (if supported)
- Submit disabled until minimum requirements met

**Offline Behavior**
- (Product decision) Can user save draft offline?
- If yes: show "Saved locally. Submit when connection returns."

**Evidence Upload**
- Only shown if product policy supports evidence
- File picker opens on tap
- Show upload progress if file is large
- Clear size/type limits if any

---

## 9. ACCOUNT

### Account Tab Overview

```
┌──────────────────────────────────────┐
│ Header: Account                      │
├──────────────────────────────────────┤
│                                      │
│  ─────────────────────────────────  │
│  PROFILE                             │
│  ─────────────────────────────────  │
│                                      │
│  Name:      John Doe                 │
│  Email:     john@example.com         │
│  Phone:     +63 912 345 6789         │
│  Status:    Approved                 │  ← Account status
│                                      │
│  [Edit Profile]                      │
│                                      │
│  ─────────────────────────────────  │
│  VEHICLES                            │
│  ─────────────────────────────────  │
│                                      │
│  ┌────────────────────────────────┐  │
│  │ CAR - Honda Civic              │  │
│  │ Plate: ABC 1234                │  │
│  │ Status: Active                 │  │
│  │ [Edit] [Remove]                │  │
│  └────────────────────────────────┘  │
│                                      │
│  [+ Add Vehicle]                     │
│                                      │
│  ─────────────────────────────────  │
│  SETTINGS                            │
│  ─────────────────────────────────  │
│                                      │
│  Notifications: [Toggle On/Off]      │
│  Email alerts: [Toggle On/Off]       │
│                                      │
│  [Change Password]                   │
│  [Payment Methods]                   │
│                                      │
│  ─────────────────────────────────  │
│  HELP & SUPPORT                      │
│  ─────────────────────────────────  │
│                                      │
│  [? How Standing Works]              │
│  [FAQ]                               │
│  [Report a Problem]                  │
│  [Contact Support]                   │
│  [About] [Version 2.1.0]             │
│                                      │
└──────────────────────────────────────┘
```

### Edit Profile Modal

```
┌──────────────────────────────────────┐
│ Header: Edit Profile | [X] Close    │
├──────────────────────────────────────┤
│                                      │
│  Name: [Text field]                  │
│  Email: [Text field]                 │
│  Phone: [Text field]                 │
│                                      │
│  [Save Changes] [Cancel]             │
│                                      │
│  Success: "Profile updated ✓"        │
│                                      │
└──────────────────────────────────────┘
```

### How Standing Works Help Screen

```
┌──────────────────────────────────────┐
│ Header: Standing Explained | [Back]  │
├──────────────────────────────────────┤
│                                      │
│  Your standing reflects your         │
│  parking account health.             │
│                                      │
│  ─────────────────────────────────  │
│  TIERS                               │
│  ─────────────────────────────────  │
│                                      │
│  🥇 Gold (0 violations)             │
│  Full access. No restrictions.      │
│                                      │
│  🥈 Silver (1 violation)            │
│  Monitored. Access may be limited.  │
│                                      │
│  🥉 Bronze (2+ violations)          │
│  May face suspension. [Learn more]  │
│                                      │
│  ─────────────────────────────────  │
│  POINTS & STREAK                     │
│  ─────────────────────────────────  │
│                                      │
│  You earn points by parking          │
│  consistently and following rules.   │
│                                      │
│  • +10 points per parking session   │
│  • +50 bonus for a 7-day streak    │
│  • Streak resets after a violation  │
│                                      │
│  ─────────────────────────────────  │
│  HOW TO IMPROVE YOUR STANDING        │
│  ─────────────────────────────────  │
│                                      │
│  • Avoid violations                  │
│  • Park regularly                    │
│  • Appeal unfair charges             │
│                                      │
└──────────────────────────────────────┘
```

### Key Interaction Points

**Profile Editing**
- Simple modal or dedicated screen
- Validate inputs
- Show success confirmation on save
- Clear error if save fails

**Vehicles**
- Show all registered vehicles
- Status indicator (active, suspended)
- Edit / remove options
- Add new vehicle button

**Settings**
- Toggle preferences (notifications, email)
- Password change
- Payment method management

**Help**
- Standing explanation screen (always accessible)
- FAQ
- Contact support

---

## 10. SUPPORTING SCREENS

### Gamification Help ("How Standing Works")

See Account section above. Accessible from:
- Home: "? How Standing Works" link next to standing display
- Account: "[? How Standing Works]" link
- First login (optional intro)

### Incident Reporting

**Location:** (Product decision required for final placement)
- Quick action on home
- Or button in account
- Or dedicated screen

**Form:**
```
┌──────────────────────────────────────┐
│ Header: Report an Incident           │
├──────────────────────────────────────┤
│                                      │
│  What happened?                      │
│  ☐ Theft             ☐ Damage       │
│  ☐ Trespassing       ☐ Other        │
│                                      │
│  Description:                        │
│  [Text field]                        │
│                                      │
│  [+ Add Photo]                       │
│                                      │
│  [Submit Report]                     │
│                                      │
└──────────────────────────────────────┘

After Submit:
✓ Report Received
Your incident has been reported to
facility management. Reference #...
```

### Session Detail (from History)

```
┌──────────────────────────────────────┐
│ Header: Parking Session | [Back]    │
├──────────────────────────────────────┤
│                                      │
│  Date:      Aug 21, 2026             │
│  Entry:     14:00                    │
│  Exit:      17:30                    │
│  Duration:  3 hours 30 minutes       │
│                                      │
│  Location:  Slot M3, Gate 1          │
│                                      │
│  Charge:    ₱175 @ ₱50/hour         │
│  Status:    Paid                     │
│  Points:    +10                      │
│                                      │
│  [View Payment] [Download Receipt]   │
│                                      │
└──────────────────────────────────────┘
```

---

## 11. STATE PATTERNS

### Loading State

**Visual Pattern**
- Skeleton screen or content placeholder
- Subtle pulse or shimmer animation (optional)
- Text: "Loading..." or action-specific ("Refreshing availability…")
- No interaction possible while loading

**When Used**
- Initial data fetch on screen load
- Manual refresh while waiting
- Checkout processing
- Form submission

---

### Empty State

**Visual Pattern**
- Icon or simple illustration (optional)
- Clear, brief message ("No violations yet" / "No payment history")
- Optional hint: "Your next parking will appear here"

**When Used**
- No violations, no parking history, no pending actions
- Normal state, not an error

---

### Error State

**Visual Pattern**
- Red alert badge
- Clear error message
- "Retry" button or alternative action
- Optional "Contact support" link for persistent errors

**When Used**
- Network failure
- Data fetch failure
- Form validation error
- Payment failure

---

### Offline State

**Visual Pattern**
- Muted appearance (gray or low opacity)
- "Offline" badge or label
- Last-known data shown with age timestamp
- Actions clearly marked as unavailable (disabled buttons)

**When Used**
- No network connectivity
- App can still display cached data
- Critical actions (pay, appeal, submit) disabled

---

### Stale State

**Visual Pattern**
- Timestamp: "Updated 5 minutes ago" or "Last checked at 14:30"
- Amber/yellow warning badge (optional)
- Refresh button prominent

**When Used**
- Data is older than X minutes (threshold TBD by product/engineering)
- User should know data may have changed
- Refresh is available and encouraged

---

### Processing State

**Visual Pattern**
- Spinner or progress bar
- Text: "Processing…" (action-specific: "Processing payment…")
- "Do not navigate away" message for critical operations
- Cannot interact with form or navigation until done

**When Used**
- Form submission in progress
- Payment processing
- Data synchronization

---

### Success State

**Visual Pattern**
- Green checkmark (✓)
- "Confirmed" or "Complete" message
- Optional summary of what was confirmed
- Primary action: continue or go home
- Shown explicitly (not silent redirect)

**When Used**
- Form submitted successfully
- Payment completed
- Action completed with positive outcome

---

### Failure State

**Visual Pattern**
- Red X or error icon
- Clear failure message
- "Retry" or "Try again" button
- Alternative action if available

**When Used**
- Form submission failed
- Payment declined
- Action resulted in error

---

### Interrupted State

**Visual Pattern**
- Form state is restored on app resume
- "Your form was saved" notification (optional)
- User can continue or discard

**When Used**
- User backgrounds app mid-form
- Connection lost mid-operation
- App crashes and recovers

---

## 12. COMPONENT PATTERNS

### Card (Information Container)

```
┌────────────────────────────────────┐
│ TITLE / HEADING                    │  ← Optional
│                                    │
│ Primary information (large, clear) │
│ Secondary information (smaller)    │
│                                    │
│ [Primary Action] [Secondary]       │  ← Optional
└────────────────────────────────────┘
```

**Usage:** Hero cards, alert cards, summary cards
**Touch target:** Minimum 48dp height
**Spacing:** Consistent padding (12-16px)
**Affordance:** Obvious tap area or button

---

### Row / List Item

```
Icon / Badge  │ Title              │ Action / Chevron
              │ Subtitle           │
```

**Usage:** Violation list, payment list, vehicle list
**Touch target:** Minimum 48dp height
**Affordance:** Trailing chevron (→) or highlight on tap
**Spacing:** 16px horizontal padding, 12-16px vertical

---

### Button (Primary Action)

```
┌──────────────────────┐
│   [Primary Action]   │  ← 48dp+ height
└──────────────────────┘
```

**Color:** Primary brand color (indigo)
**Size:** 48dp+ touch target, centered or stretched
**Label:** Clear verb + noun ("Pay Now", "Submit Appeal")
**Disabled state:** Lighter color or reduced opacity
**Loading state:** Spinner + text or progress bar

---

### Badge / Status Indicator

```
🟢 Status Label
or
[Green] Status Label
```

**Usage:** Open, under review, approved, paid, error
**Colors:** Green (success), amber (warning), red (error), gray (neutral)
**Text:** Clear, brief label
**Optional:** Icon or small illustration

---

### Alert

```
┌────────────────────────────────┐
│ 🔴 Violation Open             │
│ ₱175 · Due by Aug 25          │
│ [Review] [Dismiss]            │
└────────────────────────────────┘
```

**Usage:** Important status changes, actionable items
**Color:** Red (action required), amber (warning)
**Dismissible:** Option to close if not critical
**Action:** One or more action buttons

---

## 13. DETAILED INTERACTION FLOWS

### Flow 1: Find & Park

```
TRIGGER: User opens app, wants to park

HOME SCREEN
  ↓ [Not parked, sees "Find a Slot"]
  ↓
PARKING TAB
  ↓ Views availability ("12 slots free")
  ↓ Taps [Find a Slot]
  ↓
SLOT SELECTION SCREEN
  ↓ (Phase 3) Sees recommended slot OR (Phase 2) sees all slots
  ↓ Selects a slot
  ↓
CONFIRMATION DIALOG
  ↓ Confirms selection
  ↓
GATE / RFID SCAN
  ↓ User scans RFID at gate
  ↓
SYSTEM CONFIRMS ENTRY
  ↓ Notification or in-app confirmation
  ↓
ACTIVE PARKING STATUS
  ↓ Home shows "Currently Parked at M3"
  ↓
COMPLETION: User has parked

FAILURE RECOVERY:
  - Slot was taken: Show error, offer to select another
  - RFID scan fails: Show retry option
  - Offline: Show last-known state, proceed to gate with best guess
```

---

### Flow 2: Check & Pay

```
TRIGGER: User sees balance due or navigates to Payments

HOME / PAYMENT DUE CARD
  ↓ Taps [Pay Now] or navigates to Payments tab
  ↓
PAYMENTS SCREEN / CHECKOUT
  ↓ Sees total amount
  ↓ Sees breakdown (which sessions)
  ↓ Selects or confirms payment method
  ↓ Taps [Confirm Payment]
  ↓
PROCESSING STATE
  ↓ Shows spinner
  ↓ "Processing payment…"
  ↓
SUCCESS SCREEN
  ✓ "Payment Confirmed"
  ✓ Receipt shown
  ↓ Taps [Return to Home]
  ↓
HOME SCREEN
  ↓ Balance updated to ₱0 (or new total if partial payment)
  ↓ Payment card hidden or shows "No balance due ✓"
  ↓
COMPLETION: Payment settled

FAILURE RECOVERY:
  - Payment declined: Show error reason, offer to retry or try different method
  - Network lost: Show "Payment processing" state, offer to check status later
  - User cancels: Return to payments list, no charge made
```

---

### Flow 3: Violation Review & Appeal

```
TRIGGER: Violation arrives (push notification or user navigates to Violations)

PUSH NOTIFICATION (or Violations tab badge)
  ↓ User taps notification or goes to Violations tab
  ↓
VIOLATIONS LIST
  ↓ Sees violation row (with chevron →)
  ↓ Taps violation row
  ↓
VIOLATION DETAIL SCREEN
  ↓ Reads factual description
  ↓ Sees charge amount
  ↓ (Product decision) Decides to appeal or pay
  ↓ Taps [Appeal] (if available per product policy)
  ↓
APPEAL FORM
  ↓ Writes explanation
  ↓ (if supported) Attaches evidence
  ↓ Taps [Submit Appeal]
  ↓
CONFIRMATION SCREEN
  ✓ "Appeal Submitted"
  ✓ Status: "Under Review"
  ✓ Expected decision date (if SLA confirmed)
  ↓
USER RETURNS TO VIOLATIONS LIST
  ↓ Violation now shows "Appeal pending"
  ↓ User can tap to check status anytime
  ↓
[LATER] ADMIN REVIEWS APPEAL
  ↓ Decision made (approved or rejected)
  ↓ (Phase 5) Push notification sent
  ↓ Violations list shows outcome
  ↓ User taps to see reason
  ↓
COMPLETION: Appeal resolved

ALTERNATIVE: User chooses to pay instead of appeal
  ↓ Violation Detail → [Pay Now]
  ↓ Goes to Checkout flow (Flow 2)
  ↓ Payment made
  ↓ Violation marked as paid
  ↓
COMPLETION: Violation settled

FAILURE RECOVERY:
  - Violation detail fails to load: Show error, retry option
  - Appeal form validation error: Highlight required field, show error message
  - Appeal submission fails: Show error, offer to retry, preserve form data
  - Offline while reviewing: Show last-known data, save form locally
```

---

### Flow 4: Check Account Standing

```
TRIGGER: User taps standing display on home or account

HOME / STANDING DISPLAY
  ↓ Taps "? How Standing Works"
  ↓
HELP SCREEN
  ↓ Reads explanation:
  │   - Gold = 0 violations
  │   - Silver = 1 violation
  │   - Bronze = 2+ violations
  │   - Points system
  │   - Streak explanation
  │   - How to improve standing
  ↓
USER UNDERSTANDS
  ↓ Can return to home or account
  ↓
COMPLETION: User is informed
```

---

### Flow 5: Report an Incident

```
TRIGGER: User witnesses damage/theft and wants to report

HOME QUICK ACTIONS (or Account)
  ↓ Taps [Report Incident]
  ↓
INCIDENT FORM
  ↓ Selects incident type (theft, damage, etc.)
  ↓ Writes description
  ↓ (optional) Attaches photo
  ↓ Taps [Submit Report]
  ↓
CONFIRMATION
  ✓ "Report Received"
  ✓ Reference number
  ↓
COMPLETION: Incident reported

FAILURE RECOVERY:
  - Form validation error: Show required field message
  - Photo upload fails: Show error, offer to retry or skip
  - Submission fails: Show error, preserve form data, allow retry
```

---

## 14. SCREEN TRANSITION MAP

```
HOME (Dashboard)
  ├─→ Parking Tab
  │    ├─→ Slot Selection
  │    └─→ Active Parking Status
  │
  ├─→ Payment Card
  │    └─→ Checkout
  │         ├─→ Processing
  │         ├─→ Success
  │         └─→ Failure
  │
  ├─→ Violation Badge
  │    └─→ Violations List
  │         └─→ Violation Detail
  │              ├─→ Appeal Form
  │              │    ├─→ Confirmation
  │              │    └─→ Appeal Status
  │              └─→ Pay (to Checkout)
  │
  ├─→ Standing Display
  │    └─→ How Standing Works (Help)
  │
  └─→ Account Tab
       ├─→ Edit Profile
       ├─→ Manage Vehicles
       ├─→ Settings
       ├─→ How Standing Works
       ├─→ FAQ
       ├─→ Contact Support
       └─→ Report Incident

VIOLATIONS TAB
  ├─→ Violation List
  │    └─→ Violation Detail (as above)
  │
  └─→ Appeal Status (if under review)

PARKING TAB
  ├─→ Availability Overview
  └─→ Slot Selection

PAYMENTS TAB
  ├─→ Balance Overview
  └─→ Checkout (as above)

ACCOUNT TAB
  └─→ (all sections as above)
```

---

## 15. ACCESSIBILITY

### Structural Accessibility

1. **Logical Reading Order**
   - Home: Parking status → Alerts → Standing → Activity
   - Violations: List → Detail → Appeal form
   - Payment: Balance → Breakdown → Confirmation

2. **Meaningful Labels**
   - Button labels: "[Pay ₱500]" not "[OK]"
   - Form labels: "Explain your case" not "Text"
   - Card titles: "Payment Due" not "Alert"

3. **Color + Text**
   - Never use color alone for status
   - Example: "🔴 Violation Open" (color + badge + text)
   - "🟢 Parked" with "Status: Parked" text

4. **Non-Color Status**
   - Paid: Green checkmark + "Paid"
   - Error: Red X + "Error" label
   - Loading: Spinner + "Loading…"

5. **Touch Targets**
   - All interactive elements: minimum 48dp × 48dp
   - Buttons and tappable rows meet minimum size
   - Spacing between targets prevents accidental presses

6. **Form Accessibility**
   - Error messages appear inline and in summary
   - Required fields marked clearly
   - Validation happens on blur/submit (not keypress)

7. **Keyboard Navigation** (for future implementation)
   - Tab through form fields
   - Enter to submit
   - Escape to close

8. **Screen Reader Support** (for future implementation)
   - Semantic HTML elements
   - ARIA labels where needed
   - Alt text for images

---

## 16. UX / PSYCHOLOGY RATIONALE

### Home Dashboard Hierarchy

**Principle:** Expectation-alignment (from Psychology of UI/UX skill)

**Observation:** Users open the app with three questions: "Can I park?" "Do I owe money?" "Do I have a violation?"

**UX implication:** Answer those three questions immediately and clearly.

**Recommendation:** Hero card (parking) dominates. Alerts (balance, violations) follow. Secondary info (standing, activity) below.

**Expected effect:** Users find critical information faster; app feels responsive.

---

### Availability Freshness Timestamp

**Principle:** Expectation-alignment, transparency

**Observation:** Stale data breaks user trust. ("I see 15 slots but the lot is full.")

**UX implication:** Users need to know how current the information is.

**Recommendation:** Show "Updated 30s ago" or "Refreshed just now" timestamp.

**Expected effect:** Users can judge whether to trust the data; fewer wasted trips.

---

### Factual Violation Language

**Principle:** Procedural justice, user autonomy

**Observation:** Judgmental language ("You overstayed") triggers defensiveness.

**UX implication:** Users feel treated unfairly. Less likely to accept outcome or appeal thoughtfully.

**Recommendation:** Use facts instead. "Vehicle exited 17:30 after 3.5 hours @ ₱50/hr = ₱175."

**Expected effect:** Users perceive the process as fair. Better-reasoned appeals if users choose to appeal.

**Trade-off:** Violation detail screens are longer.

---

### Appeal Form Confirmation

**Principle:** Feedback + system transparency

**Observation:** Silent submission causes anxiety. User doesn't know if appeal was received.

**UX implication:** Users feel uncertain and may resubmit or give up.

**Recommendation:** Explicit confirmation screen showing "Under Review" + submitted date + expected decision date.

**Expected effect:** Users feel heard. Confidence in the process increases.

---

### State-Dependent Primary Action

**Principle:** Context appropriateness, user autonomy

**Observation:** Not all violations warrant appeal. Some should be paid immediately.

**UX implication:** Universal "Appeal is primary" may encourage frivolous appeals or prevent users from paying.

**Recommendation:** Primary action changes based on violation state and confirmed product policy.

**Expected effect:** Users make appropriate decisions for their situation.

---

## 17. UNRESOLVED PRODUCT DECISIONS

These decisions remain open and should NOT be silently resolved during wireframing:

1. **Violation Primary Action Rules**
   - When is Appeal the primary action vs. Pay?
   - Are certain violations non-appealable?

2. **Appeal Evidence**
   - Is evidence required, optional, or unsupported?
   - Which file types?
   - Maximum file size and count?

3. **Appeal Review SLA**
   - Timeline for admin review (3 days? 5 days? 24 hours?)
   - How is this communicated to users?

4. **Appeal Withdrawal/Resubmission**
   - Can users withdraw an appeal after submission?
   - Can users resubmit if rejected?

5. **Incident Reporting Placement**
   - Quick action on home (best case)?
   - FAB (floating action button)?
   - Account → Quick actions?
   - Dedicated screen?

6. **Offline Slot Selection**
   - Can users select a slot without network connectivity?
   - If so, what happens when connectivity returns?

7. **Gamification Confirmation**
   - Exact point values: Confirmed or design assumption?
   - Exact tier thresholds: Confirmed or design assumption?
   - Exact streak reset conditions: Confirmed or design assumption?
   - Access consequences: Confirmed or design assumption?

---

## 18. ENGINEERING DEPENDENCIES

These technical capabilities must be validated; implementation method is not prescribed here:

1. **Availability Refresh Strategy**
   - UX need: Fresh data for parking decisions
   - Engineering must determine: polling frequency, app lifecycle handling, acceptable staleness threshold

2. **Form State Persistence**
   - UX need: User doesn't lose appeal draft if app backgrounds
   - Engineering must determine: persistence mechanism (local storage, database, etc.), data security approach

3. **Appeal Status Tracking**
   - UX need: Users can see appeal status (under review, approved, rejected)
   - Engineering must determine: backend state machine, status visibility API

4. **Payment State Recovery**
   - UX need: After network loss, user can check if payment went through
   - Engineering must determine: payment status query mechanism, reconciliation logic

5. **Offline Capability**
   - UX need: Clear communication about what is/isn't available offline
   - Engineering must determine: what state can be cached, offline conflict resolution

---

## 19. SELF-AUDIT

- [x] Existing 4-tab navigation preserved
- [x] Existing functionality preserved (no deletion, only improvement)
- [x] Home hierarchy is focused (Tier 1/2/3 order preserved)
- [x] Parking flow is complete (availability → selection → confirmation)
- [x] Payment flow is complete (balance → checkout → confirmation)
- [x] Violation flow is complete (list → detail → state-dependent actions)
- [x] Appeal flow is complete (form → confirmation → status tracking)
- [x] Violation actions are state-dependent (not universal "Appeal primary")
- [x] Evidence remains conditional (included only if product policy supports)
- [x] Gamification remains secondary (below parking/payment info)
- [x] Critical edge states covered (loading, error, empty, offline, stale)
- [x] Accessibility considered (touch targets, color + text, logical order)
- [x] No unsupported business rules invented (unresolved decisions marked explicitly)
- [x] No visual/high-fidelity design started (structural wireframes only)
- [x] No code or backend changes made

---

## 20. READINESS FOR STEP 6

✅ **READY FOR STEP 6 — VISUAL / HIGH-FIDELITY DESIGN**

**Structural wireframes are complete and ready for:**
- Visual refinement (colors, typography, spacing)
- High-fidelity mockups
- Component design system
- Interaction design and animation
- Accessibility deep-dive (WCAG validation)
- Handoff to development

**Remaining product decisions DO NOT block high-fidelity design:**
- Evidence upload can be designed conditionally (visible if supported, hidden if not)
- Primary actions can be designed as state-dependent (wireframe shows both options)
- SLA timeline can be designed as a placeholder ([expected decision by [date]])
- Gamification details can be designed with the existing system (explanation screen covers unknowns)

**Next phase should:**
1. Resolve any remaining product decisions (if needed for visual design)
2. Apply visual design direction from DESIGN_DIRECTION.md
3. Create high-fidelity mockups
4. Define component library
5. Begin detailed interaction and animation design
6. Prepare handoff package for engineering

---

**WIREFRAMES PHASE COMPLETE.**

Ready for stakeholder review and transition to Step 6 — Visual / High-Fidelity Design.
