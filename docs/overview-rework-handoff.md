# Overview rework: handoff notes

Written 2026-10-14 so a fresh Claude session on another PC can pick up exactly where this one stopped.
Branch: `feat/overview-rework` (branched from `feat/incident-security-follow-up`).
Read this whole file first. It replaces the chat history and the local memory notes, which do not travel between PCs.

## Why this exists
The defense is close (capstone, solo dev, Oct 2026). The admin Overview was judged 5/10: numbers disagreed with each other, widgets were decoration, the useful Alerts sat at the bottom, and there was no way to investigate a plate or person. The user also wants the admin Reports page reviewed the same way (not started: they still have to send screenshots).

## How the user wants to work (important)
- Write chat replies in **simple, short English**. They write Taglish. They said "too much" when replies were long.
- **Open every build phase with a short briefing** that says which complaints the phase closes.
- **Do not start building until they approve a plan.** Discuss first, decide together.
- They run the testing. Build phases to completion; do not run test suites or pause for device checks. Compiling and `flutter analyze` are fine.
- Give firm UI/UX decisions with reasons. Check the real UI with a screenshot, do not only read code.
- **Never run a second local API.** It sends duplicate pushes from the shared database. Test admin UI with a fake-data preview entry point instead (see "How to preview" below).
- One Supabase database is shared by local branches and deployed main. A migration on a feature branch breaks prod until merged. **This work added no migrations. Keep it that way.**
- Do not commit the Chapter 5 diagram folders (`docs/flowcharts`, `docs/erd`, `docs/dfd`, `docs/ipo`). They are paper-only.
- Pre-existing uncommitted noise, not part of this work: regenerated `*.g.dart` files in `aimpark_admin` and `aimpark_mobile/macos/Flutter/GeneratedPluginRegistrant.swift`. Do not commit them.

## Decisions agreed with the user
**Layout, top to bottom:** header (date picker + guard post label) → Needs attention (live) → Live bays | Recent activity → Active sessions | This period. The sidebar replaces the old Modules grid.

- **Date picker:** Today, Yesterday, Last 7 days, Last 30 days, All time, Pick a day, Custom range. It moves only the history side: activity feed, period totals, hourly chart. It never moves live bays, active sessions, or Needs attention.
- **Guard post is the only source of truth for bays.** When the cloud has not heard from it, show "Last known" and the time, and say gate decisions still run on the guard post.
- **Feed shows only things that need a look:** serious denials (unknown card, or plate that is not the card holder's), new incidents, new violations. Routine refusals (full lot, double tap, no camera reading) stay on the Gate Taps page.
- **Unpaid money is split into fees and fines** (`PaymentSource.ParkingFee` and `ViolationPenalty`).
- **"Today" is the Philippine day** (UTC+8, midnight to midnight). The old report code used the UTC day, so "today" started at 8 AM.
- **All time** groups by week or month instead of a point per day.
- **Dropped on purpose:** overstays (the system has no overstay rule, never suggest it), guard action and reviewer on gate taps (`GateTapEvent` has no review fields), plate photos in the cloud panel (photos stay on the guard PC), the Modules grid, gauge card, fill bars, Device health card, dual-axis and radial charts, the red percentage badge, the Overview Export button.
- Incidents have no plate or vehicle link. In a profile, "incidents" means the ones **filed by that person**. Label it that way.

## What is done (all on this branch)
### Phase 1: fix the numbers (backend)
- `Helpers/PhilippineTime.cs`: fixed UTC+8 offset helpers (`Today`, `LocalDate`, `LocalHour`, `StartOfDayUtc`).
- `Helpers/ReportPeriod.cs`: `ReportQuery` (days | from/to | allTime) and `ReportPeriod` (resolves to Philippine days, UTC bounds, day/week/month cut: up to 62 days daily, up to 400 weekly, beyond that monthly, weeks start Monday).
- `Services/ReportService.cs`, `Controllers/AdminReportsController.cs`, `Interfaces/IReportService.cs`, `DTOs/ReportResponse.cs`: every report endpoint takes `days`, or `from` and `to` (`yyyy-MM-dd`, Philippine dates, inclusive), or `allTime=true`. Responses carry a `period` object (from, to, granularity). Old `days=N` calls still work.
- **One definition of free bays**: `ParkingCapacity.Of` (working bays minus cars that tapped in), the same rule the gates use. Summary now has `usableSlots`, `availableSlots`, `occupiedSlots` (free + occupied = usable), free and usable per four-wheel and motorcycle, `noSignalSlots`, `outOfServiceSlots`.
- Summary also has fees and fines split (collected in period, pending now), `sessionsToday`, `sessionsInPeriod`, `violationsIssued` (period), `openIncidents`, and `seriousDenialsToday`. Summary with no range means all time, as before.
- Peak hours now use the Philippine hour.
- Admin app: `models/report.dart` has the new summary fields and fee/fine on revenue points. The red delta badge was removed from the old dashboard.
- Tests (compiled, not run): `AimPark.API.Tests/ReportPeriodTests.cs`.

### Phase 2: search and profile (backend)
- `GET /api/admin/search?q=` (Admin only) returns up to 5 each of: `person`, `visitor`, `card` (tapped card nobody holds), `plate` (camera plate nobody registered). Handles "ncd 4417" and "04:a1:22:f9". Archived users are included and marked.
- `GET /api/admin/search/profile` with exactly one of `userId`, `visitorPassId`, `card`, `plate` returns subject info, latest 20 taps (same row shape as Gate Taps, so the Dart `GateTapEvent` model can be reused), latest 10 sessions, violations, incidents filed, and totals (taps, denied, serious denied, sessions, violations, incidents). A person's taps include their card and also any tap where the camera read one of their plates on someone else's card.
- Files: `Controllers/AdminSearchController.cs`, `Services/InvestigationService.cs`, `Interfaces/IInvestigationService.cs`, `DTOs/InvestigationDtos.cs`, `Helpers/SearchTerm.cs`, registered in `Program.cs`. `LiveGateController.AsRow` became `internal`.
- Tests (compiled, not run): `AimPark.API.Tests/SearchTermTests.cs`.
- **The EF queries are only verified by compiling.** Call them once against a running API. If a query fails to translate it will show on first call. Try `/api/admin/search?q=<name>`, `?q=<plate>`, and `/profile?card=<id>`.

### Phase 3: rebuild the Overview (admin app)
- `aimpark_admin/lib/providers/overview_provider.dart`: `OverviewPeriod` + `overviewPeriodProvider`, `overviewSummaryProvider` (refreshes every 15 s), `overviewHoursProvider`, `overviewFeedProvider` (merges serious denied taps, incidents, violations; newest 8). Plain Riverpod providers, no code generation.
- `aimpark_admin/lib/screens/dashboard_screen.dart`: fully rewritten with the layout above. Needs attention tiles open their pages. "Fees" and "fines" both open `/payments`.
- `LiveGateController.History` got a `serious=true` filter for the feed.
- Checked visually with fake data: the full online layout renders. **Not checked on screen:** the offline state and the empty state.
- Gotcha found: `AppDataTable` needs a fixed height (it uses `Expanded`), and `IntrinsicHeight` breaks around anything that uses `LayoutBuilder` (tables, `fl_chart`). The dashboard now uses plain rows and `_TwoUp(matchHeights: false)` for that row.

## What is next
### Phase 4: search bar and investigation panel (admin app) — start here
Briefing to give the user: it closes "a denial can't be traced to a person".
1. Search box in the Overview header. As the admin types, call `GET /api/admin/search?q=` (debounce about 300 ms, ignore under 2 characters). Show results grouped by kind.
2. A side panel (not a new page) that opens from a search result **and** from a feed row. It loads `GET /api/admin/search/profile`. Show: who it is, the tap details with the reason text, registered vs camera plate, other taps, sessions, violations, incidents filed by this person. See the approved mockup: red box for the reason ("Camera read ABM 8903 but this card is registered to a different plate."), a details table, then a "Linked records" list.
3. "Other taps by this card" must open the real filtered Gate Taps list (Gate Taps already searches by card and plate; it may need a way to receive an initial search from the route).
4. Feed rows currently just navigate to the list page (`/gate-taps`, `/incidents`, `/violations`). Change them to open the panel.
5. Unknown cards or plates have no owner, so the panel shows less. No plate photo. No guard action row.

### After Phase 4
- **Reports page review.** Ask the user for screenshots, rate it out of 10 for usefulness, discuss before changing anything. It should reuse the same period picker. `aimpark_admin/lib/providers/reports_provider.dart` and `screens/reports_screen.dart` still use the old `days` window and need to move to the new from/to/allTime parameters and the `period.granularity` in responses.
- Demo data for the three defense scenarios the user agreed on: a normal authorized entry, a plate mismatch an admin can investigate, and a guard post disconnect where bays show as last known.
- Known limits to mention if asked: the feed uses the newest 20 incidents and 20 violations and filters by date in the app, so a very long period can miss older ones. Reports endpoints have never taken a date range before this branch.

## Deploy order
The cloud API must be deployed before the new admin build uses the new fields. The old admin build keeps working against the new API (all changes are additive). No database migration is needed.

## How to build, check and preview
- Build the API without locking a running exe:
  `dotnet build AimPark.API/AimPark.API/AimPark.API.csproj -p:UseAppHost=false -p:OutDir=<some scratch dir>/`
  (the same for `AimPark.API.Tests`). A plain build fails with "file is being used" if the API is running.
- Admin app: `flutter analyze` in `aimpark_admin`.
- To look at a screen without an API: write a temporary `lib/preview_<name>.dart` with its own `main()` that wraps the screen in `ProviderScope(overrides: [...])` using fake data and a tiny `GoRouter`, run `flutter run -d web-server --web-port 8093 -t lib/preview_<name>.dart`, open it in the browser pane, then **delete the file**. Stop the server by killing the process listening on the port (`Get-NetTCPConnection -LocalPort 8093` then `Stop-Process`). TaskStop only stops the wrapper, not the Dart process, and the port stays busy.
- A first Flutter web build takes a few minutes. Hot reload is not available from a background shell, so restart on a new port after each change.

## Key files
API: `Helpers/PhilippineTime.cs`, `Helpers/ReportPeriod.cs`, `Helpers/SearchTerm.cs`, `Services/ReportService.cs`, `Services/InvestigationService.cs`, `Controllers/AdminReportsController.cs`, `Controllers/AdminSearchController.cs`, `Controllers/LiveGateController.cs`, `Controllers/SiteLinkController.cs` (guard post heartbeat), `DTOs/ReportResponse.cs`, `DTOs/InvestigationDtos.cs`.
Admin: `lib/screens/dashboard_screen.dart`, `lib/providers/overview_provider.dart`, `lib/providers/site_link_provider.dart`, `lib/models/site_link.dart` (has `stale`, `staleSince`, `lastContact`), `lib/widgets/parking/gate_status.dart` (`GateStatus.fromRelayed`), `lib/models/gate_tap_event.dart`, `lib/core/utils/ph_time.dart`.
