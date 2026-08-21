# AimPark Admin — Design System

The admin panel is unfinished on purpose: violations, incidents, reports and
policy rules will all grow, and more screens are coming. This document exists so
that the screen you write in November looks like the screen you wrote in August
without anyone having to remember what August looked like.

**The rule:** a screen never names a colour, a size or a font. It names a
*role* — `t.text.secondary`, `AppSpacing.cardPadding` — and the system decides
what that role looks like. Every hardcoded `Color(0xFF...)` is a decision that
dark mode, a rebrand and the next developer can no longer reach.

---

## 1. Where things live

```
aimpark_admin/lib/
├── theme/
│   ├── app_palette.dart      LAYER 1  raw colour ramps          (do not import)
│   ├── app_dimensions.dart   LAYER 1+2 spacing, radii, motion, sizes
│   ├── app_typography.dart   LAYER 1+2 the type scale
│   ├── app_tokens.dart       LAYER 2  semantic tokens (the vocabulary)
│   ├── app_theme.dart        LAYER 3  Material component defaults
│   └── theme.dart            ← import this
└── widgets/ui/
    ├── app_page.dart         page skeleton + header
    ├── app_card.dart         AppCard, AppSectionCard
    ├── app_data_table.dart   AppDataTable, AppCardSurface, cell helpers
    ├── app_pagination.dart   AppPagination
    ├── app_field.dart        AppField, AppFieldGrid
    ├── async_view.dart       AsyncView, loading / empty / error states
    ├── metric_card.dart      MetricCard
    ├── status_pill.dart      StatusPill + StatusIntents
    └── ui.dart               ← import this
```

Two imports get you everything:

```dart
import '../theme/theme.dart';
import '../widgets/ui/ui.dart';
```

`app_palette.dart` is intentionally not exported by `theme.dart`. If a screen
needs a colour the tokens cannot express, the fix is to **add a token**, not to
reach around them.

---

## 2. The three layers

```
LAYER 3  Component     AppTheme's DataTableThemeData, ButtonStyle, StatusPill
              ↑        "a table header is muted surface with 12px semibold text"
LAYER 2  Semantic      t.surface.card, t.text.secondary, t.status.danger
              ↑        "secondary text is neutral-500 in light, neutral-400 in dark"
LAYER 1  Primitive     AppPalette.neutral500, AppSpacing.x4
                       "neutral-500 is #64748B"
```

Each layer only ever reads the one below it. That is what makes dark mode a
single-file change: `AppTokens.dark` re-points Layer 2 at different primitives,
and Layers 3 and above never notice.

---

## 3. Using tokens

Tokens ride on `ThemeData.extensions`, so they resolve per-brightness through
the widget tree. Read them from context:

```dart
@override
Widget build(BuildContext context) {
  final t = context.tokens;
  final text = Theme.of(context).textTheme;

  return Container(
    padding: const EdgeInsets.all(AppSpacing.cardPadding),
    decoration: BoxDecoration(
      color: t.surface.card,
      borderRadius: AppRadii.lgAll,
      border: Border.all(color: t.border.normal),
    ),
    child: Text('Plate number', style: text.bodySmall?.copyWith(color: t.text.secondary)),
  );
}
```

### Colour tokens

| Group | Token | Use it for |
|---|---|---|
| `t.surface` | `canvas` | The page background behind everything |
| | `card` | Cards, tables, dialogs, menus |
| | `muted` | Table headers, disabled fields, inset wells |
| | `hover` / `selected` | Row and tile states |
| | `inverse` | Dark emphasis blocks, tooltips |
| | `sidebar`, `sidebarHover`, `sidebarSelected` | Navigation only |
| | `scrim` | The dim behind a modal |
| `t.text` | `primary` | Headings, table values — read first |
| | `secondary` | Labels, timestamps, helper text (was `Colors.black54`) |
| | `tertiary` | Placeholders, de-emphasised metadata |
| | `disabled` | Unavailable controls |
| | `inverse`, `inverseMuted` | Text on sidebar / inverse surfaces |
| | `link`, `onBrand` | Links; text on a filled brand button |
| `t.border` | `subtle` | Row dividers |
| | `normal` | Card and input outlines |
| | `strong` | Hover borders, emphasised separators |
| | `focus` | The keyboard focus ring — never remove it |
| `t.brand` | `primary` / `hover` / `pressed` | Primary actions, active nav |
| | `subtle` / `subtleText` | Tinted selected states, ghost buttons |
| `t.status` | `.success .warning .danger .info .accent .neutral` | Each carries `bg`, `fg`, `border`, `solid` |
| `t.chart` | `series(i)`, `grid` | Categorical chart colours, in order |

Each `StatusColors` bundles its four values deliberately: the tint, the text
that is readable **on** that tint, the hairline border, and the solid version
for dots and bars. Picking them together once is what prevents green-on-green.

### Spacing — everything is a multiple of 4

Prefer the named aliases; drop to a raw step only when nothing named fits.

| Alias | Value | Use |
|---|---|---|
| `pagePadding` | 24 | Outer padding of a page |
| `cardPadding` | 16 | Inside a card |
| `sectionGap` | 24 | Between major blocks on a page |
| `headingGap` | 16 | Between a heading and its content |
| `gutter` | 12 | Between cards in a grid |
| `controlGap` | 8 | Between buttons in a toolbar |
| `labelGap` | 4 | Between a label and its value |

Raw steps: `AppSpacing.x1`(4) `x2`(8) `x3`(12) `x4`(16) `x5`(20) `x6`(24)
`x8`(32) `x10`(40) `x12`(48) `x16`(64).

### Radius, elevation, motion

- **Radius** — `AppRadii.sm`(6) inline chips · `md`(8) controls · `lg`(12)
  containers · `xl`(16) dialogs · `full` pills. `.smAll`/`.mdAll`/`.lgAll` are
  ready-made `BorderRadius` constants.
- **Elevation** — `AppElevation.sm` resting cards · `md` hover · `lg` dialogs and
  slide-overs. These are real `BoxShadow` lists, because Material 3's numeric
  elevation renders as a surface *tint* and the panel wants an actual lift.
- **Motion** — `AppMotion.fast`(120ms) hover · `normal`(180ms) expand/collapse ·
  `slow`(280ms) panel slides. Anything slower reads as lag in an admin tool.

### Typography

The scale is mapped onto Material's own `TextTheme` slots, so an unstyled
`Text` inside a `DataTable` or `AlertDialog` is already correct.

| Slot | Size / weight | Use |
|---|---|---|
| `displaySmall` | 28 / 700 | Metric tile numbers |
| `headlineSmall` | 22 / 700 | Page title — one per screen |
| `titleLarge` | 18 / 600 | Dialog and slide-over headers |
| `titleMedium` | 16 / 600 | Card and section headings |
| `titleSmall` | 14 / 600 | The primary value in a row; field names |
| `bodyMedium` | 14 / 400 | **Default.** Table cells, form values |
| `bodySmall` | 12 / 400 | Timestamps, helper text, captions |
| `labelLarge` | 14 / 600 | Button labels |
| `labelMedium` | 12 / 600 | Table column headers, status pills |
| `labelSmall` | 11 / 500 | Badge counts, legend keys |

Base size is 14, not Material's 16 — fifteen visible table rows is worth more to
an admin than slightly roomier prose.

**Numbers in columns must use tabular figures**, or they visibly wobble row to
row: `AppTypography.tabular(text.bodyMedium!)`, or just use `AppNumericCell`.

**Font:** Inter, fetched and cached at runtime by `google_fonts`. If the defence
demo has to run offline, bundle the `.ttf` files under `assets/fonts/` and
change `AppTypography._base` to `TextStyle(fontFamily: 'Inter')` — one line, and
nothing else in the system moves.

---

## 4. Components

| Component | Use it when | Replaces |
|---|---|---|
| `AppPage` | Every screen. Canvas, padding, title block, toolbar slot | The repeated `Scaffold(backgroundColor: Color(0xFFF5F7FA))` |
| `AppPageHeader` | Inside `AppPage`; standalone only for nested views | `PageHeader` |
| `AsyncView` | Any `AsyncValue` from a provider | 10 hand-written `async.when` blocks |
| `AppEmptyState` / `AppErrorState` / `AppLoadingState` | Directly, when not using `AsyncView` | 4 different empty layouts |
| `AppDataTable` | Any tabular list | The nested-scroll `Card` + `DataTable` in every list screen |
| `AppCardSurface` | A card whose child manages its own padding | — |
| `AppNumericCell` / `AppPrimaryCell` | Money and count cells; name-over-ID cells | — |
| `AppPagination` | Under any paged table | 6 `_Pagination` / `_PageBar` classes |
| `AppCard` | Any container on the canvas | 5 hand-rolled card decorations |
| `AppSectionCard` | Grouping fields on a detail screen | 2 `_SectionCard` classes |
| `AppField` / `AppFieldGrid` | Read-only label/value pairs | 2 `_Field` classes |
| `StatusPill` | Any status, anywhere | **7** chip classes |
| `MetricCard` | Headline numbers on Reports | `_Tile` |

### Buttons — pick by meaning, not by looks

The theme has already styled all four; never pass a `style:`.

| Widget | Meaning | Per screen |
|---|---|---|
| `FilledButton` | The primary action | At most one |
| `OutlinedButton` | Secondary actions | Several |
| `TextButton` | Tertiary, Cancel | Several |
| `IconButton` | Icon-only, always with a `tooltip:` | Several |

---

## 5. Status colours

`StatusPill` takes a `StatusIntent`, and each domain maps its own strings:

```dart
StatusPill(label: user.status,      intent: StatusIntents.user(user.status))
StatusPill(label: payment.status,   intent: StatusIntents.payment(payment.status))
StatusPill(label: appeal.status,    intent: StatusIntents.violation(appeal.status))
```

The mapping lives per-domain in `StatusIntents` rather than in one global table,
because the domains genuinely disagree. An **appeal** that is `Dismissed` went
the admin's way; an **incident** that is `Dismissed` was closed without action.
A single string→colour map has to pick one and be wrong on the other screen —
which is precisely the bug the seven duplicated chip classes had.

**Adding a status:** add the case to the relevant `StatusIntents` method.
Anything unmapped falls through to `StatusIntent.neutral`, so a new value
arriving from the API shows as a grey pill rather than crashing the table.

**Adding a domain:** add a new static method to `StatusIntents`. Do not add a
new `_StatusChip`.

---

## 6. Recipes

### A new list screen

```dart
class SessionsScreen extends ConsumerWidget {
  const SessionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(sessionsProvider);

    return AppPage(
      title: 'Parking Sessions',
      subtitle: 'Every entry and exit recorded by the gates.',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
          onPressed: () => ref.invalidate(sessionsProvider),
        ),
      ],
      body: AsyncView(
        value: async,
        onRetry: () => ref.invalidate(sessionsProvider),
        isEmpty: (page) => page.items.isEmpty,
        empty: const AppEmptyState(
          icon: Icons.directions_car_outlined,
          title: 'No sessions yet',
          message: 'Sessions appear here as vehicles tap in at the gate.',
        ),
        data: (page) => AppDataTable(
          columns: const [
            DataColumn(label: Text('Plate')),
            DataColumn(label: Text('Slot')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Duration'), numeric: true),
          ],
          rows: [
            for (final s in page.items)
              DataRow(cells: [
                DataCell(AppPrimaryCell(title: s.plate, subtitle: s.ownerName)),
                DataCell(Text(s.slotCode)),
                DataCell(StatusPill(
                  label: s.status,
                  intent: StatusIntents.slot(s.status),
                  dense: true,
                )),
                DataCell(AppNumericCell(s.duration)),
              ]),
          ],
          footer: AppPagination(
            page: page.number,
            pageSize: page.size,
            total: page.total,
            itemLabel: 'sessions',
            onPage: (p) => ref.read(sessionsPageProvider.notifier).state = p,
          ),
        ),
      ),
    );
  }
}
```

Nothing in that screen names a colour, a font or a pixel gap — and it will pick
up dark mode for free.

### A new detail screen

```dart
AppPage(
  title: session.plate,
  subtitle: 'Session ${session.id}',
  scrollable: true,
  actions: [OutlinedButton(onPressed: ..., child: const Text('Close session'))],
  body: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      AppSectionCard(
        title: 'Session',
        icon: Icons.info_outline,
        child: AppFieldGrid(fields: [
          AppField(label: 'Plate', value: session.plate, emphasis: true),
          AppField(label: 'Slot', value: session.slotCode),
          AppField(
            label: 'Status',
            child: StatusPill(label: session.status, intent: StatusIntents.slot(session.status)),
          ),
          AppField(label: 'Entered', value: fmt(session.enteredAt)),
        ]),
      ),
      const SizedBox(height: AppSpacing.sectionGap),
      AppSectionCard(title: 'Payment', child: ...),
    ],
  ),
)
```

---

## 7. Changing the system

Work down the layers, and stop at the first one that answers the question.

1. **A component looks wrong everywhere** → fix its theme in `app_theme.dart`.
   One edit, every instance.
2. **A colour role is wrong** → fix the token in `app_tokens.dart`. Both
   brightnesses live side by side there; change them together.
3. **You need a hue that does not exist** → add the ramp to `app_palette.dart`,
   *then* give it a semantic name in `app_tokens.dart`. Never stop at step 3;
   a primitive with no semantic name is unusable by design.
4. **You need a new reusable widget** → add it to `widgets/ui/` and export it
   from `ui.dart`. Every private `_StatusChip` in this codebase began life as a
   one-screen convenience.

### Adding a token

Ask: *would two unrelated screens both want this?* If yes it is a token. If no
it is a local constant, and it belongs in the screen file.

Name it for its **role**, never its appearance. `t.text.secondary` survives a
rebrand; `t.text.grey` does not.

### Dark mode

Already built — `AppTokens.dark` and `AppTheme.dark()` are complete, and
`main.dart` passes both themes. It is pinned to `ThemeMode.light` only because
the navigation shell still hardcodes white-on-slate. Once the shell reads
`t.surface.sidebar` and `t.text.inverse`, switch `themeMode` to
`ThemeMode.system` and the whole panel follows.

Any screen built with tokens from day one needs no dark-mode work at all.

---

## 8. Status of the migration

**Done** — the token layer, the Material component defaults, the component kit,
and `main.dart` wired to `AppTheme`.

**Not yet** — the ten existing screens still carry their original hardcoded
colours and private widgets; `widgets/admin_shell.dart` still hardcodes the
sidebar; `widgets/page_header.dart` is superseded by `AppPageHeader` but is
still what the screens import.

None of that is broken — the old code renders fine under the new theme, it is
just not yet reading tokens. The migration order is cheapest-first so the
pattern is proven before the expensive screens:

1. `pending_registrations` (134 lines — the template)
2. `user_management`, `payments`, `audit_log` (same table shape)
3. `admin_shell` (the sidebar — highest visual payoff)
4. `violations` (728 lines), `parking` (586), `reports` (347)
5. Detail screens, `policy_rules`, `incidents`, `notifications`, `login`

**New features should use the system from the start**, regardless of where that
migration has reached. There is no reason to write a screen twice.
