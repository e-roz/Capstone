# DESIGN DIRECTION — AimPark Mobile App

**Date:** September 2026  
**Phase:** Design Strategy & Direction (Pre-Implementation)  
**Status:** Strategy Only (Not Final Design)

---

## 1. DESIGN STRATEGY

**Central Question:** What should the redesigned AimPark experience fundamentally do better than the current experience?

**Strategy:** Make system state **visible**, tasks **discoverable**, and important information **accessible without friction**.

AimPark's core problem is not that features don't exist — it's that users cannot reliably find them, trust the information, or understand what to do next. The redesign prioritizes **clarity and trust** over feature expansion. We preserve the existing interface structure while improving information hierarchy, state visibility, and action discoverability.

---

## 2. STRATEGIC GOALS

### Goal 1: Make Parking Availability Trustworthy

**Problem:** Availability data appears stale. Users see "15 slots free" but don't know if the number is current. This creates uncertainty at the decision moment ("Should I drive in?").

**Design Response:** Show explicit data freshness signals (timestamp, refresh state) and enable refresh-on-app-resume so data updates automatically.

**Expected UX Benefit:** Users will trust the app's availability number and make faster, more confident decisions about whether to enter the lot.

**Trade-off:** Requires visible UI for loading/updating states; slightly more API load on backend.

**Confidence:** HIGH (based on real-time dashboard research; low UX risk)

---

### Goal 2: Make Important Actions Discoverable

**Problem:** Violation appeals are hidden (row taps are not obvious). Payments are scattered (home card, Payments tab, detail screens). Incident reporting is buried in a menu.

**Design Response:** Use consistent visual affordances for tappable rows (trailing chevron, highlight states), surface critical actions on home screen (Pay button, Appeal link), and standardize where secondary actions appear (profile tabs, quick action buttons).

**Expected UX Benefit:** Users will find appeals, payments, and reports without searching or guessing.

**Trade-off:** Home screen becomes slightly more crowded; requires careful visual hierarchy to prevent clutter.

**Confidence:** HIGH (based on affordance and discoverability research; standard UX practice)

---

### Goal 3: Make Financial Transparency the Default

**Problem:** Violations show a charge amount but no breakdown. Payments show a total but users must tap to see details. Appeal costs are unclear.

**Design Response:** Every payment, fee, and penalty should show: what it's for, when it happened, how it was calculated (duration × rate), and what happens next.

**Expected UX Benefit:** Users will understand charges and feel the process is fair, reducing disputes and appeals.

**Trade-off:** Longer text; requires careful layout to avoid information overload.

**Confidence:** HIGH (based on payment UX research; procedural justice psychology)

---

### Goal 4: Make Violations Feel Fair, Not Punitive

**Problem:** Violation language feels accusatory ("You overstayed"). Users get defensive and less likely to accept outcomes fairly.

**Design Response:** Reframe violation descriptions to state facts instead of judgments: "Vehicle exited at 17:30 after 3.5 hours" instead of "You overstayed." Make appeals prominently accessible (button, not menu option).

**Expected UX Benefit:** Users will feel treated fairly and be more likely to accept decisions or file reasoned appeals rather than disputing reflexively.

**Trade-off:** Requires backend wording change; longer text on violation cards.

**Confidence:** MEDIUM (based on psychology research; needs validation that factual language actually reduces disputes)

---

### Goal 5: Make System Status Always Visible

**Problem:** Users don't know if something is loading, pending, or complete. Silent operations create uncertainty ("Did my appeal submit?").

**Design Response:** Every consequential action (submit, pay, appeal) should show a visible result within 2 seconds. Loading states, confirmation screens, and status badges should indicate what's happening.

**Expected UX Benefit:** Users will feel in control and trust that the system has received their input.

**Trade-off:** Requires careful design to avoid status spam; animations must be restrained.

**Confidence:** HIGH (standard UX principle; based on feedback research)

---

### Goal 6: Make Gamification Supportive, Not Confusing

**Problem:** Points, streak, and standing tier are displayed but unexplained. Users don't know what standing tier means or why points matter.

**Design Response:** Add a one-page explanation of how the system works: "Gold standing (0 violations) = full access. Silver (1 violation) = access monitored. Bronze (2+ violations) = possible suspension." Make standing consequences visible.

**Expected UX Benefit:** Users will understand gamification and feel motivated to maintain standing, rather than viewing it as confusing noise.

**Trade-off:** Adds one help screen; requires explaining suspension rules clearly.

**Confidence:** MEDIUM (based on gamification research; effectiveness depends on users actually visiting help screen)

---

### Goal 7: Preserve Familiarity While Improving Priority

**Problem:** Core tasks (check parking status, check balance, handle violation) are buried or require navigation. Secondary tasks (edit profile) are equally visible.

**Design Response:** Keep existing 4-tab navigation (Home, History, Violations, Account) but reprioritize what appears on each tab. Home screen shows parking status + balance due + open violations. Tabs become doorways to deeper features, not displays of everything at once.

**Expected UX Benefit:** Users can accomplish critical tasks from home without navigating away. Existing users won't need to relearn the app structure.

**Trade-off:** Requires careful card design to surface information without clutter.

**Confidence:** HIGH (preserves existing navigation; low relearning cost)

---

## 3. WHAT WE PRESERVE

### Navigation Structure
**Current:** 4-tab bottom navigation (Home, History, Violations, Account)  
**Why preserve:** Mobile users expect bottom tabs; relearning a new pattern adds friction. Existing users will feel familiar with the app structure. Research shows 4–5 tabs is optimal.

### Color Palette
**Current:** Indigo (primary), Sky (secondary), Mint (tertiary), Green (success), Amber (warning), Red (danger)  
**Why preserve:** Locked by design constraints; already strong and professional. Recoloring would feel like a pointless rebrand without functional benefit.

### Typography System
**Current:** Inter Display (headlines), Inter (body)  
**Why preserve:** Already accessible, modern, and clear. No justification to change.

### Hero Card (Parking Status)
**Current:** Prominent gradient card showing current parking slot and availability  
**Why preserve:** Users open the app to see this. It's in the right place (top of home screen) and already visually prominent. Research supports hero cards for dashboards.

### Mascot Element
**Current:** Wave character used on hero cards and payment notifications  
**Why preserve:** Provides brand recognition and warmth. Low visual load (appears sparingly). Research supports mascots in success moments and brand identity.

### Payment Integration
**Current:** Third-party payment provider (simulated checkout)  
**Why preserve:** Payment flow already works. Changing it introduces risk and doesn't solve UX problems.

### Account Management Structure
**Current:** Profile, vehicles, settings in Account tab  
**Why preserve:** These screens are functional. Reorganization doesn't address user friction points.

### Badge/Status System
**Current:** Badges for violations (red), payment due (amber), good standing (green)  
**Why preserve:** Color coding is already understood by users. Research supports this pattern.

### Flat, Modern Visual Design Language
**Current:** Minimal shadows, clean shapes, generous whitespace  
**Why preserve:** Suits a utilitarian app (parking). Scales well to small screens. Supports fast scanning.

---

## 4. WHAT WE IMPROVE

### Priority 1 (High Impact, High Confidence)

**Improve 1.1: Availability Data Freshness**
- Current: No timestamp or refresh indication
- Change: Add "Updated 30s ago" text + pull-to-refresh + refresh-on-app-resume
- Reason: Research + psychology of trust; users need to know data is current
- Effort: Low (UI + simple backend polling)

**Improve 1.2: Violation Row Affordance**
- Current: Rows are tappable but give no visual cue
- Change: Add trailing chevron; highlight on tap; ensure state change is visible
- Reason: Research shows affordances are critical; affordances signal interactivity
- Effort: Low (UI change only)

**Improve 1.3: Payment Quick-Access**
- Current: Payment info in Payments tab; must navigate away from home
- Change: Add "Pay ₱XXX" button to home dashboard (if balance due); link directly to checkout
- Reason: Research + user friction; payment is a core task that should be <1 tap from home
- Effort: Medium (requires new home card variant)

**Improve 1.4: Payment Breakdown**
- Current: Checkout shows total; details require tapping individual payments
- Change: Show itemized fee list on checkout (slot, date, duration, rate, total)
- Reason: Research + fairness; transparent pricing reduces disputes
- Effort: Low (UI change to existing checkout)

### Priority 2 (Medium Impact, Medium Confidence)

**Improve 2.1: Violation Wording**
- Current: "You overstayed" (judgmental)
- Change: "Vehicle exited 17:30 after 3.5 hours @ ₱50/hr = ₱175" (factual)
- Reason: Psychology of procedural fairness; factual language reduces defensiveness
- Effort: Medium (backend template change + testing)

**Improve 2.2: Appeal Discoverability**
- Current: Appeal form exists but hidden
- Change: Move Appeal button to top of violation detail; use primary color; ensure it's obvious
- Reason: Research + user control; appeals should feel encouraged
- Effort: Low (UI rearrangement)

**Improve 2.3: Appeal Evidence Upload**
- Current: Text-only appeal form
- Change: Add file picker for evidence (photo/video/document); show upload state
- Reason: Research shows evidence strengthens appeals; backend already supports this
- Effort: Medium (UI + file upload integration)

**Improve 2.4: Appeal Status Tracking**
- Current: Appeal submitted but no feedback; user doesn't know if it was received
- Change: Show "Appeal received" screen after submit; add "Appeal Status" view (Under Review, Approved, Rejected with reason)
- Reason: Research + feedback psychology; status visibility reduces uncertainty
- Effort: Medium (requires backend status tracking + UI)

**Improve 2.5: Gamification Explanation**
- Current: Points, streak, standing shown but unexplained
- Change: Add "How Standing Works" help screen; explain tiers and consequences
- Reason: Research + engagement; gamification works when system is clear
- Effort: Low (static content screen)

### Priority 3 (Nice-to-Have, Lower Confidence)

**Improve 3.1: Microinteractions for State Change**
- Current: Availability count updates instantly (no animation)
- Change: Add smooth number animation when count changes; subtle highlight glow
- Reason: Motion research; animation signals that data is live
- Effort: Low (animation library)

**Improve 3.2: Loading/Refresh States**
- Current: Some screens lack loading indicators
- Change: Add skeleton screens or spinners during fetch operations
- Reason: Feedback research; visible loading prevents users from thinking the app hung
- Effort: Medium (systematic review of all data-dependent screens)

---

## 5. WHAT WE DEFER / VALIDATE

### Deferred Idea 1: Smart Slot Recommendation
**Why interesting:** Research shows recommendations reduce decision paralysis and improve slot assignments.  
**Currently unknown:** Backend does not have `GET /api/parking/recommend` endpoint; Phase 3 feature.  
**What needs validation:** User willingness to accept system recommendation vs. choosing manually. Cost/benefit of reservation holds (Phase 3 decision, not UX).  
**Belongs to:** Product roadmap (Phase 3). UX can prepare for it, but not implement in Phase 2.

### Deferred Idea 2: Slot Reservation Countdown
**Why interesting:** Research shows countdown timers create urgency and clarity about hold duration.  
**Currently unknown:** Phase 3 product decision. How long should a slot be held? 10 minutes? Are cancellations allowed?  
**What needs validation:** User behavior with reservation windows. Do users feel rushed or confident?  
**Belongs to:** Product/engineering (Phase 3). UX design should prepare for this, but not implement now.

### Deferred Idea 3: Major Gamification Redesign
**Why interesting:** Gamification could be more prominent or rewarding (leaderboards, badges, tier perks).  
**Currently unknown:** Do users actually care about points/streak/standing? Does prominence help or distract?  
**What needs validation:** User interviews about motivation. A/B testing if implemented.  
**Belongs to:** Product research + user testing. Should be validated before committing.

### Deferred Idea 4: Payment Wallet Integration
**Why interesting:** Apple Pay / Google Pay would speed checkout for returning users.  
**Currently unknown:** Current integration is simulated/third-party. Technical feasibility unknown.  
**What needs validation:** User interest in biometric payment. PCI compliance requirements.  
**Belongs to:** Engineering + product decision. Worthwhile but beyond Phase 2 scope.

### Deferred Idea 5: Dark Mode
**Why interesting:** Campus users may use app at night; dark mode reduces eye strain.  
**Currently unknown:** User demand. Whether it's worth the design/testing effort.  
**What needs validation:** User surveys or usage patterns.  
**Belongs to:** Product prioritization. Good future enhancement but not critical now.

### Deferred Idea 6: Major Navigation Restructuring
**Why interesting:** Some research products use tab-less navigation (gestural or drawer-based).  
**Currently unknown:** Whether users would accept a major navigation change.  
**What needs validation:** Usability testing with existing users.  
**Belongs to:** Strategic redesign decision. Current navigation works; incremental improvement is safer.

---

## 6. CORE UX PRINCIPLES

### Principle 1: Clarity Before Decoration

**Definition:** Information and actions should be immediately understandable before visual flourishes are introduced.

**Why it matters:** Users access AimPark in the car or at a gate under time pressure. Parsing visual complexity slows decision-making. Clarity reduces uncertainty and builds trust.

**Example Application:** Parking availability should show "15 slots free" and "Updated 30s ago" before any decorative gradients or illustrations. Payment breakdown should show itemized fees before any color-coded categories.

**What Violates This:** Adding a pie chart to show slot distribution (visually interesting but adds cognitive load). Using subtle color shifts to indicate status instead of explicit labels.

**Supported by:** Visual hierarchy research, real-time dashboard UX, parking app patterns.

---

### Principle 2: Show System State

**Definition:** When something is loading, updating, pending, failed, or completed, communicate that state explicitly.

**Why it matters:** Silent operations create anxiety. Users assume the app is broken if nothing changes after they tap a button. Visible feedback builds confidence and trust.

**Example Application:** When user taps "Pay," show a loading spinner with "Processing payment…" Not: silent redirect to success. When availability refreshes, show skeleton loading state, not a blank card.

**What Violates This:** Payment button changes color silently (user doesn't know it's processing). Appeal form submit disappears with no confirmation. Data updates with no indication that it's fresh.

**Supported by:** HCI feedback principles, real-time UX research, interaction design standards.

---

### Principle 3: Reduce Decisions, Preserve Control

**Definition:** Recommend sensible defaults when useful, but ensure users understand the recommendation and can override it.

**Why it matters:** Reducing cognitive load is good; removing user control feels paternalistic and frustrating. Balance matters.

**Example Application:** (Phase 3) Show "Recommended: Slot M3" prominently, but let user tap "Browse other options" to see the full list. Don't force the recommendation or hide alternatives.

**What Violates This:** Recommending a slot and disabling other options. Showing only recommended slots with no alternative path.

**Supported by:** Cognitive load research, user autonomy psychology, control & agency principles.

---

### Principle 4: Transparency Builds Trust

**Definition:** Payments, violations, status, and important decisions should be understandable without hidden information or complex language.

**Why it matters:** AimPark involves money and rule enforcement. Users will distrust the system if information is obscured or unclear. Fair process matters more than the outcome.

**Example Application:** Violations show duration + rate + total calculation. Appeals show status and timeline explicitly. Payments show fee breakdown. Nothing is hidden.

**What Violates This:** Showing only a total fee without breakdown. Vague violation language ("Policy violation"). Silent appeal handling with no status update.

**Supported by:** Procedural justice psychology, payment UX research, fairness principles.

---

### Principle 5: Familiarity Over Novelty

**Definition:** Use established mobile interaction patterns unless there is strong evidence a different approach is needed.

**Why it matters:** AimPark's users have varying tech literacy (campus-wide, not just power users). Familiar patterns reduce relearning and friction. Novel interactions are only worth the cost if they solve a real problem.

**Example Application:** Keep bottom tab navigation (standard mobile pattern). Use tappable rows with chevrons (standard pattern). Use standard alert dialogs, forms, and card layouts.

**What Violates This:** Replacing tabs with a gesture-only navigation. Using a novel swipe pattern for something a button does better.

**Supported by:** Mobile UX research, interaction design standards, Nielsen Norman guidelines.

---

### Principle 6: Motion Has Purpose

**Definition:** Animation should communicate state, feedback, hierarchy, or continuity — not exist purely for decoration.

**Why it matters:** Motion can clarify or distract. Purposeful animation improves clarity; decorative animation fatigues users and slows perceived performance.

**Example Application:** Number tween animation when availability updates (signals data is live). Scale-down on button press (feedback). Slide transition between pages (continuity). NOT: spinning logo while waiting, wiggling cards, cascading entrances.

**What Violates This:** Adding animation to every interaction. Using motion to hide latency. Decorative effects that don't communicate anything.

**Supported by:** Motion/interaction research, perception psychology, performance UX.

---

### Principle 7: Accessibility by Default

**Definition:** Designs should work for users with different abilities, devices, and contexts without separate "accessible versions."

**Why it matters:** Campus users include people with disabilities. AimPark's critical paths (parking, payment) must work for everyone. Accessibility benefits everyone (low light, one-handed use, distraction).

**Example Application:** Text contrast ≥4.5:1 (WCAG AA). Buttons ≥48dp (one-handed use). No information conveyed by color alone (colorblind users). Keyboard navigation works.

**What Violates This:** Thin fonts on light backgrounds. Tiny buttons. Color-only status indicators. No keyboard support.

**Supported by:** WCAG standards, accessibility research, inclusive design principles.

---

## 7. EXPERIENCE PERSONALITY

AimPark should feel **reliable, clear, helpful, and calm** — not exciting or playful, but not cold or corporate either.

### Characteristic 1: Reliable

**We want users to feel:** Parking is manageable; the system has their back; they can trust the information.

**We should therefore:**
- Show data freshness (timestamps)
- Provide explicit confirmations
- Use factual, honest language
- Make status visible at all times

**We should avoid:**
- Vague wording ("something happened")
- Hidden fees or charges
- Silent operations
- Excessive promises ("guaranteed" slots, instant approval)

### Characteristic 2: Clear

**We want users to feel:** I understand what's happening; I know what to do next; information is presented simply.

**We should therefore:**
- Use short labels and clear hierarchy
- Show one primary action per screen
- Break complex information into manageable pieces
- Explain systems upfront (gamification, standing, appeals)

**We should avoid:**
- Jargon or technical terms
- Dense text blocks
- Multiple equally-important actions
- Unexplained abbreviations

### Characteristic 3: Helpful

**We want users to feel:** The system is on my side; it guides me without controlling me; I have agency.

**We should therefore:**
- Provide guidance (help screens, tooltips for first-time use)
- Make recovery clear (error messages with solutions)
- Show what happens next (timelines, status)
- Offer recommendations without forcing them

**We should avoid:**
- Punitive language
- Accusatory tone
- Lack of explanation for decisions
- Apparent arbitrariness

### Characteristic 4: Calm

**We want users to feel:** I'm in control; the system is not adding stress; there's no artificial urgency.

**We should therefore:**
- Use restrained motion (not flashy)
- Avoid fake scarcity ("only 2 slots left!" when 15 are free)
- Give users time to think (not rushing through onboarding)
- Use reassuring language ("take your time," "you can review before paying")

**We should avoid:**
- Excessive notifications
- Flashing colors or alerts
- Artificial deadlines
- Demanding language ("you must," "required now")

---

## 8. UX BALANCE

AimPark operates across several potentially competing dimensions. This section defines the intended balance:

```
              EFFICIENCY
                  ↑
                  |
       TRUST ←────┼───→ FRIENDLINESS
                  |
                  ↓
             ENGAGEMENT
```

### Positioning:

**High TRUST (primary)**
- Users must trust that parking status is accurate
- Users must trust that payment is fair and secure
- Users must trust that violations are justified
- Trust > engagement

**High EFFICIENCY (primary)**
- Users access app in car or at gate under time pressure
- Core tasks (parking, payment) should be completable in <2 minutes
- Efficiency > decoration

**Moderate FRIENDLINESS (secondary)**
- Tone should be warm but professional, not cute or casual
- Mascot provides warmth without compromising clarity
- Gamification adds personality without distracting from core task
- Friendliness supports trust and efficiency; doesn't override them

**Moderate ENGAGEMENT (tertiary)**
- Gamification (points, streak, standing) should motivate responsible parking
- Engagement should not manipulate or coerce
- Engagement is secondary to trust and efficiency
- Never sacrifice trust or clarity for engagement

### Decision Rule:

When dimensions conflict, prioritize: **Safety → Accessibility → Trust → Efficiency → Friendliness → Engagement**

Never sacrifice trust for engagement. Never sacrifice clarity for decoration. Never remove control in pursuit of engagement.

---

## 9. MASCOT STRATEGY

### Current Mascot Usage
The wave character currently appears on:
- Hero card (parking status)
- Payment due notifications

### Where Mascot SHOULD Appear

1. **Hero Card** — Existing placement is good. Provides brand recognition and visual warmth.

2. **Success Moments** — Celebration after first parking, after payment confirmed, after appeal submitted. Mascot with checkmark signals "you did it!"

3. **Empty States** — "No violations yet" with mascot + peace sign illustration. "No parking history" with mascot + empty state illustration.

4. **Payment Due Notification** — Existing placement (friendly reminder to pay).

5. **First-Parking Celebration** — Special screen after user's first successful parking session: "Welcome! You parked at M3. +10 pts. 🎉" (with mascot).

### Where Mascot SHOULD NOT Appear

1. **Violation Detail** — Mascot would trivialize a serious message. User is being charged or warned. Keep tone formal.

2. **Payment Checkout** — Focus should be on total cost and security. Mascot is distracting.

3. **Appeal Process** — Appeals require seriousness and fairness. Mascot would undermine that.

4. **Error Screens** — "Something went wrong" should be direct and serious, not cute.

5. **Dense Forms** — Every card showing mascot becomes noise. Reserve it for special moments.

6. **Status/Badges** — Straight icons and colors only (good standing ✓, violation ✗).

### Purpose

The mascot serves **brand recognition and emotional warmth** in moments where users feel accomplishment or need reassurance. It does not appear in critical workflows where clarity and seriousness are priorities.

---

## 10. GAMIFICATION STRATEGY

### What Gamification Is For
- Motivating consistent parking behavior (streak)
- Recognizing good account standing
- Creating a sense of progress and achievement
- Encouraging users to return to the app

### What Gamification Is NOT For
- Manipulating users into unnecessary actions
- Creating artificial urgency or scarcity
- Replacing core parking functionality
- Being more prominent than parking itself

### Where It Appears

1. **Home Dashboard** — Standing tier, current streak, points balance visible but not dominant. Parking status is primary; gamification is supporting.

2. **History/Session Detail** — "+10 pts earned" shown for each parking session. Streak counter shows streak progress.

3. **Help/How It Works Screen** — Full explanation of tiers, points, and consequences.

4. **Notifications** — "3-day streak! Keep it going" after a parking session. Only positive notifications (not punitive).

### How Users Understand It

Add a "?" help button next to "Good Standing" on the dashboard. Tapping it shows:
- "Gold standing (0 violations) = full access"
- "Silver standing (1 violation) = access monitored"
- "Bronze standing (2+ violations) = possible suspension"
- "Earn points per parking session (+10 pts). Maintain 7-day streak (+50 pts bonus on day 7)."

### When It Remains Secondary

- Home screen should prioritize parking status and balance due before gamification
- Gamification should never block or require participation to use core features
- Users with zero interest in points should still be able to park and pay normally

### Manipulative Patterns to Avoid

❌ **No Confirmshaming:** "OK, I'll lose my streak" (button accepting a bad outcome)  
❌ **No Fake Urgency:** "Only 2 slots left! Rush now!" (when 15 are actually free)  
❌ **No Forced Engagement:** Requiring users to understand points to park  
❌ **No Hidden Tier Consequences:** Making suspension a surprise (must be explicitly stated)  
❌ **No Reward Bait:** Offering bonus points that are never achievable  

### Research Support

Research shows gamification works when:
- System is explained upfront
- Achievements are tied to real behavior
- Tier consequences are transparent
- Progression feels achievable (not grindy)

---

## 11. MOTION PHILOSOPHY

Motion in AimPark should enhance clarity and feedback, never distract or deceive.

### Motion Should Communicate

1. **State Changes** — Loading spinner to show processing. Checkmark animation to show confirmation. Color fade on updated data.

2. **System Feedback** — Button scale-down on press (user input was received). Highlight glow when data updates (live signal).

3. **Continuity** — Slide transition between pages (logical connection). Persistent hero card across navigation (visual consistency).

4. **Hierarchy** — Staggered entrance of form fields (content order). Subtle emphasis on primary action (scale + color).

5. **Successful Completion** — Checkmark animation + success color wash after payment or appeal submission (accomplishment signal).

### Motion Should NOT

1. **Delay Important Actions** — Don't use 500ms entrance animations on critical workflows. Fast > beautiful.

2. **Hide Latency** — Spinning logo does not make the app faster. Show real progress or state honestly ("Loading…").

3. **Distract from Critical Info** — Wiggling cards or cascading animations on payment screen = bad. Clean, static layout = good.

4. **Create Fake Urgency** — Pulse or glow on limited slots when supply is actually high. Honest state only.

5. **Reduce Accessibility** — Flashing/strobing (epilepsy risk). Motion-based UI that has no non-motion alternative (vestibular disorders).

### Motion Principles (No Specific Durations Yet)

- **Transitions should be smooth and brief** (200–400ms typical; feels snappy on mobile)
- **Loading indicators should be confident** (spinning, not janky or stuttering)
- **Success animations should be celebratory but restrained** (checkmark in 300–500ms, not elaborate)
- **Emphasis animations should be subtle** (gentle glow, not harsh flash)
- **Avoid animation fatigue** (single-use animations in workflows, not every interaction)

### Research Support

Research shows motion is most effective when:
- It communicates state or feedback (not decoration)
- It feels responsive and snappy (not laggy)
- It's consistent across the app (same pattern used everywhere)
- It works on low-end devices and poor connections

---

## 12. INFORMATION HIERARCHY

Based on user research, establish what information receives priority on different screens.

### Parking Discovery Screen

**Tier 1 (Immediate):**
- Current parking status ("You are parked at M3" OR "Not currently parked")
- Available slots count ("15 slots free")
- Data freshness ("Updated 30s ago")

**Tier 2 (Important):**
- Slot availability by type (motorcycles vs. cars)
- Gate locations (Gate 1, Gate 2)
- Rate information (₱50/hour)

**Tier 3 (Supporting):**
- Recent parking history (last 3 sessions)
- Tips ("Pro tip: M-section is closest to entrance")

**NOT INCLUDED (too much):**
- Full slot grid layout on home (move to dedicated Parking tab)
- Real-time sensor data
- Facility map

### Payment Screen

**Tier 1 (Immediate):**
- Total balance due ("₱500 owed")
- Most recent unpaid session
- "Pay Now" button

**Tier 2 (Important):**
- Itemized list of unpaid sessions
- Session breakdown (date, slot, duration, rate, cost)
- Due date if applicable

**Tier 3 (Supporting):**
- Payment history (past 10 sessions)
- Average parking duration
- Monthly spending summary

**NOT INCLUDED (too much):**
- Analytics or trends
- Predictive costs
- Comparison to other users

### Violation Screen

**Tier 1 (Immediate):**
- What rule was violated
- When it happened (date, time)
- Penalty amount
- **Appeal option (prominent)**

**Tier 2 (Important):**
- Vehicle involved (slot, entry/exit times)
- Violation category (overtime, unauthorized vehicle, etc.)
- Policy reference (what rule was broken)
- Evidence (photos, timestamps)

**Tier 3 (Supporting):**
- Appeal timeline ("Decision in 3–5 business days")
- Appeal history (if user has appealed before)
- Payment option if not appealing

**NOT INCLUDED (too much):**
- Admin notes or comments (internal info)
- Complex rule explanations

### Home Dashboard (Summary)

**Tier 1 (Immediate):**
- Current parking status
- Available slots + data freshness
- Balance due (if any) with "Pay" button
- Open violations count (if any) with link

**Tier 2 (Important):**
- Standing tier (Good / Monitored / Suspended)
- Current streak (days)
- Latest notification or alert

**Tier 3 (Supporting):**
- Quick action buttons (Report Incident, View Account)
- Upcoming events (permit expiry, etc.)

**NOT INCLUDED (too much):**
- Full payment history (link to Payment tab instead)
- Full violation list (link to Violations tab)
- Detailed points breakdown

---

## 13. DASHBOARD PHILOSOPHY

### Central Question
**When a user opens AimPark, what should they understand within 3–5 seconds?**

### Answer
1. **Where am I parked right now?** (primary question)
2. **How much do I owe?** (if anything)
3. **Do I have any open violations?** (if any)
4. **Is my account in good standing?** (health check)

### Primary Information (Above Fold)

The hero card should show:
- **Status:** "Currently Parked at Slot M3" OR "Not Parked"
- **Availability:** "15 slots available | Updated 30s ago"
- **Quick Action:** "Find a Slot" button (if not parked) OR "View Parking Details" button

### Primary Action

The one clearest action available to user on home:
- **If not parked:** "Find a Slot" or "Check Availability"
- **If parked:** "View My Parking" (to see details, duration, cost estimate)
- **If payment due:** "Pay ₱XXX" button (overlays or supplements above)

### Secondary Actions

Below the hero card, visible without scrolling:
- **Balance Due Card** (if owed; includes payment button)
- **Open Violations Badge** (if any; links to violations tab)
- **Standing Tier Display** (Good / Monitored / Suspended)

### Important Alerts

Should appear but not dominate:
- **Payment Overdue:** Amber badge + card with payment prompt
- **Open Violation:** Red badge + text; links to detail
- **Suspension Active:** Red alert; explains restriction

### Supporting Information (Optional)

Only if scrolling doesn't feel required:
- Recent activity (last 2 parking sessions)
- Current streak (days of clean parking)
- Quick action buttons (Report Incident, View Account)

### Information That Should NOT Compete

Hide or de-emphasize:
- Full payment history (link to tab instead)
- Full parking history (link to tab)
- Detailed points breakdown
- Facility announcements (separate section if needed)
- Promotions or marketing

### Philosophy

Home is not a dashboard; it's a launching pad for tasks. Users should:
1. **Understand their status instantly**
2. **Know what action to take next**
3. **Be able to take that action with one tap**
4. **Navigate to deeper features if needed**

Home should never feel like "everything in one screen." It should feel like "the most important things, clearly."

---

## 14. CORE JOURNEY STRATEGY

### Journey 1: Find Parking

**What should the user know?**
- Is there space available?
- Where should I park?
- Which gate should I use?
- What is the rate?

**What should the system recommend?**
- (Phase 3) One recommended slot + hold countdown
- (Current Phase 2) Guidance on which slots to pick ("M-section is closest to entrance")
- Gate location relative to parking area

**How much control should the user have?**
- Browse full slot list if they want
- Override recommendation
- Cancel and try again
- Full transparency on why a slot was recommended

**What feedback should they receive?**
- Slot reserved notification (Phase 3)
- Confirmation of RFID scan at gate
- Entry logged notification
- Current parking status displayed immediately

---

### Journey 2: Pay

**What should be immediately visible?**
- Total balance owed
- If payment is overdue
- Available payment methods
- Expected arrival time for payment to process

**How should cost be communicated?**
- Itemized breakdown (date, duration, slot, rate, total)
- Clear calculation (3 hours @ ₱50/hr = ₱150)
- Any fees or penalties itemized separately
- No surprises

**How should confirmation work?**
- Order review screen before final submit
- Explicit confirmation button ("Pay ₱150 from Card 42")
- Success screen with checkmark + receipt
- Email/SMS confirmation if available
- Balance updates in real-time after payment

**Expected UX:**
From home screen "Pay ₱XXX" → Review order → Confirm → Success → Balance shows ₱0 due

**Time budget:** <2 minutes from tap to confirmation

---

### Journey 3: Handle Violation

**How should the user discover the issue?**
- Push notification (if notification service active)
- Violation badge on home dashboard (if missed notification)
- Violations tab always shows unresolved violations
- Red alert if standing is affected

**How should the information be presented?**
- Violation detail screen with clear explanation
- Facts: vehicle, date, time, slot, rule broken, penalty amount
- Evidence (photos, sensor data) if available
- Standing impact (will this affect my access?)

**How should the appeal process work?**
- Clear "Appeal" button on violation detail screen
- Appeal form: explanation + evidence upload
- Show expected timeline ("Decision in 3–5 business days")
- Optional: pre-filled template ("I believe this charge is incorrect because…")

**How should status be communicated?**
- After appeal submit: "Appeal received | Status: Under Review | Submitted Aug 20 | Expected decision by Aug 25"
- Violation tab shows appeal status for each violation
- Notification when decision is made
- Final outcome screen showing approval/rejection + reason

**Expected UX:**
Receive violation → Read detail → Tap Appeal → Upload evidence → Write explanation → Submit → See status confirmation → Get notified of decision

---

### Journey 4: Manage Account

**What should be easy to access?**
- Profile (email, phone, password change)
- Vehicles (registered cars, RFID status)
- Payment methods (saved cards)
- Settings (notifications, privacy)

**What should remain secondary?**
- Subscription management
- Documentation upload
- Support contact

**Interface:**
Account tab shows main sections as cards or simple menu. Tapping opens detail screen. No complex nested navigation.

---

## 15. VISUAL DIRECTION

### Visual Character

AimPark should feel **clean, modern, and structured** — not playful, not premium, not corporate.

- **Not Playful:** No rounded corners on every element, no excessive illustrations, no animated mascots everywhere
- **Not Premium:** No gradients on gradients, no complex shadows, no luxury aesthetic
- **Not Corporate:** Not sterile or cold, not intimidating, not aggressively formal

**Instead:** Professional but approachable. Calm and clear. Trustworthy but not boring.

### Shape Language

- **Cards:** Subtle rounded corners (8–12px). Minimal shadow (1–2px blur, low opacity).
- **Buttons:** Primary buttons have slightly more rounded corners (12px). Secondary buttons are flatter.
- **Icons:** Clean, simple line work. 24–48px sizes. Consistent stroke weight.
- **Input Fields:** Subtle border, light background. Border on focus; no excessive glow.
- **Dividers:** Thin, low-contrast lines (not heavy).

**Philosophy:** Shapes support content hierarchy without competing. Restraint > decoration.

### Visual Density

Screens should feel **moderately spacious with clear grouping** — not cramped, not sparse.

- **Padding/Margin:** Generous around primary content (16–24px). Tighter around secondary (8–12px).
- **Line Height:** Comfortable reading (1.5–1.6 for body text). Tighter for labels (1.3).
- **Card Spacing:** 12–16px between cards. Not touching; not floating far apart.

**Philosophy:** Breathing room helps scanning. But excessive whitespace feels empty.

### Imagery & Illustration

**Where illustrations belong:**
- Empty states ("No violations yet 🎉" with contextual illustration)
- Success moments (checkmark + celebration illustration)
- First-time user guidance (optional)
- Mascot in specified places (see Mascot Strategy)

**Where illustrations do NOT belong:**
- Critical workflows (payment, violation, appeal)
- Data-heavy screens (history, payment list)
- Every card or status

**Style:** Illustrations should match existing visual language (flat, simple, modern). If a mascot illustration exists, use it consistently. Don't invent new illustration styles.

### Color Behavior

**Locked Palette:** Indigo (primary), Sky (secondary), Mint (tertiary), Green (success), Amber (warning), Red (danger)

**Behavior Definitions:**
- **Indigo:** Primary actions, headers, brand moments. Dominant color.
- **Sky:** Secondary actions, disabled states, subtle backgrounds. Supportive.
- **Mint:** Tertiary accents, positive state indicators. Sparingly used.
- **Green:** Success feedback, good standing, checkmarks. Always positive.
- **Amber:** Warnings, payment due, attention needed. "Hey, look."
- **Red:** Errors, violations, critical alerts. "Take action."
- **Neutral (Grays):** Text, borders, backgrounds. 10+ shades from dark to light.

**Philosophy:** Color conveys meaning (status, action type). Not decorative. High contrast for text (≥4.5:1 AA).

### Typography Behavior

**Locked Fonts:** Inter Display (headlines), Inter (body)

**Hierarchy (proposed, no change to fonts):**
- **Display/Hero:** 32–40px, semi-bold. Home screen status ("Currently Parked at M3").
- **Headline:** 20–24px, semi-bold. Card titles, screen titles.
- **Body:** 14–16px, regular. Main content, descriptions.
- **Caption:** 12–13px, regular. Supporting info, timestamps.
- **Overline:** 11–12px, semi-bold, uppercase. Labels, section headers.

**Philosophy:** Hierarchy comes from size + weight + spacing, not font changes. Clean and scannable.

---

## 16. DESIGN SUCCESS CRITERIA

The redesigned AimPark is successful if:

1. **Availability is Trusted**
   - Users can see when data was last updated
   - Users can manually refresh if desired
   - User satisfaction with accuracy increases (measured by NPS or survey)

2. **Important Actions are Discoverable**
   - Users find the Appeal button without help (success rate >80%)
   - Users find the Pay button from home screen without navigation (success rate >90%)
   - Users complete incident reports without getting lost (success rate >80%)

3. **Payments are Clear**
   - Users can articulate what they're paying for (test with "why is this charge?" interview)
   - Payment dispute rate decreases (measured over 4 weeks post-launch)
   - Checkout abandonment rate is <5% (measured with analytics)

4. **Violations Feel Fair**
   - Users report that violations are explained clearly (survey question: "I understood why I was charged")
   - Appeal rate increases (shows users feel empowered to contest)
   - Successful appeal rate increases (shows appeals are better reasoned)

5. **System Status is Always Visible**
   - Users report "I know what's happening" after taking actions (survey: "I felt in control")
   - Support tickets about "did my action go through?" decrease
   - Loading/confirmation screens appear on all consequential actions

6. **Gamification is Understood**
   - Users can explain how standing tiers work (test with "what does Silver mean?" interview)
   - Users report caring about their streak (survey: "I try to park consistently")
   - Gamification does not interfere with core parking task

7. **Existing Users Can Continue Seamlessly**
   - 80%+ of existing users can complete familiar tasks within 1 attempt
   - 90%+ of existing users report "I didn't have to relearn the app"
   - Adoption of new features is >50% within 2 weeks of launch

8. **Core Journeys Are Fast**
   - Average time to check parking status: <10 seconds
   - Average time to complete payment: <90 seconds
   - Average time to submit appeal: <3 minutes

9. **Accessibility is Intact**
   - All interactive elements are ≥48dp
   - Text contrast is ≥4.5:1 on all backgrounds
   - Keyboard navigation works throughout
   - Screen readers can use the app (manual testing needed)

10. **Visual Design Feels Right**
    - Users report app feels "professional" and "trustworthy" (survey: tone/personality assessment)
    - No users report app feels "cold," "corporate," or "confusing"
    - Visual hierarchy matches actual task priority (tested with eye-tracking or observation)

---

## 17. OPEN QUESTIONS FOR VALIDATION

1. **Slot Recommendation Timing:** Should recommendation appear on parking screen (user initiates) or only at RFID gate (system initiates after scan)? When should hold countdown start?

2. **Appeal Review Timeline:** Is "3–5 business days" realistic? Should it be faster (24–48 hours) or slower (2 weeks)? How will users be notified of decision?

3. **Gamification Opt-Out:** Should users be able to hide points/streak/standing if they find it distracting? Or is it always visible?

4. **Violation Evidence Types:** What file types should evidence accept (photos, videos, PDFs)? Size limits? Should there be a maximum number of uploads?

5. **Payment Method Reset:** If a saved payment fails, should the form auto-switch to manual card entry or ask the user?

6. **Availability Polling Frequency:** How often should the app refresh availability in the background? Every 5 seconds? 10 seconds? Or only on user interaction?

7. **Data Persistence:** If user is filing an appeal and a push notification arrives, should the form be saved locally? Or is losing the draft acceptable?

---

## 18. DESIGN DECISIONS REQUIRING VALIDATION

The following decisions are sound design hypotheses but should be validated before final implementation:

### Hypothesis 1: Factual Violation Language Reduces Disputes
**Assumption:** Changing violation wording from "You overstayed" to "Vehicle exited 17:30 after 3.5 hours" will make violations feel fairer and reduce reflexive appeals.

**How to validate:** A/B test two violation wordings. Measure appeal rate and success rate. Gather qualitative feedback ("Did you feel the charge was fair?").

**Risk:** Longer text may not fit on mobile; might require rework.

### Hypothesis 2: Payment Quick-Access on Home Increases Completion Rate
**Assumption:** Adding a "Pay ₱XXX" button to home screen will reduce payment abandonment and time-to-payment.

**How to validate:** Analytics before/after. Measure average time from app open to payment completion. Measure completion rate (% of users with balance who pay).

**Risk:** Home screen becomes crowded if balance due card is too prominent.

### Hypothesis 3: Appeal Status Tracking Increases Appeal Confidence
**Assumption:** Showing "Appeal under review | Expected decision by Aug 25" will make users feel their appeal is being heard and increase fair appeals.

**How to validate:** Track appeal submission rate before/after. Gather qualitative feedback ("Did you feel your appeal was heard?"). Compare appeal success rates.

**Risk:** Backend must track appeal status; requires admin changes.

### Hypothesis 4: Timestamp + Refresh UI Increases Trust in Availability Data
**Assumption:** Showing "Updated 30s ago" + manual refresh option will make users trust the availability number more and reduce wasted trips.

**How to validate:** Survey users: "How fresh do you believe the availability data is?" Measure app-open-to-lot-entry time. Track support tickets about "lot was full but app said it was open."

**Risk:** More API calls; backend needs caching strategy to avoid overload.

### Hypothesis 5: Gamification Help Screen Increases Engagement
**Assumption:** Adding a "How Standing Works" screen will help users understand gamification and care more about their standing tier.

**How to validate:** Track help screen views. Measure if users who read it have higher streak rates or standing awareness.

**Risk:** Users may never find or read the help screen; feature may be invisible.

---

## SUMMARY

This Design Direction document establishes the **strategy and philosophy** for the AimPark redesign before any final UI design. 

### Key Principles
- **Preserve:** Existing navigation, color, typography, hero card, payment flow
- **Improve (High Priority):** Availability freshness, action discoverability, payment clarity, violation fairness, system status visibility
- **Defer:** Slot recommendation, reservation countdowns, major gamification changes, wallet integration
- **Values:** Clarity > Decoration | Trust > Engagement | Efficiency > Novelty | User Control > Paternalism

### Next Phase

**Step 4 — UX Architecture & Screen Design** will use this direction to design actual screens, flows, and component behaviors.

Do NOT proceed to high-fidelity UI design without stakeholder alignment on this direction.

---

**This Design Direction is COMPLETE and ready for review.**
