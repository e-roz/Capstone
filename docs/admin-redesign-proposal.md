# AimPark Admin Panel — Redesign Proposal

**Date:** 2026-10-04
**Status:** Proposal for discussion. No code has been changed.
**Basis:** A read of `aimpark_admin/lib` as it is on `main` (869413a): the router, the
shell, the theme files, the shared `widgets/ui` kit and all 24 screens. I did not
look at the running app for this proposal, so anything about how a screen *looks*
(rather than how it is built) is marked **(check on screen)**.

---

## Decisions (2026-10-04, after looking at the live panel)

Screenshots taken of the deployed panel (`aim-park.web.app`), Admin account, all
18 screens at 1440 / 1024 / 768 / 600 / 390, light theme. Dark mode was **not**
captured (the theme switch could not be clicked by the script).

| # | Question | Decision | Why |
|---|---|---|---|
| 1 | Shell | **Left sidebar.** Uniqueness comes from elsewhere (see §2.4). | Screenshots: at 768 the whole "System" group is off-screen; at 1024 "Backup" and "Site Server" are cut off; System Logs stacks three rows of tabs. |
| 2 | Spec names | **No tag on pages.** Page title = nav label. The Overview module grid (already showing spec names) is the trace map for the panel. | A tag on every page is clutter for the real users, who never read the spec. One map page serves the panel better. |
| 3 | Appeals | **Move into Violations** as an "Appeals" tab. The "Incidents & Appeals" tile on Overview stays, pointing at Incidents, whose page links to Appeals. | An appeal is a step in a violation. The spec feature still exists — it just lives where the work is. |
| 4 | Overview range/export | **Remove from Overview.** | Today the cards say "Sessions **today**" next to a "**14d**" toggle. Mixed message. Reports already repeats 4 of the same cards. |
| 5 | Radius | **Cards/tables 24 → 16, dialogs 28 → 20. Keep pill buttons and pill filters.** | Pill buttons are part of the shared identity with mobile. Big containers are where 24px looks soft and wastes corners. |
| 6 | Scope | **Do all of it, in phases, each merged and tested. Freeze UI one week before the defense.** | Coding is fast with Claude Code. The slow, risky parts are your device testing and breaking something the week of the defense. |

### What the screenshots showed (beyond the code read)

**Bugs to fix regardless of redesign**
1. **Search box is squashed** — about 20px tall next to 40px filter pills, and it sits higher than them. Every list page.
2. **Top nav clips:** at 768px the "System" group is not visible at all; at 1024 the sub-nav cuts "Backup" mid-word. No scroll hint.
3. **Phone tables show 2 columns.** Status, RFID and all actions are off-screen on Users, Violations, etc.
4. **Phone Overview:** "Live parking" title wraps one syllable per line ("Live / parki / ng").
5. **Phone table footer collides:** "Showing 1–5 of 5 usersPage 1 of 1".
6. **Phone shows the title twice** (app bar + page header).

**Design problems**
7. **Mono everywhere:** long sentences in IBM Plex Mono — Backup's red warning, empty-state text, card subtitles. Hard to read.
8. **Primary button moves around:** in the header (Violations, Parking, Backup), in the toolbar row (Devices, Visitor Passes). Refresh icon changes place on every page.
9. **Two primary buttons on one view:** Backup ("Create backup" + "Create backup now"), Visitor Passes ("Issue a card" ×2).
10. **Visitor Passes contradicts itself:** "No visitor cards are registered yet" *and* "Every visitor card is in the drawer", while offering "Issue a card", which cannot work.
11. **Raw data leaks:** Payments shows `ViolationPenalty` as a source, and "0 min / ₱0.00/hr" columns that mean nothing for a penalty.
12. **Loud rows:** Users has coloured Suspend + Archive buttons on every row.
13. **Reports metric grid** wraps 4 + 2, leaving a hole.
14. **Titles don't match nav:** "Violation Tracking" vs "Violations", "Reports & Monitoring" vs "Reports".

**What looks great (protect it)**
- **The live parking map.** Gates as dark blocks, drive lane, bays with type icons, "Live · just now". This is the most distinctive thing in the product.
- Status pills, calm colour, generous but not wasteful spacing, friendly empty states ("Nothing waiting").

---

## 0. Where we are starting from

Short version: **the foundations are good, the map is messy.**

| Area | Today | Verdict |
|---|---|---|
| Tokens | 3 layers (palette → semantic tokens → Material theme), light + dark, status intents | Strong. Keep. |
| Shared kit | `AppPage`, `AppToolbar`, `AppFilterDropdown`, `AppDataTable`, `AsyncView`, skeletons, `StatusPill`, `MetricCard`, `AppRowAction` | Strong. Extend, don't replace. |
| Shell | Top bar with group pills + a second row of sub-tabs; drawer below 600px | Works, but costs height and needs two clicks to reach most pages. |
| Navigation map | 18 destinations in 5 groups. **"System" holds 9 of them.** | The main problem. |
| Duplicated pages | Payments / Payment Log; Visitor Passes / Visitor Cards; Devices / Site Server / Gate Readers; Violations / Logs › Violations / Incidents › Appeals | Merge. |
| Row actions | Up to 4 inline buttons per row (Users: Suspend, Unsuspend, Restore, Archive) | Too loud; destructive actions sit next to safe ones. |
| Detail views | Mix of full pages, dialogs and none | Pick one rule. |
| Confirmations | About 30 hand-written `showDialog<bool>` confirms | One shared component. |
| Responsive | Tables scroll sideways at every width; nav becomes a drawer below 600 | Needs a real phone/tablet layout, not a squeezed desktop. |

**Two people use this panel, and they are very different:**

| | Administrator | Security guard |
|---|---|---|
| Where | Office desk, laptop or monitor | Guard post PC, sometimes a phone |
| How | Sits down, works through a queue | Interrupted every minute, standing, a car is waiting |
| Wants | Accuracy, full picture, history | Speed, one answer, big buttons |
| Main screens | Registrations, Users, Violations, Payments, Reports | Gate Check, Visitors, Live parking, Incidents |

A third audience matters this month: **the capstone panel**. They will compare the
app to the spec document. Every redesign choice below keeps the spec's module names
findable.

---

## 1. Design direction

### Overall: "calm control room"

A quiet, warm, mostly-neutral workspace where **colour means something**. When
something is red, it is a problem. When something is indigo, it is the thing you
can click. Everything else is cream, white and dark text.

You already have this direction. The redesign sharpens it rather than replacing it.

| Aspect | Choice | Why |
|---|---|---|
| **Aesthetic** | Flat, bordered, warm-neutral. Same cream + indigo as the mobile app. | It is already your identity and it is good. Flat survives dark mode; borders separate data better than shadows. |
| **Personality** | Trustworthy, quiet, exact. Not playful. | People suspend accounts and restore databases here. The UI should feel like it will not surprise you. |
| **Density** | Two densities. **Office** (admin): 44px rows, 14px text, lots of rows on screen. **Post** (guard screens): 48–56px controls, 16px+ text, one task per screen. | One density cannot serve someone scanning 60 rows and someone glancing at a screen while a car waits. |
| **Colour use** | ~90% neutral. Indigo only for: primary button, selected nav, focus ring, links. Status colours only for status. **Never decorative.** | If colour is everywhere, a red "Revoked" pill stops standing out. |
| **One-primary rule** | At most **one filled indigo button per view.** | It answers "what is the main thing to do here?" without reading. |
| **Typography** | Inter for anything you read. Inter Display for titles and big numbers. IBM Plex Mono **only for machine values** (plate, RFID tag, reference no., IDs, times in tables). | Today the small text style (`bodySmall`) and column headers are mono, so all helper text and captions are mono too. Mono is slower to read in sentences. Keep it where it helps: values you compare character by character. |
| **Border radius** | Tighten a little: controls 10, cards/tables 16, dialogs 20, pills full. (Today: controls 18, cards 24, dialogs 28.) | 24px corners on a data table read as "mobile app", and an 18px corner on a 40px button is almost a pill, so buttons and filter pills look the same. **Optional, low priority** — see §11. |
| **Shadows** | Keep: flat cards at rest, shadow only on things that float (menus, side panel, dialogs). | Already right. Shadow = "this is on top of something". |
| **Icons** | Material outlined at 20px; filled version only for the selected nav item. One icon per meaning across the app (e.g. `credit_card` always means RFID card). | Already mostly true. Write the icon-per-meaning list down so it stays true. |
| **Whitespace** | Keep 24 page / 16 card / 12 gutter. Add bigger gaps (32) between *unrelated* groups on the dashboard; keep small gaps inside a group. | Spacing should show grouping. Equal gaps everywhere make a dashboard look like one long list. |

### What "professional admin system" should feel like

1. **Fast.** Nothing animates longer than 200ms. Lists show skeletons, never spinners in the middle of nowhere.
2. **Predictable.** Every list page has the same layout. Learn one, know all.
3. **Honest.** Empty tables say *why* they are empty (a filter? nothing yet? an error?).
4. **Safe.** Dangerous actions look different, sit apart, and ask before they act.
5. **Exact.** Numbers line up, times are clear, IDs can be copied.

---

## 2. Information architecture

### 2.1 Problems with the current map

Current nav (admin view):

```
Overview
Gate         Visitor Passes · Devices                     (+ Gate Check, Gate Readers for Security)
Operations   Pending Registrations · Parking · Payments
Enforcement  Violations · Policy Rules · Incidents
System       User Management · RFID Cards · Visitor Cards · Notifications ·
             Reports · Payment Log · System Logs · Backup & Restore · Site Server
```

1. **"System" is a junk drawer.** 9 of 18 items. Users, Reports and Payment Log are not "system" things. Finding Users means remembering it lives next to Backup.
2. **One topic, many pages.**
   - Payments vs **Payment Log** — same records, one is a working list, one is an export.
   - Visitor Passes vs **Visitor Cards** — who has a card now vs which cards exist. Split across two groups.
   - Devices vs **Site Server** vs **Gate Readers** — Site Server is literally the Devices screen with a flag.
   - Violations vs **System Logs › Violations** vs **Incidents › Appeals** — appeals are *about* violations but live under Incidents.
3. **Two front doors for notifications** — the bell in the top bar *and* a nav item.
4. **Overview and Reports overlap** — both have date ranges and Export.
5. **RFID Cards** only shows revoked cards; enrolling a card happens on the user page. The name promises more than the page does.
6. **Names don't match.** Nav says "Policy Rules", page title says "Policy & Rule Management". Nav says "Gate Check", spec says "Entry/Exit Verification".

### 2.2 Proposed map

**Administrator**

```
Overview

Gates
  Live parking          (was Parking)
  Gate activity         (was System Logs › RFID Access + Gate taps)
  Visitors              tabs: On site · Card stock     (was Visitor Passes + Visitor Cards)

People
  Registrations         (was Pending Registrations)       [badge]
  Users                 (was User Management)
  RFID cards            tabs: Awaiting reissue · All cards

Enforcement
  Violations            tabs: All · Appeals               [badge on Appeals]
  Incidents                                               [badge]
  Policy rules

Payments                tabs: Charges · Ledger · Rates    (was Payments + Payment Log + Manage Rates dialog)

Reports

System
  Devices               tabs: Gate devices · Site server · Health
  Announcements         (was Notifications › Sent + Broadcast)
  Logs                  tabs: Admin actions · User activity · System errors
  Backup & restore
```

Top bar (always): **Search (Ctrl+K)** · **Bell** (inbox) · **Account** (theme, sign out).

**Security guard**

```
Overview (guard)
Gate Check                     ← the guard's home; big, one task
Visitors      tabs: On site · Card stock (read-only)
Live parking  (read-only)
Incidents     (report + follow up; no Appeals)
Gate activity
Devices       tabs: Health · Readers on this PC
```

### 2.3 Why each change

| Change | Reason |
|---|---|
| Split "System" into **People**, **Payments**, **Reports**, **System** | Groups should match what the admin is *doing*. "I need to deal with a person" → People. Nobody thinks "a user is a system setting". |
| **Payments** becomes one page with 3 tabs | Charges (working list), Ledger (date range + export, was Payment Log), Rates (was a dialog). Same data, same people, one place. The spec names "Payment Monitoring" — still one module. |
| **Visitors** merges passes and card stock | The guard lending a card needs to see which cards are free. Two groups apart is two clicks too many. |
| **Devices** merges Devices + Site Server + device health; Gate Readers becomes a tab for Security | They are the same kind of thing (hardware that talks to the server). Site Server is already the same screen. |
| **Appeals move to Violations** | An appeal is a step in a violation's life. Deciding it next to the violation (with its history) is faster and safer. Incidents stays its own page. |
| **Logs** loses the Violations tab and RFID/Gate tabs | Violations already has full filters and history. Gate events are *operations*, not system logs — they move to **Gate activity** under Gates, where guards look. Logs keeps only audit trail and errors. |
| **Bell = inbox, Announcements = sending** | Receiving and broadcasting are different jobs. Removes the duplicate nav entry. |
| **Overview = now, Reports = past** | Overview shows today and what needs attention, no date range, no export. Reports owns ranges, charts and exports. One question per page. |
| **RFID cards** gets an "All cards" tab | Lets the admin answer "whose card is this tag?" without knowing the owner first. Enrollment stays on the user page, where it belongs. |
| **Page title = nav label**, spec name shown as a small tag | Consistency for users; traceability for the capstone panel. E.g. title "Payments", small grey tag "Spec: Payment Monitoring". |
| **Global search** | The most common admin question is "who is this?" — from a plate, a tag, a name or a student number. Today that means guessing which page to open. |

**Tabs live in the URL** (`/payments/ledger`, `/violations/appeals`) so back button,
bookmarks and links from the dashboard all work. Old routes (`/payment-log`,
`/visitor-cards`, `/site-server`) redirect to the new tab.

### 2.4 Navigation shell — the biggest decision to discuss

**Recommendation: a grouped left sidebar at ≥1024px**, collapsible to a 72px icon
rail, with a slim top bar for search / bell / account.

| | Top pills + sub-tabs (today) | Left sidebar (proposed) |
|---|---|---|
| Height used before the page starts | ~108px (60 bar + ~48 sub-nav) | 56px |
| Clicks to reach a page in another group | 2 | 1 |
| Badges visible | Only for the open group's pages | All at once |
| Room to grow | Each new page widens a row | Each new page adds one line |

On a 1366×768 laptop, 108px is 14% of the screen spent on navigation before a table
even starts. Tables are what admins look at most.

**Decided: sidebar.** The top nav was chosen to look different from other
groups' panels. That goal is right, but nav position is the wrong place to spend
it — it costs space and hides pages (see screenshot findings). Be unique where it
also helps the user:

1. **A "live" sidebar.** Deep indigo sidebar with a **gate pulse** pinned at the
   bottom: Gate 1 / Gate 2 status dots, free bays "18 / 18", visitors on site.
   Every other admin panel's sidebar is a list of links; ours shows the lot is
   alive from every page.
2. **The parking map as the signature.** Use its visual language (dark gate
   blocks, mono labels, bay tiles) in small places: Gate Check result card,
   slot side panel, the login brand panel.
3. **Instrument-style labels.** Keep Plex Mono for data labels and readings
   ("LIVE · JUST NOW", "FREE NOW") — it reads like a control panel. Just stop using
   it for sentences.
4. **Guard station mode.** A full-screen Gate Check with big type — no other
   panel will have a mode built for the person at the gate.
5. **Warm cream + indigo**, not the default grey + blue every template ships with.

---

## 3. Admin workflows

### 3.1 Action classes (applies everywhere)

| Class | Looks like | Where | Example |
|---|---|---|---|
| **Primary** | Filled indigo button. One per view. | Page header, right. Or sticky decision bar. | Approve, Issue violation, Create backup |
| **Secondary** | Outlined or text button | Next to primary, left of it | Ask to retake, Export, Log exit |
| **Row action** | One small outlined button per row, max | Last column | View, Mark paid, Mark returned |
| **More (⋯)** | Overflow menu | Header or row end | Edit, Copy ID, Download, Rotate key |
| **Destructive** | Red text in a menu, or red outlined button set apart. Always confirms. | Bottom of the ⋯ menu, or a "Danger zone" card | Archive user, Revoke card, Restore database, Remove device |
| **Immediately accessible** | Always visible, no menu | Header / top bar | Search, the page's main action, the queue badge |

**Rule:** a destructive action is never the closest button to a safe one.

**Confirm levels** (one `ConfirmDialog` component, three strengths):

| Level | When | How |
|---|---|---|
| 1 — Simple | Undoable, small | "Mark as paid?" → Cancel / Mark paid |
| 2 — Reason | Affects a person | Suspend, Reject, Revoke → reason field required |
| 3 — Type to confirm | Cannot be undone, affects everything | Restore database → type `RESTORE` |

### 3.2 Workflow by workflow

**Reviewing pending applications** (most frequent admin job)
- Queue sorted **oldest first** by default; "Waiting" column shows age, turns amber after 24h, red after 72h.
- Open one → review page: documents on the left, extracted values + checks on the right, so the eye goes picture → value → picture.
- **Sticky decision bar** at the bottom: `Reject` (red, far left) · `Ask to retake` · **`Approve`** (primary, far right).
- After a decision the next application opens automatically. Header shows "3 of 12". A "Back to queue" link is always there.
- Optional keyboard: `J`/`K` next/previous, `A` approve (still confirms).
- Primary: Approve. Secondary: Ask to retake. Destructive: Reject (reason required).

**Managing users**
- Search first: the search box is the biggest control. Searches name, email, student no., plate, RFID tag.
- No inline Suspend/Archive buttons. Row click opens the user. Row has one ⋯ menu.
- User page header: status pill + primary action that depends on state (Suspended → **Unsuspend**; Active → nothing primary, Suspend under ⋯). Archive is last in ⋯, red, Level 2 confirm.
- **Bulk revoke RFID** becomes table selection: tick rows → a bulk bar appears ("4 selected · Revoke RFID · Clear"). No separate picker dialog.

**Managing RFID cards**
- Enrollment happens on the user page: **Link card** → scan with reader (`RfidScanField`) → confirm.
- RFID cards page answers two questions: "which cards are waiting to be reissued?" and "who owns tag X?"
- Revoke is destructive (Level 2, reason). Reissue is primary on the "Awaiting reissue" tab.

**Monitoring parking**
- Live map is the page. Free/occupied counts in the header.
- Admin: **Log entry** / **Log exit** as secondary buttons (manual fallback, not the normal path).
- Slot setup (Add slot, change status) moves into a **Manage slots** mode behind ⋯. It is configuration, done rarely.

**Handling violations**
- List defaults to "Open" status. Columns trimmed to what decides action (see §9).
- Row click opens a **side panel** with a timeline: issued → appeal filed → decision → paid. Actions in the panel follow the state.
- **Appeals tab** with badge: the queue of decisions owed. Decide `Uphold` / `Dismiss` with a reason.
- Primary: Issue violation. Destructive: Void violation (Level 2).

**Managing payments**
- Charges tab defaults to **Outstanding**. Mark paid is a row action, Level 1 confirm, asks for method + reference.
- Ledger tab: date range + filters + **Export CSV** as primary.
- Rates tab: a small table you edit in place, not a dialog.

**Managing visitor passes** (guard)
- Default view "On site now", overdue rows highlighted amber with "3h 20m over".
- **Issue a card** is primary. `Mark returned` is the row action.
- Card stock tab: available / lent / blocked counts on top. Block/Remove under ⋯.

**Monitoring gates**
- Devices → Health tab: one row per device, green/amber/red dot + "last seen 12s ago". Problems sorted to the top.
- **Open gate manually** is a safety action: always visible on the guard screens, but press-and-hold (1s) or confirm, and it logs who did it.

**Viewing reports**
- Pick range (Today / 7d / 30d / Custom) → metric strip → charts → tables. **Export** is the primary button.
- Every chart has a one-line plain summary under its title ("Busiest hour: 7–8 AM").

**Backup / restore**
- **Create backup** is primary. History below with Download.
- Restore lives in a separate **Danger zone** card at the bottom, red outline, Level 3 confirm. Already close to this today.

**System administration**
- Devices: Register device (primary). Copy key (secondary). **Rotate key** and **Remove** are destructive under ⋯ — rotating breaks the device until it is updated, so the dialog says so.

---

## 4. Layout system

### 4.1 Page anatomy

```
┌───────────────────────────────────────────────────────────────────────┐
│ ← Back to queue                                (only on detail pages) │
│ Page title                     [spec tag]      [Secondary] [Primary ▣]│
│ One-line description                                                  │
├───────────────────────────────────────────────────────────────────────┤
│ Tab · Tab · Tab                                       (if siblings)   │
├───────────────────────────────────────────────────────────────────────┤
│ [Status: Open ▾] [Rule: All ▾]          [🔍 Search      ]  [⋯]        │
│ Status: Open ×   Clear all                         124 results        │
├───────────────────────────────────────────────────────────────────────┤
│ TABLE / CONTENT                                                       │
│                                                                       │
├───────────────────────────────────────────────────────────────────────┤
│ 1–25 of 124                                       ‹ 1 2 3 4 5 ›       │
└───────────────────────────────────────────────────────────────────────┘
```

| Slot | Rule |
|---|---|
| **Header** | Title (one per page), optional description (one line, says what the page is *for*), actions on the right. Max 1 primary + 2 secondary; the rest go in ⋯. |
| **Tabs** | Only for sibling views of the same data. Show counts on tabs that are queues ("Appeals 3"). |
| **Filters** | Left of the toolbar. Pill style that tints when active (keep `AppFilterDropdown`). |
| **Active-filter chips** | New. A row under the toolbar listing active filters with × and "Clear all", plus result count. Answers "why is this empty?" |
| **Search** | Right of the toolbar (current choice, keep). Says what it searches: "Search name, plate, tag". |
| **Table actions** | Refresh / Export / column options in the toolbar ⋯, not in the page header. |
| **Content** | Table, card grid, or map. Fills the height; the table scrolls inside its card. |
| **Pagination** | Footer of the table card. "1–25 of 124" + pages + page size. |

### 4.2 Five page templates

| Template | Used by | Shape |
|---|---|---|
| **List** | Users, Registrations, Violations, Payments, Visitors, RFID cards, Logs, Devices | Anatomy above |
| **Detail** | User, Registration review | Back link, header with status + actions, two columns (main + side facts), history at the bottom |
| **Dashboard** | Overview (admin, guard), Reports | Metric strip → attention → live → charts |
| **Station** | Gate Check, Gate readers | One big input, one big answer, two big buttons. Post density. |
| **Settings / form** | Policy rules, Rates, Backup, Announcements | Cards with a form column max 560px |

### 4.3 Overlays — one rule each

| Overlay | Use for | Size |
|---|---|---|
| **Side panel** (slides from right) | Quick look + small actions on one row without losing the list: violation, payment receipt, incident, visitor, device | 480px; full screen under 768 |
| **Full page** | Deep work: registration review, user | — |
| **Dialog** | Confirmations and short forms (≤5 fields) | 400 / 560 / 720 |
| **Toast** | "Saved", "Payment marked as paid · Undo" | Bottom, 4s, never for errors that need action |
| **Banner** | Page- or app-level state: site update, offline, lost contact with server | Top of content |

### 4.4 States

| State | Treatment |
|---|---|
| **Loading** | Shape-matched skeleton (already the rule). |
| **First use** | Icon + "No policy rules yet" + one sentence + primary action. |
| **No results** | "No users match 'reyes'" + **Clear filters** button. |
| **All done** | Positive: "Nothing waiting. 0 applications in the queue." Green check, no button. |
| **Error** | What failed + **Try again** + small "Reference: `traceId`" with copy. The API already returns a traceId on 500s — showing it lets you find the error in Logs instead of guessing it was CORS. |
| **No permission** | "Security accounts can't see appeals." Not a blank page. |

---

## 5. Responsive design

Breakpoints change from **600 / 900** to **600 / 768 / 1024 / 1440**.

| | **≥1440 desktop** | **1024 laptop** | **768 tablet** | **600 compact** | **390 phone** |
|---|---|---|---|---|---|
| **Nav** | Sidebar 248px, labels | Sidebar collapses to 72px icon rail (hover/expand for labels) | Rail 72px | Top app bar + drawer | Admin: app bar + drawer. **Guard: bottom nav** (Gate Check · Visitors · Parking · Incidents · More) |
| **Top bar** | Search box 360px, bell, account | Search box 280px | Search icon → opens full-width | Search icon | Search icon |
| **Header** | Title + description left, actions right | Same | Description hides if over 1 line | Actions: primary stays, others into ⋯ | Title only; primary becomes a bottom-right button (FAB) on list pages |
| **Filters** | Inline pills | Inline pills | Inline; extra filters into "More filters" | One **Filters** button → bottom sheet, with a count ("Filters · 2") | Same as 600 |
| **Tables** | All columns | Low-priority columns hide (each column has a priority 1–3) | Priority 1–2 only | **Turn into cards**: title line, status pill, 2–3 key facts, row action | Cards, one per row, full width |
| **Detail page** | Two columns (main + facts) | Two columns | One column, facts on top | One column | One column; actions in a sticky bottom bar |
| **Side panel** | 480px over the list | 480px | 480px | Full screen | Full screen |
| **Dialogs** | Fixed widths | Same | Same | Full width minus 16 | Forms become full-screen; confirms stay small |
| **Dashboard** | 4 metrics in a row, 2-column cards | 4 metrics, 2-col | 2×2 metrics, 1-col cards | 2×2 metrics, 1-col | Metrics as a 2-col grid, attention list first, charts last |
| **Reg. review** | Documents left, values right | Same | Tabs: Documents / Details | Tabs | Tabs + sticky decision bar |
| **Live map** | Map + side list | Map + list below | Map, list below | List first, map toggle | **List first** ("12 free · 48 taken"), map behind a toggle |
| **Touch targets** | 32px row buttons OK (mouse) | 32px | **44px** | 44px | 48px on guard screens |

Main structural changes, not just shrinking:
- **Tables become cards under 768.** Sideways scrolling a 9-column violation table on a phone is not usable.
- **Filters become a sheet under 768.**
- **Guard on a phone gets a bottom nav** of their 4 jobs. Admin on a phone gets a drawer and is expected to do triage only (approve a registration, look someone up, check alerts).
- **Reading order flips on phone dashboards**: "needs attention" first, charts last.

---

## 6. Component system

✓ = exists today, keep · ~ = exists, extend · + = new

```
shell/
  AdminShell            ~  picks layout by breakpoint and role
  NavSidebar            +  grouped, collapsible, badges (or keep top pills, see §2.4)
  NavDrawer             ~  (today _DrawerNav)
  GuardBottomNav        +  phone, Security role
  TopBar                ~  search · bell · account
  GlobalSearch          +  Ctrl+K: people, plates, tags, payments, violations
  NotificationBell      ✓
  AccountMenu           ✓  (today _AccountChip)
  SiteUpdateBanner      ✓

page/
  AppPage               ✓  add `tabs`, `specTag`, `template`
  PageHeader            ✓  (AppPageHeader) add overflow ⋯ rules per breakpoint
  PageTabs              +  URL-synced tabs with counts
  AppToolbar            ✓
  AppSearchField        ✓  add hint "Search name, plate, tag"
  AppFilterDropdown     ✓
  ActiveFilterChips     +  chips + Clear all + result count
  FilterSheet           +  bottom sheet under 768

data/
  AppDataView           +  wraps AppDataTable; column priority; card mode under 768
  AppDataTable          ✓
  ColumnDef             +  label, priority, numeric, sortable, cell builder, card role
  RowActions            +  one visible action + ⋯ menu; destructive last + red
  BulkActionBar         +  appears when rows are selected
  AppPagination         ~  add "1–25 of N" and page size
  StatusPill            ✓
  AppPrimaryCell        ✓
  AppNumericCell        ✓
  MonoValue             +  plate / tag / reference, copy on click
  RelativeTime          +  "12 min ago", exact time in tooltip

feedback/
  AsyncView             ✓
  Skeleton*             ✓
  EmptyState            ~  variants: firstUse, noResults, allDone, noPermission
  ErrorState            +  message + retry + traceId copy
  AppBanner             +  (several screens have a private _Banner today)
  AppToast              +  success/info with optional Undo

overlays/
  ConfirmDialog         +  levels 1–3 (replaces ~30 hand-written confirms)
  FormDialog            +  title, fields, validation, submit/cancel
  SidePanel             +  480px slide-over, full-screen on phone
  ActionMenu            +  the ⋯ menu, consistent order and icons

display/
  AppCard / SectionCard ✓
  MetricCard            ✓
  KeyValueList          +  label/value pairs (receipt rows, personal info)
  Timeline              +  violation / registration / user history
  DangerZone            +  red-outlined card for destructive settings
  AppChart, Gauge, …    ✓

domain/ (screen-specific, but shared between screens)
  UserPicker            ✓
  RfidScanField         ✓
  LiveParkingMap        ✓
  GateStatus            ✓
  DeviceHealthList      ✓
  DocumentViewer        ✓
  ChecksPanel           ✓
  DecisionBar           +  sticky Approve / Retake / Reject (registrations, appeals)
  ViolationPanel        ~  (today the 800-line violation dialog, becomes a SidePanel)
```

**Shared across almost every page:** AppPage, PageHeader, PageTabs, AppToolbar,
filters, AppDataView, RowActions, StatusPill, EmptyState, ErrorState,
ConfirmDialog, SidePanel, AppPagination.

The biggest wins are **AppDataView** (fixes phones on 12 list pages at once),
**ConfirmDialog** (makes every dangerous action behave the same) and **RowActions**
(fixes the loud rows).

---

## 7. Design tokens

Keep the 3-layer system and almost every value. Changes are marked **→**.

### Colour

| Token | Light | Dark | Note |
|---|---|---|---|
| surface.canvas / card / muted | neutral50 / white / neutral100 | neutral950 / 900 / 800 | Keep |
| brand.primary / hover / pressed | brand500 / 600 / 700 | brand400 / 300 / 500 | Keep |
| text.primary | neutral900 | neutral50 | Keep |
| text.secondary | neutral500 **→ neutral600** | neutral400 **→ neutral300** | Today ~4.6:1 on canvas — passes, barely. One step darker gives room. |
| text.tertiary | neutral400 **→ neutral500** | neutral500 **→ neutral400** | **Today ~2.6:1 on canvas (light) and ~4:1 (dark) — fails WCAG AA for text.** Used for eyebrows and placeholders. |
| border.focus | brand500 | brand400 | Keep |
| status.* (bg/fg/border/solid) | as today | as today | Keep — the pairing system is excellent |
| chart.categorical | as today | as today | Keep |

### Typography

| Role | Face | Size / weight | Change |
|---|---|---|---|
| Big numbers | Inter Display | 32 / 800 | Keep |
| Page title | Inter Display | 22 / 700 | Keep |
| Dialog / panel title | Inter Display | 18 / 600 | Keep |
| Section title | Inter | 16 / 600 | Keep |
| Body | Inter | 14 / 400 | Keep |
| Small / helper / caption | **Plex Mono → Inter** | 12 / 400 | Mono only where it helps |
| Column headers | **Plex Mono → Inter**, 12 / 600, secondary colour | | Optional — keeps mono for *values*, not labels |
| Status pill | Plex Mono 11–12 / 600 | | Keep (it's a label, short, fine) |
| **mono** (new named style) | Plex Mono 13 / 500, tabular | | Plates, tags, references, table times |
| Post density body | Inter 16 | | Guard screens |

### Spacing, radius, elevation, sizes

| Token | Value | Change |
|---|---|---|
| Spacing grid | 4px steps; page 24, card 16, gutter 12, section 24 | Keep. Add `groupGap` = 32 for dashboard groups |
| Radius sm / md / lg / xl | 12 / 18 / 24 / 28 | **→ 8 / 10 / 16 / 20** (optional, see §11) |
| Elevation sm / md / lg | flat / menus / dialogs | Keep |
| Control height sm / md / **lg** | 32 / 40 / **+48** | Add lg for post density and touch |
| Table row | 44 (office) / **+52** (touch) | Touch row under 1024 |
| Top bar | 60 **→ 56** | |
| Sidebar | 248 / 72 | Reuse existing tokens |
| Side panel | **+480** | |
| Form max width | 560 | Keep |
| Touch target min | **44** (48 on guard screens) | New |
| Breakpoints | 600 / 900 **→ 600 / 768 / 1024 / 1440** | |

### Interaction states

| State | Rule |
|---|---|
| **Hover** | Rows: `surface.hover`. Buttons: one step darker (`brand.hover`). Cursor: pointer on anything clickable — including whole rows. |
| **Focus (keyboard)** | 2px `border.focus` ring with 2px gap, on every interactive thing. Shown for keyboard focus only, never removed. |
| **Pressed** | `brand.pressed`; no ripple on desktop (feels like mobile). |
| **Selected** | `surface.selected` + 3px brand bar on the left of rows/nav items. |
| **Disabled** | `text.disabled`, no tint, no hover. **Always with a tooltip saying why** ("Only admins can broadcast"). Hide instead of disable when the role can never use it (already the rule — keep). |
| **Error** | Field: `status.danger.border` outline + icon + message under the field in `danger.fg`. Page: ErrorState. |
| **Success** | Toast with `status.success`; inline green check for completed steps. |
| **Warning** | Amber banner or pill. Used for "waiting too long", "device last seen 5 min ago". |

---

## 8. Accessibility

Flutter web needs a little extra effort here, because screen readers only see
what the semantics tree exposes.

**Keyboard**
- Tab order follows the visual order: nav → header actions → filters → search → table → pagination.
- "Skip to content" as the first focusable item.
- Rows focusable; `Enter` opens, `Space` selects (in bulk mode), arrow keys move between rows.
- `Esc` closes side panels, sheets and dialogs and returns focus to what opened them.
- `Ctrl+K` search, `?` shows the shortcut list. Shortcuts never fire while typing in a field.

**Focus states**
- Visible 2px ring everywhere (§7). Check custom widgets that use `GestureDetector`/`MouseRegion` instead of buttons — they often get no focus at all. `_GroupPill`, `_SubTab`, `_AttentionRow` and `_ModuleTile` are candidates **(check on screen)**.

**Screen readers**
- Every icon-only button has a tooltip (most do already) — that also gives it a label.
- Status pills read as "Status: Suspended", not just "Suspended".
- Charts get a text summary and a "View as table" toggle.
- Live parking map has a list alternative (needed for phones anyway).
- Toasts and "approved, next application loaded" are announced politely.
- Badges read as "Registrations, 4 waiting".

**Contrast**
- Fix `text.tertiary` (fails today, §7).
- Never colour alone: every status has a word; every red row also has an icon or label.

**Touch targets**
- 44px minimum under 1024, 48px on guard screens. Desktop row buttons can stay 32px.

**Semantic controls**
- Use real buttons, checkboxes, tabs and menus rather than styled containers, so keyboard and reader support come for free.

**Forms**
- Label above every field, always visible (no placeholder-only fields).
- Required fields say "Required" in text, not just `*`.
- Validate on blur and on submit; on submit, move focus to the first error and show a short summary at the top if there are several.
- Error text says how to fix it: "Plate must look like ABC 1234", not "Invalid input".

**Motion**
- Respect reduced-motion: no slide animations, instant panel open.

---

## 9. Screen-by-screen

### Login
- **Primary user goal:** Get in quickly.
- **Recommended layout:** Keep the split brand panel + form. Form is a single column, max 400px.
- **Primary action:** Sign in.
- **Secondary actions:** Forgot password (when it exists), theme.
- **Filters/search:** —
- **Main content:** Email, password (show/hide), sign-in.
- **Empty state:** —
- **Important interactions:** Enter submits; error under the form says what went wrong ("Wrong email or password", "This account can't use the admin panel"); caps-lock hint.
- **Responsive behavior:** Brand panel hides under 768; form full width with 16px gutter.
- **Changes from current design:** Essentially unchanged. Check error wording and focus order.
- **Reasoning:** It works and it is the first impression for the panel. Not worth risk.

### Overview (Admin)
- **Primary user goal:** "Is anything wrong, and what do I need to do today?"
- **Recommended layout:** 1) Metric strip (4): Occupancy now, Entries today, Waiting for me (registrations + appeals + incidents), Outstanding payments. 2) **Needs attention** list (full width, top). 3) Live parking (compact) + gate status side by side. 4) Active sessions. 5) Module shortcuts (keep, last — useful for the capstone demo).
- **Primary action:** None. The attention list *is* the action.
- **Secondary actions:** Refresh (auto every 30s with a "updated 10s ago" label).
- **Filters/search:** None. **Remove** the range pills and Export.
- **Main content:** Today, live.
- **Empty state:** Attention list "All clear" with green check.
- **Important interactions:** Each attention row deep-links to the filtered list (e.g. Registrations sorted by oldest).
- **Responsive behavior:** 2×2 metrics under 1024; attention first on phone; charts dropped below 600.
- **Changes from current design:** Range pills + Export + Sessions-vs-revenue chart + peak hours move to Reports. Attention moves from the bottom to the top.
- **Reasoning:** One question per page. Trends are "the past"; the overview is "now". Today the most actionable card (Attention) is the last thing you reach.

### Overview (Security)
- **Primary user goal:** "Are the gates working, and who is on site?"
- **Recommended layout:** Gate status (both gates, big), device health, visitors on site (count + overdue), live parking counts, recent gate events.
- **Primary action:** Go to Gate Check (large button).
- **Secondary actions:** Report an incident.
- **Filters/search:** —
- **Main content:** Live status.
- **Empty state:** "No visitors on site."
- **Important interactions:** Device problem row → Devices › Health.
- **Responsive behavior:** Phone: stacked, gate status first; bottom nav.
- **Changes from current design:** Small. Promote Gate Check button; move device detail list to Devices.
- **Reasoning:** Already a separate, role-appropriate screen. Good call; keep the idea.

### Gate Check (Security) — spec: Entry/Exit Verification
- **Primary user goal:** Tap/type a card, see who it is and whether the car matches, log in or out.
- **Recommended layout:** **Station template.** One huge input at the top (auto-focused, reader input goes straight in). Result card: photo/name, plate on file in big mono, status pill (Allowed / Suspended / Revoked) in large size. Two large buttons.
- **Primary action:** `Log entry` or `Log exit` — whichever matches the session state is filled; the other is outlined.
- **Secondary actions:** Report incident (pre-filled with this card), Clear.
- **Filters/search:** The lookup field itself.
- **Main content:** One result.
- **Empty state:** "Tap a card or type a tag / plate." with a reader icon.
- **Important interactions:** Blocked cards show a red full-width banner with the reason. After logging, the field clears and refocuses. Sound cue already exists — keep.
- **Responsive behavior:** Same on phone, buttons full width, 56px.
- **Changes from current design:** Post density (bigger text/buttons); plate in mono; state-aware primary button.
- **Reasoning:** A guard is standing with a car waiting. One glance, one tap.

### Live parking (was Parking)
- **Primary user goal:** See occupancy now; occasionally log by hand.
- **Recommended layout:** Header with counts (free / taken / reserved). Map + slot list.
- **Primary action:** None by default (it's monitoring). For admin, `Log entry` and `Log exit` as secondary.
- **Secondary actions:** ⋯ → Manage slots (enter edit mode: add slot, change status).
- **Filters/search:** Zone/gate filter, search slot or plate.
- **Main content:** Map; clicking a slot opens a side panel (who, since when, session).
- **Empty state:** "No slots set up yet" → Manage slots.
- **Important interactions:** Live updates; slot side panel.
- **Responsive behavior:** List first on phone, map behind a toggle.
- **Changes from current design:** `Add Slot` filled button → into Manage slots mode. Slot click → side panel.
- **Reasoning:** Today the only filled button is "Add Slot", a rare config job, so it looks like the main thing to do.

### Gate activity (new: from System Logs › RFID Access + Gate taps)
- **Primary user goal:** "What happened at the gate?" — find a tap, entry or denial.
- **Recommended layout:** List template. One timeline-style table: time, gate, event (entry / exit / denied), who, plate seen vs plate on file, reason.
- **Primary action:** Export CSV.
- **Secondary actions:** Refresh / live toggle.
- **Filters/search:** Gate, event type, date range; search name / plate / tag.
- **Main content:** Events, newest first.
- **Empty state:** "No gate activity in this range."
- **Important interactions:** Row → side panel with camera snapshot (if any) and links to the user and session. Plate mismatch rows amber.
- **Responsive behavior:** Cards under 768.
- **Changes from current design:** Two log tabs become one page under Gates; guards see it without going into "System".
- **Reasoning:** These are operational events. Guards and admins look here after something odd happens at the gate.

### Visitors — tab "On site" (was Visitor Passes) — spec: Visitor RFID Access
- **Primary user goal:** Lend a card, see who still has one, take it back.
- **Recommended layout:** List template. Small strip: On site · Overdue · Cards free.
- **Primary action:** Issue a card.
- **Secondary actions:** Export.
- **Filters/search:** Status (On site / Returned / Overdue), date; search visitor name / plate / card label.
- **Main content:** Visitor, card, plate, since, time left/over.
- **Empty state:** "No visitors on site." (all-done style)
- **Important interactions:** Row action `Mark returned`. Overdue rows amber with "2h over".
- **Responsive behavior:** Cards; FAB for Issue on phone.
- **Changes from current design:** Merged with card stock; overdue made visible.
- **Reasoning:** Lending and stock are one job at the guard post.

### Visitors — tab "Card stock" (was Visitor Cards)
- **Primary user goal:** Keep the card pool in order.
- **Recommended layout:** Counts (free / lent / blocked) + table.
- **Primary action:** Add visitor card (admin).
- **Secondary actions:** —
- **Filters/search:** State; search label / tag.
- **Main content:** Label, tag (mono), where, last visitor.
- **Empty state:** First use: "No visitor cards yet. Add the cards kept at the guard post."
- **Important interactions:** ⋯ → Block / Unblock, Remove (red, confirm). Today Block/Unblock/Remove are all inline buttons.
- **Responsive behavior:** Cards under 768.
- **Changes from current design:** Moves from System to Visitors; inline actions into ⋯.
- **Reasoning:** Removes a cross-group hop; quiets the rows.

### Devices — tabs Gate devices · Site server · Health (· Readers on this PC, Security)
- **Primary user goal:** Register hardware, keep it connected, fix it when it drops.
- **Recommended layout:** List template per tab. Health tab: problems first.
- **Primary action:** Register device / Register site server.
- **Secondary actions:** —
- **Filters/search:** Gate, type, status.
- **Main content:** Name, gate, type, status dot + last seen, key (masked, copy).
- **Empty state:** First use with a link to the setup guide.
- **Important interactions:** ⋯ → Copy key, Rotate key (destructive: "the device stops working until updated"), Remove (red, Level 2).
- **Responsive behavior:** Cards.
- **Changes from current design:** Devices, Site Server and health become one page with tabs. Gate Readers becomes the "Readers on this PC" tab for Security (station-ish layout: ports, hub, recent taps).
- **Reasoning:** Same kind of object, same people, same tasks. Site Server is already the same screen with a flag.

### Registrations (was Pending Registrations)
- **Primary user goal:** Clear the queue accurately.
- **Recommended layout:** List template, queue style. Sorted oldest first.
- **Primary action:** `Start reviewing` (opens the oldest).
- **Secondary actions:** —
- **Filters/search:** Checks result (All pass / Needs attention), affiliation; search name / email.
- **Main content:** Name, checks summary (✓ 5/6 with the failing one named), submitted, waiting (colour by age).
- **Empty state:** All-done: "Nothing waiting."
- **Important interactions:** Row → review page in queue mode ("3 of 12").
- **Responsive behavior:** Cards; tap to review.
- **Changes from current design:** Default sort by age; "Start reviewing"; ageing colours; title matches nav.
- **Reasoning:** This is a queue; design it as one.

### Registration review (detail)
- **Primary user goal:** Decide correctly in under a minute.
- **Recommended layout:** Detail template. Left: documents (RAF, licence, OR) with zoom. Right: extracted values next to account values, checks panel, history at the bottom. **Sticky decision bar** at the bottom.
- **Primary action:** Approve.
- **Secondary actions:** Ask to retake (choose document + reason).
- **Filters/search:** —
- **Main content:** Evidence vs claims.
- **Empty state:** "This application was already decided by X at 10:42" if opened late.
- **Important interactions:** After a decision → next application automatically, with toast "Approved Juan Dela Cruz · Undo (5s)". Reject = red, far left, reason required.
- **Responsive behavior:** Tabs (Documents / Details) under 1024; decision bar stays.
- **Changes from current design:** Actions move from header to sticky bar; Reject separated from Approve; auto-advance; documents beside values.
- **Reasoning:** Today Approve, Ask to retake and Reject sit side by side in the header — the most dangerous action next to the most common one, and the decision scrolls away while you look at documents.

### Users (was User Management) — spec: Manage Users
- **Primary user goal:** Find a person and change their access.
- **Recommended layout:** List template; big search.
- **Primary action:** None (users self-register). Search is the main control.
- **Secondary actions:** Export.
- **Filters/search:** Status, RFID status, affiliation; search name / email / student no. / plate / tag.
- **Main content:** Name + email (one cell), status, RFID, vehicles count, joined.
- **Empty state:** No results → Clear filters.
- **Important interactions:** Row → user page. Checkbox selection → BulkActionBar (Revoke RFID). Row ⋯ → Suspend / Unsuspend, Archive (red).
- **Responsive behavior:** Cards; selection mode via long-press on touch.
- **Changes from current design:** Inline Suspend/Unsuspend/Restore/Archive buttons → ⋯; Bulk Revoke becomes selection instead of a header button + picker dialog.
- **Reasoning:** Four colourful buttons per row make the table hard to scan and put Archive one click from a mis-click.

### User (detail)
- **Primary user goal:** See everything about one person, act on their account or card.
- **Recommended layout:** Detail template. Header: name, status pill, primary state action. Main: Vehicles, RFID card (with Link / Revoke), Violations summary, Payments summary. Side: personal info. Bottom: history timeline.
- **Primary action:** Depends on state: Suspended → Unsuspend; Archived → Restore; no card → Link card; otherwise none.
- **Secondary actions:** Issue violation (pre-filled), View payments.
- **Filters/search:** —
- **Main content:** Account at a glance.
- **Empty state:** Sections say "No vehicles", "No violations".
- **Important interactions:** ⋯ → Suspend, Delete document images (red, Level 2), Archive (red, Level 2).
- **Responsive behavior:** One column; actions in a sticky bottom bar on phone.
- **Changes from current design:** One state-aware primary instead of several buttons; destructive into ⋯; links to the person's violations and payments.
- **Reasoning:** The user page should be the hub for "everything about this person".

### RFID cards
- **Primary user goal:** Reissue revoked cards; find who owns a tag.
- **Recommended layout:** Tabs: Awaiting reissue · All cards.
- **Primary action:** On Awaiting reissue: row action `Reissue`.
- **Secondary actions:** Export.
- **Filters/search:** State, reason; search tag / owner.
- **Main content:** Tag (mono, copy), state, reason, holder, date.
- **Empty state:** All-done: "No cards waiting to be reissued."
- **Important interactions:** Row → owner's user page.
- **Responsive behavior:** Cards.
- **Changes from current design:** Adds "All cards" lookup; moves into People.
- **Reasoning:** Today the page only lists revoked cards, which surprises people expecting a card registry.

### Violations — spec: Violation Tracking
- **Primary user goal:** Issue, follow and close violations.
- **Recommended layout:** List template with tabs All · Appeals (badge).
- **Primary action:** Issue violation.
- **Secondary actions:** Export.
- **Filters/search:** Status (default Open), rule, date; search name / plate / student no.
- **Main content:** Person (name + student no.), rule, status, penalty, issued, appeal deadline. **Trim from 9 columns to 6**; RFID and suspension type move into the side panel (priority-3 columns on wide screens).
- **Empty state:** No results → Clear filters. First use → "No violations recorded."
- **Important interactions:** Row → **side panel** with timeline and state-aware actions (Void, Record payment). Appeals tab → decide Uphold / Dismiss with reason.
- **Responsive behavior:** Cards; side panel full-screen.
- **Changes from current design:** Detail dialog → side panel; Appeals move here from Incidents; fewer columns.
- **Reasoning:** Keeping the list visible while reading one case is faster; deciding appeals next to the violation is safer.

### Incidents — spec: Incidents & Appeals
- **Primary user goal:** Record what happened on the ground and follow it up.
- **Recommended layout:** List template.
- **Primary action:** Report an incident.
- **Secondary actions:** —
- **Filters/search:** Status (default Open), category; search.
- **Main content:** Category, summary, status, reported by, when.
- **Empty state:** All-done: "No open incidents."
- **Important interactions:** Row → side panel with attachments and status changes; "Turn into violation" when a person is identified.
- **Responsive behavior:** Cards; FAB on phone for guards.
- **Changes from current design:** Appeals tab moves to Violations. Keep the spec tag "Incidents & Appeals" so the panel can trace it, with a link "Appeals are under Violations".
- **Reasoning:** Incidents and appeals are different jobs for different people (guards vs admins).

### Policy rules — spec: Policy & Rule Management
- **Primary user goal:** Set the rules and penalties the system applies.
- **Recommended layout:** Settings template: a table of rules (name, penalty, suspension default, active).
- **Primary action:** Add rule.
- **Secondary actions:** —
- **Filters/search:** Active/inactive (only if the list grows).
- **Main content:** Rules.
- **Empty state:** First use with Add rule (exists today — keep).
- **Important interactions:** Row → edit side panel. Deactivate rather than delete when a rule has violations attached (⋯, confirm).
- **Responsive behavior:** Cards.
- **Changes from current design:** Title becomes "Policy rules" to match nav; edit in a side panel.
- **Reasoning:** Mostly fine today. Small consistency fixes.

### Payments — tabs Charges · Ledger · Rates — spec: Payment Monitoring
- **Primary user goal:** Know what is owed and what was paid; settle by hand when needed.
- **Recommended layout:** Metric strip (Outstanding total, Collected today, Collected this month) + tabs.
- **Primary action:** Charges: none (row actions). Ledger: Export CSV. Rates: Add rate.
- **Secondary actions:** —
- **Filters/search:** Status (default Outstanding), source, date range; search name / plate / reference.
- **Main content:** Charges: who, source, amount, status, created. Ledger: itemized with method + reference.
- **Empty state:** Charges all-done: "Nothing outstanding."
- **Important interactions:** Row → receipt side panel (today a dialog). `Mark paid` → small form (method, reference), Level 1 confirm, toast with Undo.
- **Responsive behavior:** Cards; amounts right-aligned and tabular everywhere.
- **Changes from current design:** Payments + Payment Log + Manage Rates dialog become one page.
- **Reasoning:** Same data and same person, three places today.

### Reports — spec: Reports & Monitoring
- **Primary user goal:** Understand trends; produce a report for someone else.
- **Recommended layout:** Dashboard template: range picker → metric strip → charts in sections (Usage, Revenue, Enforcement) → top lists.
- **Primary action:** Export (CSV now; PDF later if needed for the school).
- **Secondary actions:** Range: Today / 7d / 30d / Custom.
- **Filters/search:** Range, gate.
- **Main content:** Charts with plain one-line summaries; receives the trend charts removed from Overview.
- **Empty state:** "No data in this range."
- **Important interactions:** Chart hover shows exact values; "View as table" toggle.
- **Responsive behavior:** One chart per row under 1024; metrics 2×2.
- **Changes from current design:** Gains Overview's trend charts; sections with headings.
- **Reasoning:** One home for "the past".

### Announcements (was Notifications › Sent + Broadcast) — spec: Notifications Management
- **Primary user goal:** Tell users something.
- **Recommended layout:** List of sent announcements + composer.
- **Primary action:** New announcement.
- **Secondary actions:** —
- **Filters/search:** Audience, date.
- **Main content:** Title, audience, sent, read count.
- **Empty state:** First use with New announcement (exists today).
- **Important interactions:** Composer shows a preview of the phone notification and the audience size before sending; Level 1 confirm ("Send to 412 users?").
- **Responsive behavior:** Composer full-screen on phone.
- **Changes from current design:** Inbox moves to the bell; sending gets its own page in System.
- **Reasoning:** Receiving ≠ sending.

### Notification inbox (bell)
- **Primary user goal:** See what needs me.
- **Recommended layout:** Bell → popover with the latest 10 + "View all" → full inbox page (no nav entry).
- **Primary action:** Mark all read.
- **Secondary actions:** —
- **Filters/search:** Unread / all, type.
- **Main content:** Notifications that link to their item.
- **Empty state:** "You're all caught up."
- **Important interactions:** Click → goes to the item and marks read.
- **Responsive behavior:** Full screen on phone.
- **Changes from current design:** Removed from nav; popover added.
- **Reasoning:** The bell already exists; two entries for one inbox is confusing.

### Logs (was System Logs) — spec: Access Monitoring / audit
- **Primary user goal:** Find out who changed what, or why something failed.
- **Recommended layout:** Tabs: Admin actions · User activity · System errors.
- **Primary action:** Export CSV.
- **Secondary actions:** —
- **Filters/search:** Action, actor, date; System errors: **search by traceId**.
- **Main content:** Who, what, target, before → after, when.
- **Empty state:** "No entries in this range."
- **Important interactions:** Row → side panel with the full change; error rows show stack/trace info and copy button. ErrorState elsewhere links here with the traceId pre-filled.
- **Responsive behavior:** Cards.
- **Changes from current design:** 6 tabs → 3. Violations tab removed (Violations page covers it); RFID Access + Gate taps → Gate activity.
- **Reasoning:** Smaller, purpose-built. The traceId link closes the loop on "it looked like CORS" errors.

### Backup & restore — spec: Data Backup & Restore
- **Primary user goal:** Make a safe copy; very rarely, put one back.
- **Recommended layout:** Settings template: Create backup card → History table → **Danger zone** card (Restore).
- **Primary action:** Create backup.
- **Secondary actions:** Download (row).
- **Filters/search:** —
- **Main content:** History with size and date.
- **Empty state:** "No backups yet." (exists)
- **Important interactions:** Restore = Level 3 confirm (type `RESTORE`), explains that a safety copy is taken first (already true — say it in the dialog).
- **Responsive behavior:** One column.
- **Changes from current design:** Small: restore visually moved into a danger zone at the bottom; metric cards trimmed to last backup + count.
- **Reasoning:** Already careful. Make the danger look dangerous.

---

## 10. Visual hierarchy

What the eye should hit, in order: **1) where am I → 2) what's the main thing to do →
3) what's in the data → 4) what's wrong in the data.**

| # | Element | Treatment | Weight |
|---|---|---|---|
| 1 | Page title | Inter Display 22/700, primary text | Highest text weight on the page |
| 2 | Page description | 14/400, secondary text, one line | Quiet; read once, then ignored |
| 3 | Primary action | Only filled indigo element in the view, top right | Highest colour weight |
| 4 | Secondary actions | Outlined, neutral, left of primary | Present but calm |
| 5 | Filters | Pills, neutral until active → tinted indigo | Calm until used, then visible |
| 6 | Data | 14px body, primary text; key column (name/plate) semibold | The bulk; must be easy to scan |
| 7 | Status | Tinted pill with a word; danger/warning pills are the only strong colour inside a table | Pops *only* when something is wrong |
| 8 | Destructive actions | Red text inside ⋯ or a separated red-outlined button / danger zone | Hidden or isolated, never next to primary |
| 9 | Supporting info | 12px Inter, tertiary/secondary text: timestamps, IDs, helper text | Lowest |

**First, second, third:**
1. **Title + primary button** — top row, the only big text and the only filled colour.
2. **Status colour in the data** — amber/red pills and highlighted rows pull the eye to problems.
3. **The rest of the table** — neutral, aligned, scannable.

Test: blur a screenshot. You should still see the title, one indigo blob top-right,
and the red/amber spots in the table — nothing else.

---

## 11. What I would NOT change

1. **The token architecture.** Palette → semantic tokens → theme, with "screens never name a colour". This is better than most production apps.
2. **The colour identity.** Indigo + cream shared with mobile, the status ramps and the bg/fg/border/solid pairing in `StatusColors`.
3. **Flat cards with hairline borders**, shadows only for floating things.
4. **Dark mode as it is** (with the contrast fix).
5. **Inter / Inter Display**, bundled locally so the demo works without Wi-Fi.
6. **44px table rows and 14px base text.** Right density for admin work.
7. **`AppFilterDropdown`'s design** — showing "Status: All" and tinting when active is exactly right.
8. **Filters left, search right** in the toolbar — a reasoned choice; keep it.
9. **Skeleton loading via `AsyncView`** as the standard.
10. **`StatusIntents` per domain** — "Dismissed" meaning different things for appeals and incidents is handled correctly.
11. **Hiding (not disabling) what a role can never use**, and one shared nav definition for rail, drawer and dashboard.
12. **Separate Security overview** and the Gate Check screen idea.
13. **Backup's careful wording** and safety copy before restore.
14. **Module shortcut grid with spec names** — keep it for the capstone panel, just at the bottom of Overview.

On **radius**: the tighter radii in §7 are a taste-plus-density argument, not a
fix. If you like the soft look and its match with mobile, skip it. It is last on
the roadmap for that reason.

---

## 12. Final concept (handover)

**Design philosophy.** A calm control room. Neutral surfaces, colour only for
meaning, one obvious next step per screen, dangerous things look dangerous.

**Navigation philosophy.** Group by what the person is doing (Gates, People,
Enforcement, Payments, Reports, System). One page per topic; sibling views are tabs
in the URL. Find anything by search, not by remembering where it lives. Badges show
where work is waiting.

**Layout philosophy.** Five templates — List, Detail, Dashboard, Station,
Settings. Every list page has the same anatomy. Side panels for a quick look,
full pages for deep work, dialogs only for confirms and short forms.

**Component philosophy.** Build the pattern once, in `widgets/ui`, and make the
screens thin. A screen describes *what* (columns, filters, actions); the components
decide *how* it looks at each width.

**Responsive philosophy.** Change structure, don't shrink: tables become cards,
filters become a sheet, secondary actions go into ⋯, guards get a bottom nav,
phones show "needs attention" first.

**Accessibility philosophy.** Real controls, visible focus, words alongside colour,
AA contrast, full keyboard use, and big targets on touch and guard screens.

### Top 10 design decisions

1. Regroup navigation: split "System" into People / Payments / Reports / System.
2. Merge duplicated pages into one page with URL tabs (Payments, Visitors, Devices, Logs).
3. Move Appeals into Violations; gate events into Gate activity.
4. Global search (Ctrl+K) for name / plate / tag / student no. / reference.
5. One primary action per view; destructive actions only in ⋯ or a danger zone.
6. Shared `ConfirmDialog` with three strengths (simple / reason / type-to-confirm).
7. `AppDataView`: column priorities, tables become cards under 768.
8. Registration review as a real queue: sticky decision bar, auto-next, Undo.
9. Side panels for row details (violation, payment, incident, device).
10. Fix contrast (`text.tertiary`) and limit Plex Mono to machine values.

(11th, to discuss: left sidebar instead of top pills — §2.4.)

### Implementation roadmap

**Deadline.** Do all phases, one at a time, each merged and tested on your
devices before the next starts. **Freeze UI changes one week before the defense**
so the demo build is the one you have rehearsed. Phase 0 is done (see Decisions
at the top). Order changed: bug fixes and the shell come first, because they are
the most visible and everything else sits inside them.

| Phase | What | Risk | Size | Before freeze? |
|---|---|---|---|---|
| **0. Decide** | Answer the open questions below | — | Talk | Yes |
| **0.5 Bug fixes** | The 6 screenshot bugs (search box, clipping, phone columns, title wrap, footer, double title) | Low | Small | Yes |
| **0.8 Shell** | Left sidebar with gate pulse; new nav groups | Medium | Medium | Yes |
| **1. Foundations** | Contrast fix; `bodySmall` back to Inter + new `mono` style; `ConfirmDialog` (3 levels) replacing hand-written confirms; `RowActions` + `ActionMenu`; `ErrorState` with traceId; focus ring audit; page titles = nav labels + spec tags | Low — visual + mechanical | Medium | Yes |
| **2. IA** | New nav groups; merged pages with URL tabs; redirects from old routes; Appeals into Violations; Gate activity; bell = inbox, Announcements page | Medium — routes move | Medium | Yes |
| **3. Registration queue** | Sticky decision bar, auto-next, Undo toast, oldest-first, ageing colours | Low–medium | Small | Yes |
| **4. List pages** | `AppDataView` with column priority + card mode; `ActiveFilterChips`; `FilterSheet`; Users bulk selection | Medium | Large | Yes, if time |
| **5. Side panels** | `SidePanel`; violation dialog → panel with timeline; payment receipt, incident, device, slot panels | Medium | Medium | Yes, if time |
| **6. Global search** | Ctrl+K across users, plates, tags, payments, violations (needs one API search endpoint) | Medium — needs backend | Medium | Yes, if time |
| **7. Responsive + guard mode** | New breakpoints; guard bottom nav; station density for Gate Check; phone dashboard order | Medium | Medium | Yes, if time |
| **9. Polish** | Radius tweak (optional), keyboard shortcuts, chart text summaries, reduced motion | Low | Small | Yes, if time |

Each phase is shippable on its own and leaves the app working.

### Open questions

None — all six were decided on 2026-10-04 (see Decisions at the top).
