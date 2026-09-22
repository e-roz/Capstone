# AimPark Mobile App — Design Handoff Context

This document provides a UI/UX designer with everything needed to redesign the AimPark mobile application accurately. Focus on the screens, user flows, and constraints described here rather than implementation details.

---

## 1. Mobile App Overview

**AimPark** is a parking management app enabling users to register vehicles, check parking availability, track parking history, manage violations and payments, and report incidents. The app serves three roles: **User** (the primary role), **Admin**, and **Security Officer**. Only User functionality is implemented on mobile; Admin and Security Officer are web-only.

**Key User Responsibilities:**
- Register vehicle(s) via document capture (receipt)
- Access live parking slot availability
- Track entry/exit history and costs
- View and appeal parking violations
- Manage payments for parking fees and violation penalties
- Report incidents (vandalism, theft, accidents, etc.)
- Monitor account standing (Gold/Silver/Bronze tier based on violation history)
- Track a consecutive-day "parking streak" (gamification)

---

## 2. Technology & Framework

- **Framework:** Flutter (cross-platform for iOS/Android)
- **Language:** Dart
- **State Management:** Riverpod with async/await patterns
- **Routing:** Go Router (declarative navigation)
- **Backend Communication:** Dio HTTP client
- **Authentication:** JWT tokens (stored securely locally)
- **Document Recognition:** Google ML Kit (on-device OCR for registration)
- **Camera:** Full-resolution image capture for documents
- **Push Notifications:** Firebase Cloud Messaging
- **Payments:** External checkout (GCash) via URL launch in browser
- **Local Storage:** Flutter Secure Storage (tokens), SharedPreferences (user data)
- **Design System:** Token-based theming (light/dark mode, semantic color tokens)

---

## 3. Screen Inventory

### **Authentication Flows**

| Screen | Purpose | Key Elements | User Actions |
|--------|---------|--------------|---------------|
| **Splash** | App startup & session check | AimPark logo, loading state | Auto-route based on auth state |
| **Welcome** | Entry point to auth flow | Brand logo, intro text, sign-in/sign-up buttons | Choose login or registration |
| **Login** | Email + password sign-in | Email field, password field, Google sign-in button, forgot password link | Sign in, reset password, or switch to registration |
| **Forgot Password** | Initiate password reset | Email field | Request password reset code |
| **Reset Password** | Complete password reset | Email (passed invisibly), new password fields | Set new password |
| **Register Email** | Registration step 1 | Email field, OTP option | Enter email, receive OTP |
| **Register OTP** | Verify email via code | OTP input (6 digits), resend button | Submit OTP |
| **Register Profile** | Collect name, affiliation, password | First name, last name, affiliation dropdown, password fields, terms checkbox | Complete profile details |
| **Register Documents** | Capture 3 documents per vehicle | Camera prompt for receipt, plate photo; ML Kit OCR results review; confirmation | Review OCR-extracted data, confirm or retake photos |
| **Account Status** | Display approval/rejection status | Status message, rejection reason (if applicable), reapply date | View only; no actions |
| **Security Placeholder** | Security officer message | Static message | View only |
| **Admin on Web** | Admin role message | Redirect to web panel text | View only |

### **Main User Dashboard (Tab 1: Home)**

| Screen | Purpose | Key Elements | User Actions |
|--------|---------|--------------|---------------|
| **User Dashboard** | Primary entry point, overview of key metrics | Hero card (current parking status or availability), payment-due card (if owed), "week at a glance" (standing meter + streak + points), quick actions grid (6 tiles), recent activity list | Navigate to parking, history, alerts, vehicles, violations, payments, incidents; pull-to-refresh |

### **Parking & History (Tab 2: History)**

| Screen | Purpose | Key Elements | User Actions |
|--------|---------|--------------|---------------|
| **Parking History** | List of all entry/exit logs | Chronological list of parking sessions (entry time, slot, duration, status badge), tap to view associated fee | Pull-to-refresh; tap session to view payment details |
| **Parking Slots** | Live slot availability & search | Availability card (X of Y available), "Find me a slot" button, recommendation card (if applicable), gate-grouped grid of slot tiles, legend | Check availability, request AI recommendation for best slot, pull-to-refresh |

### **Alerts & Notifications (Tab 3: Alerts)**

| Screen | Purpose | Key Elements | User Actions |
|--------|---------|--------------|---------------|
| **Notifications** | Unread and read alerts | Section header with unread count badge, tinted notification tiles (type-specific coloring), message + timestamp | Tap unread alert to mark as read; pull-to-refresh |

### **Profile & Account (Tab 4: Profile)**

| Screen | Purpose | Key Elements | User Actions |
|--------|---------|--------------|---------------|
| **Account Screen** | Central hub for account & activity | Profile card (avatar, name, email, role badge), access status card (RFID card status), quick links (edit profile, change password, vehicles, violations, payments, incidents), appearance toggle, logout button | Navigate to sub-screens; toggle light/dark mode; logout |
| **Edit Profile** | Modify name, email, etc. | Name field, email field, save button | Update account details |
| **Change Password** | Update password | Current password, new password, confirm password fields | Change password |

### **Vehicles**

| Screen | Purpose | Key Elements | User Actions |
|--------|---------|--------------|---------------|
| **Vehicles List** | All registered vehicles | List of vehicle cards (plate number, color, type badge, registration validity), add vehicle button | Tap to view detail (if detail screen exists); add a vehicle |
| **Add Vehicle** | Register a new vehicle | Camera prompts (receipt, plate photo), OCR review, confirmation, success dialog | Photograph documents, review extracted data, confirm registration |

### **Violations**

| Screen | Purpose | Key Elements | User Actions |
|--------|---------|--------------|---------------|
| **Violations List** | All violations, separated by open/settled | Section for open violations (issued, appealed), section for settled (dismissed, overturned, paid), each with status badge and amount | Tap violation to view details; pull-to-refresh |
| **Violation Detail** | Full violation record & appeal action | Violation rule title, amount, date issued, status (issued/appealed/upheld/dismissed/overturned), penalty details, appeal button (if open) | File appeal; pull-to-refresh |

### **Payments**

| Screen | Purpose | Key Elements | User Actions |
|--------|---------|--------------|---------------|
| **Payments List** | All parking fees and violation penalties | Chronological list of payments (source: slot or violation, amount, status badge: unpaid/processing/paid, due date if applicable) | Tap payment to view details; pull-to-refresh |
| **Payment Detail** | Single payment record & checkout | Payment source, amount, fee/penalty breakdown, status, due date, checkout button (if unpaid) | Initiate payment (external GCash checkout in browser); pull-to-refresh |

### **Incidents**

| Screen | Purpose | Key Elements | User Actions |
|--------|---------|-----------|
| **Incidents List** | All reported incidents | List of incident cards (category, description, date, status), new report button | Tap to view detail; create new report |
| **Report Incident** | File a new incident | Category picker (6 options: vandalism, theft, accident, blocked slot, suspicious activity, other), description field (4 lines), location field (optional), photo evidence slots (up to 3 photos), submit button | Select category, describe incident, optionally add location and photos, submit |
| **Incident Detail** | Full incident record | Category, description, location, attached photos (if any), timestamp, status, withdraw button (if reporter) | Withdraw incident (if user filed it); view only otherwise |

---

## 4. Navigation Map

```
Splash
  ├─→ [No token or invalid] → Login
  └─→ [Valid token] → Home (role-based)

Login Screen
  ├─→ Welcome (entry point)
  │    ├─→ Sign In (form)
  │    │    ├─→ Forgot Password
  │    │    │    └─→ Reset Password
  │    │    └─→ [Success] → Home/User
  │    └─→ Registration Flow
  │         ├─→ Email Step
  │         ├─→ OTP Step
  │         ├─→ Profile Step
  │         ├─→ Documents Step (0, 1, 2)
  │         └─→ [Success] → Home/User

Home (User Shell - 4 Tabs)
  │
  ├─ Tab 1: Home Dashboard
  │   ├─→ Parking Slots
  │   ├─→ Violations
  │   ├─→ Payments
  │   ├─→ Vehicles
  │   └─→ Incidents (new)
  │
  ├─ Tab 2: Parking History
  │   └─→ Payment Detail (from history)
  │
  ├─ Tab 3: Alerts/Notifications
  │   └─→ [No detail screen; tapping marks as read]
  │
  └─ Tab 4: Profile
      ├─→ Edit Profile
      ├─→ Change Password
      ├─→ Vehicles
      │   └─→ Add Vehicle
      ├─→ Violations
      │   └─→ Violation Detail
      │       └─→ [Appeal action]
      ├─→ Payments
      │   └─→ Payment Detail
      │       └─→ [Checkout]
      ├─→ Incidents
      │   ├─→ Incident Detail
      │   └─→ Report Incident
      └─→ [Logout]
```

---

## 5. Feature Inventory

### **Dashboard & Overview**
- **Parking Status Card:** Shows if user is currently parked (slot code, entry time, duration) or availability count
- **Payment Due Card:** Displays total outstanding balance with most recent unpaid fee details (only shown if balance > 0)
- **Week at a Glance:** Three stats—Standing meter (Gold/Silver/Bronze tier), Streak (consecutive days parked violation-free), Points (10 per session, 50 per week streak)
- **Quick Actions Grid:** 6 shortcuts—Find Slot, History, Vehicles, Violations, Payments, Report
- **Recent Activity:** Last 3 parking sessions with session duration and link to associated fee
`   
### **Parking & Availability**
- **Live Slot Availability:** Displays X of Y slots free, grouped by gate
- **AI-Recommended Slot:** Button to request server recommendation; shows recommended slot and reasoning
- **Slot Grid Visualization:** 4-column grid per gate showing each slot's status (available/occupied/reserved)

### **Violation Management**
- **Status Tracking:** Issued, Appealed, Upheld, Dismissed, Overturned, Settled
- **Appeal Filing:** Users can appeal open violations; appeal status shown separately
- **Payment Linkage:** Violations with unpaid penalties show amount and due date

### **Payment Processing**
- **Payment Types:** Parking fees (from sessions), violation penalties
- **Status Tracking:** Unpaid, Processing, Paid, Waived, Overdue
- **External Checkout:** Unpaid payments link to external GCash payment page in system browser
- **Overdue Indicator:** Red text for past-due payments

### **Vehicle Management**
- **Multi-Vehicle Support:** One RFID card covers all registered vehicles; gate matches on plate
- **Document-Based Registration:** Users photograph receipt and plate; server OCR extracts plate and validates registration
- **Registration Validity:** Displays expiration date; badge shows "Expired" if past-due

### **Incident Reporting**
- **Categories:** 6 preset categories (Vandalism, Theft, Accident, Blocked Slot, Suspicious Activity, Other)
- **Photo Evidence:** Up to 3 photos per report
- **Withdrawal:** User can withdraw their own incident report

### **Notifications & Alerts**
- **Type-Specific Styling:** Different colors per notification type (violation, payment, account, parking availability, system, etc.)
- **Unread Indicator:** Tinted background + small dot; tap to mark read
- **Unread Badge:** Shown on Alerts tab and home screen header

### **Gamification**
- **Points:** +10 per parking session, +50 per full week of streak
- **Standing Tier:** Gold (0 violations), Silver (1 violation), Bronze (2+ violations)
- **Streak:** Consecutive calendar days with at least one parking log and no violations issued

### **Account Management**
- **RFID Card Status:** Shows whether registered card is active
- **Theme Toggle:** Light/dark mode picker

---

## 6. Major User Flows

### **New User Registration**
1. Tap Sign Up on Welcome screen
2. Enter email → receive OTP
3. Submit OTP to verify email
4. Enter name, affiliation (Student/Employee/Faculty), password
5. Accept terms
6. Photograph vehicle registration receipt (full page) and plate (metal)
7. Review ML Kit OCR-extracted plate number
8. Confirm plate number (or retake photos)
9. Account pending approval; can check status via Account Status screen
10. Upon approval, receive email and can sign in

### **Daily Parking Usage**
1. Open app, see home dashboard
2. Check current parking status or parking availability
3. Find a slot (manual search or AI recommendation)
4. [Outside app: car enters gate via RFID card or QR]
5. History tab shows new entry log
6. [When car exits: outside app]
7. History tab shows exit log and associated fee
8. Payment Due card appears if fee is unpaid
9. Tap Payment Due card or Payments tab to pay (external browser checkout)

### **Violation Appeal**
1. Receive push notification of new violation
2. Tap notification → Alerts tab or tap Violations in Profile
3. Open violation detail
4. Tap Appeal button
5. [Optional form fields for appeal reason]
6. Status changes to "Appealed"
7. Receive notification when appeal is reviewed (upheld or dismissed)
8. If dismissed, standing meter improves

### **Incident Reporting**
1. Tap Report action on home or Profile → Incidents
2. Select incident category (radio/chip group)
3. Describe what happened (4-line textarea)
4. Optionally add location landmark/slot code
5. Optionally photograph evidence (up to 3 photos)
6. Tap Submit
7. Success dialog shown
8. Can later withdraw report from Incidents list

---

## 7. Important UI Components

### **Reusable Patterns**

| Component | Purpose | Variants |
|-----------|---------|----------|
| **AppCard** | Bordered card container | Default (bordered), solid color, gradient (hero cards only) |
| **AppListRow** | List item with icon, title, subtitle, optional badge/trailing | Dense option; intent colorization (success/warning/danger/info) |
| **AppButton** | Primary action button | Standard, full-width, loading state, disabled state |
| **AppStatusBadge** | Inline status indicator | Intent-colored (success/warning/danger/info/brand), compact |
| **AppEmptyState** | Placeholder when no data | Icon, title, message; intent colorization |
| **AsyncView** | Data loading/error wrapper | Loading skeleton, error state with retry, data, empty state |
| **AppScreen** | Page wrapper | Title, back button, body, bottom bar, pull-to-refresh |
| **AppSectionHeader** | Section label | Title, optional action badge/button |
| **AppAvatar** | User profile circle | Generated from name (color + initials) |
| **AppBottomNav** | Tab bar | 4 items (Home, History, Alerts, Profile), badging for Alerts |
| **AppChipGroup** | Multi-option selector | Single-select or multi-select, tappable chips |
| **AppTextField** | Text input | Label, helper text, error message, maxLines |

### **Hero Components (Home Only)**

These are intentionally distinct from app-wide patterns:

- **Parking Hero Card:** Full-bleed gradient (indigo-to-mint), 28px border radius, tag pill, mascot illustration, circular arrow CTA
- **Payment Due Card:** Full-bleed gradient (amber-to-coral), similar layout, warns of balance owed
- **Week at a Glance:** Standing card (with illustrated shield + progress ring) + 2 ring-stat cards (streak + points)

### **Design Tokens**

The app uses a **semantic token system** rather than hard-coded colors:

- **Brand Color:** Indigo (primary actions, active nav, key UI elements)
- **Accent Color:** Sky blue (secondary actions, informational)
- **Tertiary Color:** Mint (onboarding, celebratory actions)
- **Status Colors:** Success (green), Warning (amber), Danger (red), Info (blue)
- **Surface Layers:** Canvas (background), Card, Muted, Overlay, Scrim
- **Text Hierarchy:** Primary, Secondary, Tertiary, OnDark, OnDarkMuted
- **Light & Dark Modes:** All tokens animate smoothly when theme switches

### **Typography**

- **Display:** Large hero numbers (point totals, availability count)
- **Headline:** Screen titles, card headlines
- **Title:** Subsection heads
- **Body:** Form labels, descriptions, body text
- **Label:** Badges, tags, buttons, captions
- **Typeface:** Inter (text), InterDisplay (headlines only)

### **Spacing & Sizing**

- **Gutter:** 16px (standard screen padding)
- **Control Gap:** 12px (space between form controls)
- **Icon Sizes:** Sm (16px), Md (24px), Lg (32px)
- **Border Radius:** 12px (cards), 20-28px (buttons/chips), infinite (avatars)

---

## 8. Mobile-Relevant Data & API Dependencies

### **User Data Model**
- **Profile:** Full name, email, role (User/Admin/Security), affiliation (Student/Employee/Faculty)
- **Access Status:** RFID card active/inactive
- **Password:** Can be changed but not reset via app during registration

### **Vehicles**
- **Per Vehicle:** Plate number, color, vehicle type (Car/Motorcycle), registration expiration date
- **Linked to:** User account (one RFID card, multiple plates)
- **Proof:** OCR-extracted plate from receipt photo

### **Parking History**
- **Per Entry:** Entry time, slot code, exit time (if parked out), linked payment ID
- **Client-Derived:** Duration, streak count, points total
- **Real-Time:** Current parking status (currently parked or not)

### **Violations**
- **Per Violation:** Policy rule title, penalty amount, created date, status (Issued/Appealed/Upheld/Dismissed/Overturned)
- **Settlement:** Marked settled when paid
- **Client Logic:** Standing tier (Gold/Silver/Bronze) derived from unsettled violation count

### **Payments**
- **Per Payment:** Amount due, status (Unpaid/Processing/Paid/Waived), source (ParkingFee/ViolationPenalty), slot code, due date
- **External Checkout:** GCash integration via external browser URL
- **Client-Derived:** Overdue flag, remaining balance sum

### **Notifications**
- **Types:** PolicyUpdate, ParkingAvailability, Violation, Payment, Account, Incident, System
- **Status:** Read/unread, type-specific coloring
- **Delivery:** Firebase Cloud Messaging (push); also queryable via API

### **Incidents**
- **Per Incident:** Category (Vandalism/Theft/Accident/BlockedSlot/SuspiciousActivity/Other), description, location, up to 3 photo URLs, status
- **User Actions:** Can withdraw own incident

### **Critical Endpoints**
All endpoints require JWT authentication (except auth flows):

| Action | Endpoint | Method | Notes |
|--------|----------|--------|-------|
| Register email | `/api/auth/register/initiate-email` | POST | Initiates registration, no response tells if email exists |
| Verify OTP | `/api/auth/register/verify-email` | POST | Returns registration-only JWT |
| Complete profile | `/api/auth/register/complete-profile` | POST | Updates account, advances registration step |
| Scan documents | `/api/auth/register/documents/scan` | POST | Sends photos, returns OCR results |
| Confirm documents | `/api/auth/register/documents/confirm` | POST | Commits OCR data, creates vehicle, advances step |
| Login | `/api/auth/login` | POST | Email + password; returns session JWT |
| Logout | `/api/auth/logout` | POST | Clears server-side session |
| Parking history | `/api/parking/history` | GET | Paginated list of logs |
| Parking slots | `/api/parking/slots` | GET | Real-time availability per slot & gate |
| Parking recommend | `/api/parking/recommend` | GET | AI-recommended slot |
| Violations | `/api/violations` | GET | List of user's violations |
| Violation appeal | `/api/violations/:id/appeal` | POST | File appeal for specific violation |
| Payments | `/api/payments` | GET | List of user's payments |
| Payment checkout | `/api/payments/:id/checkout` | POST | Returns GCash URL for external checkout |
| Notifications | `/api/notifications` | GET | Paginated list |
| Mark notification read | `/api/notifications/:id/read` | POST | Mark single notification as read |
| Incidents | `/api/incidents` | GET | List of user's incidents |
| Create incident | `/api/incidents` | POST | File new report |
| Withdraw incident | `/api/incidents/:id/withdraw` | POST | User can withdraw own report |

---

## 9. Current UX Observations

### **Information Hierarchy Issues**

**FACT:** The home dashboard now contains:
- Hero card (parking status or slot availability)
- Payment due card (if owed)
- Week at a glance (standing, streak, points)
- Quick actions (6 shortcuts)
- Recent activity (3 entries)

**OBSERVATION:** Previously, key features (vehicles, violations, payments) were hidden inside the Profile tab with no indication they existed on the main screen. This made the dashboard appear featureless. The redesign added quick-action tiles to surface them, but the visual hierarchy still skews toward the hero card. A designer may want to evaluate whether all 6 quick-action tiles deserve equal visual weight or if some could be promoted/demoted.

### **Payment Visibility**

**FACT:** Payment due amounts appear:
1. On home dashboard (if balance > 0)
2. On Payment Due card (showing most recent unpaid fee detail)
3. On Profile (showing total due in badge)
4. On Payments list screen

**OBSERVATION:** Users open the app specifically to know "do I owe money" and "how much." The Payment Due card was added as a hero card to answer this immediately. However, the card's amber-coral gradient may not stand out enough in dark mode, and the "from your session at B-14" detail text is small. A designer should verify the payment card is prominent enough.

### **Violation Concealment**

**FACT:** A user who misses a push notification about a new violation only sees it:
1. When they tap Violations from home quick-actions or profile
2. Never on the dashboard itself

**OBSERVATION:** The dashboard now lists open violations under "Needs your attention" (replacing the old behavior where they were completely invisible). This is better, but a designer should verify the section is noticeable—it's below the hero cards and only appears when there are open violations.

### **Streak & Points Mechanics**

**FACT:** Streak and points are computed client-side from parking history:
- Streak = consecutive calendar days with ≥1 parking log and no violations issued
- Points = 10 per session + 50 per full week of streak
- Standing = based on unsettled violations (Gold/Silver/Bronze)

**OBSERVATION:** Users do not have a clear mental model of how to *increase* points or protect their streak. The week-at-a-glance card shows these metrics, but the UI does not explain the formulas. A designer should consider adding tooltips or a help page explaining the mechanics.

### **Dark Mode Token Animation**

**FACT:** The app smoothly animates theme colors when switching between light and dark mode; all colors are defined via tokens.

**OBSERVATION:** This is technically sound, but the designer should verify that all new screen designs respect the token system and avoid hard-coding colors (e.g., no `Color(0xFF1C7A99)` in designs).

### **Mobile-Specific Layout**

**FACT:** Screens use responsive layouts (wrap, LayoutBuilder, etc.) to adapt to phone widths; the Parking Slots screen uses a 4-column grid that scales appropriately.

**OBSERVATION:** Designers should test mockups on both portrait (narrow ~390dp) and landscape orientations if the app will support it. Currently, landscape is not a stated requirement, but the responsive patterns suggest it may be intended.

### **Hero Card Limitation**

**FACT:** Hero cards (parking, payment due, week at a glance) are scoped *only* to the home dashboard; every other screen uses flat, bordered cards.

**OBSERVATION:** This intentional constraint keeps the visual language consistent. A designer should not introduce gradient cards or special treatment elsewhere, to avoid visual confusion. The home dashboard is meant to feel distinct—a landing page, not a typical list screen.

---

## 10. Redesign Constraints

### **Must Maintain**

1. **Navigation Structure:** Bottom nav with 4 tabs (Home, History, Alerts, Profile) is core. Redesigns should not move to drawer or side nav without strong justification.

2. **Registration Flow:** Email → OTP → Profile → Documents (3-step photo capture with OCR review) is proven. Do not redesign unless the backend flow changes.

3. **Role-Based Routing:** The app routes based on JWT role; Admin and Security Officer users are sent to web-only screens. Mobile redesigns must not expose incomplete paths for those roles.

4. **Push Notification Delivery:** Firebase Cloud Messaging is wired; notifications appear in Alerts tab. Do not remove or significantly alter this flow.

5. **External Payment Checkout:** Payments open an external browser (GCash) by design—the payer must see the real address bar. Do not move to in-app WebView.

6. **Quick-Action Grid (6 Tiles):** Home dashboard has become more discoverable by adding these tiles. Removing them would hide key features again.

7. **Payment Due Card:** Users specifically want to see "do I owe money" at a glance. Keep it prominent or replace it with something equally visible.

8. **Open Violations Banner:** Users must see open violations on the dashboard so they do not miss an appeal deadline. "Needs your attention" section is minimal; ensure visibility in redesign.

9. **Profile Avatar:** Generated from user's name (initials + color). Do not require photo upload; the name-based avatar is a constraint of the account model.

10. **Token-Based Theming:** All colors must be defined via semantic tokens. Hard-coded hex colors in new designs will not work; coordinate with developers.

### **Do Not Redesign (Out of Scope)**

- Backend API shapes or endpoints
- Authentication token format or flow
- OCR or document recognition logic
- Payment provider integration (GCash)
- Firebase Push Notification infrastructure
- User database schema

### **Acceptable Scope (Designer Can Redesign)**

- Visual hierarchy and layout
- Typography and type scales
- Color usage within token constraints
- Component shapes (border radius, shadows)
- Spacing and padding
- Icon choices (Material Icons are available)
- Animation and transitions (smooth theme switching is required; other motion is optional)
- Empty, loading, and error state UI
- Badge, badge, notification appearance
- Form input styling and validation feedback
- Dialog and sheet appearance
- Card and list-item layouts

---

## 11. Open Questions / Unclear Behavior

### **Needs Clarification**

1. **Incident Withdrawal Timing:** Can users withdraw an incident report immediately, or only before review? The UI allows it anytime, but the business rule is unclear.

2. **Violation Appeal Reasons:** The appeal endpoint exists, but it's unclear if users submit free-text reasons or select from preset categories. Current implementation may just file an empty appeal.

3. **Payment Refund Path:** When an appeal succeeds and a violation is dismissed, the associated paid fine has no refund endpoint. Is this intentional (user keeps it) or a known gap?

4. **Slot Recommendation Algorithm:** The "Find me a slot" feature calls `/api/parking/recommend`. What factors does the server consider? Distance to entrance? Gate preference? This affects how users perceive the recommendation.

5. **Notification Unread Count Reset:** Does marking a notification read automatically decrement the Alerts badge? The code suggests yes, but it should be verified.

6. **Offline Mode:** The app assumes constant connectivity. Is offline-first caching needed, or is the assumption that users are online when checking parking?

7. **Multi-Device Sessions:** If a user signs in on a second device, does the first device's session stay active? Token refresh logic should be clarified.

8. **Affiliation Relevance:** The registration form captures affiliation (Student/Employee/Faculty) but it's unclear how the backend uses it. Does it affect parking rules, pricing, or is it just a categorization field?

---

## 12. Summary for Designer

You are redesigning a **mobile parking management app** serving parking lot users. The current design uses:

- **Bottom navigation** (4 tabs, non-negotiable)
- **Hero cards on home screen only** (parking status, payment due, week at a glance)
- **Flat, bordered cards everywhere else**
- **Semantic color tokens** (brand indigo, accent blue, tertiary mint, + status colors)
- **Responsive layouts** (test on phone widths ~360–420dp)
- **Material Icons** (available in Flutter)

**Key user needs:**
1. **At-a-glance parking status** — most important
2. **Outstanding balance visibility** — must be obvious
3. **Violation alerts** — users must not miss them
4. **Payment shortcuts** — reduce taps to pay
5. **Incident reporting** — quick and low-friction

**Key constraints:**
- Do not move navigation from bottom tabs
- Keep external payment checkout (users need real address bar)
- Maintain token-based color system
- Keep registration flow (users expect document capture)
- Preserve quick-action grid visibility

Your redesign succeeds if it makes these needs *more* obvious and reduces the number of taps to access them. Focus on information hierarchy, whitespace, and type scale to guide the eye to what matters most.

---

**Document Last Updated:** 2026-09-20  
**Mobile App Version Analyzed:** 1.0.0+1 (as of commit 07e3973)
