# AimPark Admin — ClickUp Restyle Plan

**Goal:** make the admin panel read like a modern SaaS workspace (ClickUp as the
reference) without changing a single line of backend, provider, model or router
logic. UI/UX only.

**Decisions taken (2026-08-16):**

| Decision | Choice |
|---|---|
| Brand colour | **Keep AimPark blue.** Copy ClickUp's *structure*, not its purple. |
| Scope | Restyle all 13 screens + rebuild the shell + add a slide-over. No dashboard, no ⌘K, no view tabs. |
| Design extraction | **skillui only**, run against `clickup.com`. |

---

## 0. The situation this plan starts from

The design system already exists and is already documented in
[admin-design-system.md](admin-design-system.md):

- `lib/theme/` — 5 files, ~1,330 lines. Three-layer tokens, both brightnesses.
- `lib/widgets/ui/` — 9 components + barrel. All present.
- Dark mode — **already written**, pinned off in `main.dart`.

What does *not* exist: any screen that uses it. All 13 screens (7,858 lines)
still carry hardcoded colours, and `widgets/admin_shell.dart:8` still declares
`const _navBackground = Color(0xFF1E293B)` with `Colors.white54` throughout.

**So the ClickUp restyle and the token migration are the same job.** Every screen
gets touched exactly once. Doing them separately would mean writing each screen
twice.

---

## 1. What "ClickUp" means for a data-dense admin panel

The restyle is these seven patterns, and nothing else. Anything not on this list
is out of scope.

| # | Pattern | Where it lands |
|---|---|---|
| 1 | Dark ~240px sidebar; rounded *inset* selected pill, not full-bleed; workspace chip on top, user chip on bottom; grouped sections | `admin_shell.dart` |
| 2 | Right-hand slide-over detail panel instead of navigating away | registration detail, user detail |
| 3 | Toolbar strip above every table: search · filter · sort | new `AppToolbar` |
| 4 | Dense rows (44px), hairline dividers, whole-row hover | `AppDataTable` |
| 5 | Dot-prefixed colour pills | `StatusPill` — already does this |
| 6 | Soft shadow + 8–12px radius on every raised surface | `AppElevation`, `AppRadii` — already exist |
| 7 | Fast motion (≤180ms); nothing in an admin tool should feel like it animates | `AppMotion` — already exists |

Four of the seven are already built. That is the whole reason this is affordable.

---

## 2. Phase 0 — Extraction ✅ *done 2026-08-16*

```bash
npm install -g skillui
npx playwright install chromium          # --mode ultra needs this
skillui --url https://clickup.com --mode ultra
```

**Output lives in [clickup-skill/](clickup-skill/)** — `DESIGN.md`, `SKILL.md`,
`CLAUDE.md`, `screenshots/homepage.png`. The 3.3 MB `.skill` archive and the
26-file font dump were deliberately left out of the repo; the originals are at
`~/clickup-design/` if they're ever needed again.

**What actually came back.** The run printed *"Continuing without ultra
features"* and fell back to static analysis, so there is no interaction trace —
one homepage screenshot and six generic HTML "components". The harvest was
correspondingly thin, and mostly **confirmed** the existing token system rather
than changing it:

| Extracted | Verdict |
|---|---|
| 4px base grid, scale 2–24 | Already exact — `AppSpacing` unchanged |
| Body 14px / Inter | Already exact — `AppTypography` scale unchanged |
| Headings 236px / 166px | Rejected: marketing hero sizes, meaningless for an admin table |
| 20-colour palette | Rejected as planned (brand stays blue), and it is junk anyway — `border: #1d1e20`, `danger: #fd9a46` |
| 45 border-radius values | No scale to extract; our 6/8/12/16 stands. ClickUp's own `--table-border-radius` is 10–14px, close enough |
| **Layered shadow ladder** | **Taken** → `AppElevation` rewritten |
| **Inter + Plus Jakarta Sans `.ttf`** | **Taken** → Inter bundled, `google_fonts` removed |
| "No zebra striping, no blur" | Confirms the hairline-divider decision in §4 |

Two real changes came out of it:

1. `AppElevation` now uses ClickUp's doubling ladder — each layer twice the blur
   and offset of the last, pulled back by a negative spread of half its blur.
   Dense under the edge, long soft tail. This is the single largest visual
   difference between a modern SaaS surface and a Material one.
2. Inter's four used weights are bundled under `assets/fonts/` and `google_fonts`
   is gone from `pubspec.yaml`. **This closes the offline-demo risk in §9.**

> ⚠️ skillui also installed a global skill at `~/.claude/skills/clickup-design/`.
> It does not auto-load, but it *is* offered in every Claude Code session on this
> machine and its instructions are Tailwind/JSX-shaped. Delete that folder if it
> ever starts pulling a session sideways.

Nothing from skillui was consumed as code — it is a reference sheet. The
`CLAUDE.md` and `SKILL.md` it emits stay under `docs/clickup-skill/`, never at
the repo root, or Claude Code would load them every session and start writing
Tailwind and React into a Flutter project.

**Known limitation, now confirmed:** `clickup.com` is the marketing site, the
product UI is behind login, and the crawl fell back to static analysis anyway.
So it supplied **none** of the sidebar, row or slide-over layout — those come
entirely from documented ClickUp app conventions (section 1 above), exactly as
anticipated. If Phase 1 review feels off, the cheap fix is still 3–4 screenshots
of the real app dropped into `docs/clickup-skill/screenshots/`.

---

## 3. Phase 1 — The shell ✅ *done 2026-08-16*

`widgets/admin_shell.dart` — 239 lines, rewritten. **Highest visual payoff per
line changed in the entire project**, and it is what unblocks dark mode.

**Structure**

```
┌─ 240px ────────────────┐
│ ◆ AimPark              │  workspace chip — logo + "STI Baliuag" + chevron
│                        │
│ OPERATIONS             │  section label, 11/600, inverseMuted
│   ▸ Pending Registrations
│   ▸ Parking            │  ← selected: inset 8px-radius block,
│   ▸ Payments           │    white @10%, white icon, 600 weight
│ ENFORCEMENT            │
│   ▸ Violations         │  hover: white @6%
│   ▸ Policy Rules       │
│   ▸ Incidents          │
│ SYSTEM                 │
│   ▸ User Management    │
│   ▸ Notifications      │
│   ▸ Reports            │
│   ▸ Audit Log          │
│ ─────────────────────  │
│ ● Juan D.        ⋯     │  user chip → logout menu
└────────────────────────┘
```

**Changes**

- Ten flat nav items become three labelled groups. ClickUp groups; ten
  undifferentiated items is the single most dated thing about the current panel.
- `NavigationRail` is replaced with a plain `Column` of custom tiles —
  `NavigationRail` cannot do an inset rounded selection block, and fighting it
  costs more than replacing it.
- Every colour reads `t.surface.sidebar` / `t.surface.sidebarHover` /
  `t.surface.sidebarSelected` / `t.text.inverse` / `t.text.inverseMuted`.
  **No `Colors.white54` survives this phase.**
- Collapse toggle → 56px icon-only rail, tooltips on.
- `_NavItem`, `_selectedIndex` and the `context.isCompact` drawer branch are
  kept as-is. The drawer re-skins from the same tile widget so the two can still
  never drift.

**Done when:** the sidebar is indistinguishable in structure from a ClickUp
sidebar, and `grep -c 'Color(0xFF\|Colors\.' admin_shell.dart` returns 0.

**Outcome.** Gate met — the grep returns 0 and `flutter analyze lib` reports
nothing in this file. 239 lines → 480, all of it the tiles the old file got for
free from `NavigationRail`. Notes on what landed differently from the sketch:

- **Widths came from the tokens, not this doc.** `AppSizes.sidebarExpanded` is
  248 and `sidebarCollapsed` is 72, against the 240/56 written above. The tokens
  won — a second source of truth for a width is exactly the drift the design
  system exists to prevent. With 8px tile margins the collapsed pill is 56px
  wide anyway, so it reads as intended.
- **The user chip shows an email, not a name.** The JWT carries
  `NameIdentifier`, `Email` and `Role`, and no display name at all — so a "Juan
  D." would have had to be invented. It shows the part before the `@` with the
  full address in the menu, via a new `JwtUtils.getEmail`. Getting a real name
  in there needs an API change, which is out of scope by §8.
- **The collapse toggle hides itself below 900px**, where the rail is already
  force-collapsed. A control the next resize would silently override is worse
  than no control.
- **Group labels survive collapse as a hairline rule.** Dropping them outright
  would have left ten near-identical icons in one undifferentiated stack —
  which is the exact problem this phase set out to fix.
- `_NavItem`, `_selectedIndex` and the `isCompact` drawer branch are unchanged
  as planned. `_navItems` is now *derived* from `_navGroups` rather than written
  out twice, so the flat index `_selectedIndex` returns cannot fall out of step
  with the grouped layout.

Not yet verified in a browser — worth a look at three widths (phone, ~800px,
full) before Phase 2 builds on top of it.

---

## 4. Phase 2 — Table screens ✅ *done 2026-08-16*

Cheapest first, so the pattern is proven on a 134-line file before it is applied
to a 728-line one.

1. `pending_registrations_screen.dart` (134) — **the template**
2. `audit_log_screen.dart` (217)
3. `payments_screen.dart` (378)
4. `user_management_screen.dart` (485)

**New component:** `widgets/ui/app_toolbar.dart` — search field, filter chips,
sort control, right-aligned actions slot. Sits between `AppPageHeader` and the
table. Exported from `ui.dart`.

**Edited component:** `AppDataTable` gains ClickUp row density — 44px rows,
`t.border.subtle` dividers, full-row `t.surface.hover`, and optional group
headers (label + count + status colour bar).

Per screen: delete the private `_StatusChip` / `_Pagination` / `_Field` classes,
swap in the kit, replace every literal colour with a token. No behaviour change,
no provider change.

### Outcome

All four screens migrated; `flutter analyze lib` is clean across the whole app
and `flutter build web --release` succeeds. 1,214 lines of screen code became
845, almost entirely by deleting private re-implementations.

**Row density came from the theme, not the widget.** `app_theme.dart` already
routed `dataRowColor` through `t.surface.hover` and dividers through
`t.border.subtle`, so three of the four listed changes were a one-line edit to
`AppSizes.tableRowHeight` (52 → 44, header 44 → 40) rather than work on
`AppDataTable`.

**Group headers were not built.** No Phase 2 screen groups its rows, and
shipping an unused API is worse than shipping none. Deferred to Phase 4, where
Parking-by-zone is the first screen that actually wants it.

**Two components were added that the plan didn't foresee:**

- `AppFilterDropdown` — a filter that names itself even when unset ("Status:
  All") and tints when set. The bare `DropdownButton`s it replaces sat in the
  page header at the same visual weight as a primary button, and gave no hint
  why a table was empty. Now used by three screens.
- `AppRowAction` — the small button that fits a 44px row. Material's 40px
  minimum height doesn't, so four screens had each grown a private shrunken
  copy; User Management's version hardcoded four `Colors.*` for its action
  tints, which now come from the status tokens.

**Search and sort were added only where they can tell the truth.** Pending
Registrations returns its whole queue in one response, so it got client-side
search and sortable columns. Payments, Users and Audit Log are server-paginated:
a search box there would filter the fifty rows on screen and silently ignore the
other four hundred, so they got filters only. User Management's search was
already server-side and stayed that way. **This is a departure from §1 pattern
3**, which called for search on every table.

**One real bug fixed, and it was a behaviour change.** User Management's suspend
dialog returned the reason string, which made "cancelled" and "confirmed with an
empty reason" both come back as `null`; the tie-break that followed resolved to
*suspend*, so **pressing Cancel suspended the account**. The dialog now returns
a bool and reads the controller separately. Fixing it violates "no behaviour
change" and was worth it.

**Two smaller judgement calls.** User Management's "Archived" column was an
empty cell on almost every row — it is now a struck-through name plus an
Archived pill, one column lighter. And Audit Log's per-action snackbar tints
(green for unsuspend, red for archive) are gone: a red snackbar reads as "that
failed", which is the opposite of what a successful archive should say.

---

## 5. Phase 3 — The slide-over

**New component:** `widgets/ui/app_slide_over.dart`

- Right-anchored panel, 520px, `AppMotion.slow` slide + scrim fade
- `t.surface.scrim` behind it; click-out and `Esc` both close
- Header: title, `StatusPill`, action buttons, close ✕
- Body scrolls independently; footer pinned for primary actions

**Routing decision.** The two detail screens have real routes and must stay
deep-linkable. Approach:

- The route stays and still renders the full-page version. Direct URL, bookmark
  and refresh all keep working.
- Opening a detail *from a list row* instead pushes a provider-held
  `SlideOverRequest`, which the shell renders as an overlay above the current
  screen — so the table stays visible behind it, which is the entire point of
  the pattern.
- Both paths render the **same** body widget. The screen file is split into
  `_DetailBody` (shared) plus two thin wrappers. No logic is duplicated.

Then convert `registration_detail_screen.dart` (371) and
`user_detail_screen.dart` (486).

---

## 6. Phase 4 — Heavy screens

`violations_screen.dart` (728) · `parking_screen.dart` (586) ·
`reports_screen.dart` (347)

Same migration as Phase 2, but these are large enough to be their own phase.
Reports additionally moves its metric tiles onto `MetricCard` and its chart
colours onto `t.chart.series(i)`.

---

## 7. Phase 5 — Remainder, then dark mode on

`policy_rules_screen.dart` (248) · `incidents_screen.dart` (271) ·
`notifications_screen.dart` (255) · `login_screen.dart` (300)

Login gets the most visual attention of the four — it is the first thing a
panelist sees.

**Closing out:**

- `main.dart` → `themeMode: ThemeMode.system`. Dark mode was written months ago;
  this is the line that turns it on, and it only becomes safe once the shell no
  longer hardcodes white-on-slate.
- Delete `widgets/page_header.dart` — superseded by `AppPageHeader`, and by this
  point nothing imports it.
- Update section 8 of [admin-design-system.md](admin-design-system.md), which
  currently says the migration has not started.

---

## 7b. Visual overhaul — *added 2026-08-16, out of original plan order*

The restyle was making the panel **consistent**, which is not the same as making
it **good**. Thirteen screens of header-then-table are uniform and still dull.
This section is the answer to "what would actually move the needle", agreed
after Phase 2 and built ahead of Phases 3–5.

### Charts — `widgets/ui/app_chart.dart` (new), `fl_chart` added

Reports hand-rolled its own bars out of `Container`s: no axis, no gridlines, no
tooltips. `AppBarChart`, `AppAreaChart` and `AppProgressRing` replace it, all
reading `t.chart.series(i)` and `t.chart.grid` — tokens that had been defined
since the design system was written and never once used.

### Dashboard — `screens/dashboard_screen.dart` (new), now the landing route

**The plan was wrong to call this out of scope.** It listed the dashboard as "a
new screen, not a restyle" — but all five providers it needs already existed for
Reports. It cost no backend work at all.

`/dashboard` replaces `/pending` as `initialLocation` and as the post-login
redirect. Four metric tiles, an occupancy ring, a "needs attention" list that
links straight into the three queues, a revenue area chart and two bar charts.
Reports keeps the same data at longer windows: the dashboard is where you
*notice*, Reports is where you *study*.

### Parking — rebuilt as a floor map rather than restyled

The one screen whose data is inherently spatial, previously announcing a full
lot with a line of grey 14px text. Now: an occupancy ring, a fill bar per gate,
and bays coloured through `StatusIntents.slot`. Occupied bays are joined against
`activeParkingSessionsProvider` so a bay names its driver and plate on hover —
which is the entire argument for drawing a map instead of a list. **This
supersedes the Phase 4 line item for `parking_screen.dart`.**

### Login — split brand panel

First thing a panelist ever sees. Gradient brand half with the AimPark mark and
three product claims, form on the other half, collapsing to form-only below
940px. The gradient is deliberately the only one in the panel: a flourish is
noise on a data screen and the difference between a product and a form on the
one screen with no data.

### Dark mode — reachable, not default

`main.dart` now reads `themeModeProvider`, toggled from the sidebar account
menu. It is **not** `ThemeMode.system`, and that is deliberate: Violations,
Incidents, Policy Rules, Notifications and the two detail screens still hardcode
`Colors.white` and `Colors.black54`, so following the OS would hand a dark-mode
user six screens of white text on white. **Phases 3–5 are what unblock the
default.** One line in `providers/theme_provider.dart` changes when they land.

---

## 8. Out of scope

Named explicitly so they don't creep in:

- ~~Home dashboard screen~~ — **built, see §7b**
- ⌘K command palette
- View tabs (List / Board / Table) on Parking and Violations
- Any provider, model or API change. *Router logic did change:* the landing
  route moved to `/dashboard`, which a new landing screen cannot avoid.
- ClickUp's purple — the brand stays blue

---

## 9. Risks

| Risk | Mitigation |
|---|---|
| ~~skillui's `CLAUDE.md` lands at repo root and hijacks sessions~~ | **Closed** — output is under `docs/clickup-skill/`. Note the global skill at `~/.claude/skills/clickup-design/`, see §2 |
| Marketing-site tokens produce a landing-page look | **Closed** — the palette and the 236px type scale were both discarded; only the shadow ladder survived |
| ~~`google_fonts` fetches Inter at runtime — offline defence demo~~ | **Closed 2026-08-16** — Inter bundled under `assets/fonts/`, dependency removed |
| Slide-over breaks deep links | Route and overlay render the same shared body; the route is never removed |
| A phase half-lands and the panel looks mixed | One phase per commit; every phase leaves the app building and coherent |
