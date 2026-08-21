import 'package:flutter/material.dart';

import 'app_palette.dart';

/// LAYER 2 — Semantic tokens.
///
/// This is the only colour vocabulary screens are allowed to speak. A token
/// names a *role* ("the canvas behind a page", "the text you read second")
/// rather than a hue, which is what lets the whole panel switch to dark mode,
/// or change brand colour, by editing this one file.
///
/// Tokens are carried on [ThemeData.extensions] rather than as `static const`
/// so they resolve per-brightness through the widget tree. Read them with
/// `context.tokens`:
///
/// ```dart
/// final t = context.tokens;
/// Container(color: t.surface.card, child: Text('Hi', style: TextStyle(color: t.text.primary)));
/// ```
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.surface,
    required this.text,
    required this.border,
    required this.brand,
    required this.status,
    required this.chart,
  });

  final AppSurfaceTokens surface;
  final AppTextTokens text;
  final AppBorderTokens border;
  final AppBrandTokens brand;
  final AppStatusTokens status;
  final AppChartTokens chart;

  static const light = AppTokens(
    surface: AppSurfaceTokens.light,
    text: AppTextTokens.light,
    border: AppBorderTokens.light,
    brand: AppBrandTokens.light,
    status: AppStatusTokens.light,
    chart: AppChartTokens.light,
  );

  static const dark = AppTokens(
    surface: AppSurfaceTokens.dark,
    text: AppTextTokens.dark,
    border: AppBorderTokens.dark,
    brand: AppBrandTokens.dark,
    status: AppStatusTokens.dark,
    chart: AppChartTokens.dark,
  );

  @override
  AppTokens copyWith({
    AppSurfaceTokens? surface,
    AppTextTokens? text,
    AppBorderTokens? border,
    AppBrandTokens? brand,
    AppStatusTokens? status,
    AppChartTokens? chart,
  }) {
    return AppTokens(
      surface: surface ?? this.surface,
      text: text ?? this.text,
      border: border ?? this.border,
      brand: brand ?? this.brand,
      status: status ?? this.status,
      chart: chart ?? this.chart,
    );
  }

  @override
  AppTokens lerp(covariant AppTokens? other, double t) {
    if (other == null) return this;
    return AppTokens(
      surface: AppSurfaceTokens.lerp(surface, other.surface, t),
      text: AppTextTokens.lerp(text, other.text, t),
      border: AppBorderTokens.lerp(border, other.border, t),
      brand: AppBrandTokens.lerp(brand, other.brand, t),
      status: AppStatusTokens.lerp(status, other.status, t),
      chart: AppChartTokens.lerp(chart, other.chart, t),
    );
  }
}

/// Reads [AppTokens] off the nearest theme.
extension AppTokensContext on BuildContext {
  /// The semantic design tokens for the current theme.
  ///
  /// Non-null by construction — [AppTheme] always registers the extension — so
  /// a failure here means someone built a `ThemeData` by hand.
  AppTokens get tokens => Theme.of(this).extension<AppTokens>()!;
}

// ── Surfaces ────────────────────────────────────────────────────────────────

/// Backgrounds, from the furthest-back canvas to the closest-forward overlay.
@immutable
class AppSurfaceTokens {
  const AppSurfaceTokens({
    required this.canvas,
    required this.card,
    required this.muted,
    required this.hover,
    required this.selected,
    required this.inverse,
    required this.sidebar,
    required this.sidebarHover,
    required this.sidebarSelected,
    required this.overlay,
    required this.scrim,
  });

  /// The page background behind all cards.
  final Color canvas;

  /// Cards, tables, dialogs — anything sitting on the canvas.
  final Color card;

  /// Table headers, disabled fields, inset wells.
  final Color muted;

  /// Row and tile hover.
  final Color hover;

  /// Selected row or active tab background.
  final Color selected;

  /// A dark block on a light theme, used for emphasis tiles.
  final Color inverse;

  /// Navigation sidebar background.
  final Color sidebar;
  final Color sidebarHover;
  final Color sidebarSelected;

  /// Menus, tooltips and popovers.
  final Color overlay;

  /// Dimming behind a modal.
  final Color scrim;

  static const light = AppSurfaceTokens(
    canvas: Color(0xFFF5F7FA),
    card: AppPalette.neutral0,
    muted: AppPalette.neutral100,
    hover: AppPalette.neutral50,
    selected: AppPalette.brand50,
    inverse: AppPalette.neutral800,
    sidebar: AppPalette.neutral800,
    sidebarHover: Color(0x14FFFFFF),
    sidebarSelected: Color(0x24FFFFFF),
    overlay: AppPalette.neutral0,
    scrim: Color(0x800F172A),
  );

  static const dark = AppSurfaceTokens(
    canvas: AppPalette.neutral950,
    card: AppPalette.neutral900,
    muted: AppPalette.neutral800,
    hover: Color(0xFF16233B),
    selected: Color(0xFF1B2C4D),
    inverse: AppPalette.neutral100,
    sidebar: AppPalette.neutral900,
    sidebarHover: Color(0x14FFFFFF),
    sidebarSelected: Color(0x24FFFFFF),
    overlay: AppPalette.neutral800,
    scrim: Color(0xB3020617),
  );

  static AppSurfaceTokens lerp(
      AppSurfaceTokens a, AppSurfaceTokens b, double t) {
    return AppSurfaceTokens(
      canvas: Color.lerp(a.canvas, b.canvas, t)!,
      card: Color.lerp(a.card, b.card, t)!,
      muted: Color.lerp(a.muted, b.muted, t)!,
      hover: Color.lerp(a.hover, b.hover, t)!,
      selected: Color.lerp(a.selected, b.selected, t)!,
      inverse: Color.lerp(a.inverse, b.inverse, t)!,
      sidebar: Color.lerp(a.sidebar, b.sidebar, t)!,
      sidebarHover: Color.lerp(a.sidebarHover, b.sidebarHover, t)!,
      sidebarSelected: Color.lerp(a.sidebarSelected, b.sidebarSelected, t)!,
      overlay: Color.lerp(a.overlay, b.overlay, t)!,
      scrim: Color.lerp(a.scrim, b.scrim, t)!,
    );
  }
}

// ── Text ────────────────────────────────────────────────────────────────────

/// Foreground colours, ordered by how much attention they should attract.
///
/// The panel had `Colors.black54` scattered through it for secondary text;
/// [secondary] is that role, defined once.
@immutable
class AppTextTokens {
  const AppTextTokens({
    required this.primary,
    required this.secondary,
    required this.tertiary,
    required this.disabled,
    required this.inverse,
    required this.inverseMuted,
    required this.onDark,
    required this.onDarkMuted,
    required this.onDarkSubtle,
    required this.link,
    required this.onBrand,
  });

  /// Headings, table values, anything read first.
  final Color primary;

  /// Labels, timestamps, helper text.
  final Color secondary;

  /// Placeholders and de-emphasised metadata.
  final Color tertiary;

  final Color disabled;

  /// Text on [AppSurfaceTokens.inverse] — a surface that flips with the theme,
  /// such as a tooltip or a snackbar. **Not** the sidebar; see [onDark].
  final Color inverse;

  final Color inverseMuted;

  /// Text on a surface that is dark in **both** themes — the navigation
  /// sidebar and the login brand panel.
  ///
  /// [inverse] cannot do this job. It means "the opposite of the current
  /// theme's text", so it is white in light mode and *dark* in dark mode. On a
  /// surface that stays dark either way, that renders dark-on-dark and the text
  /// disappears — which is exactly what happened to the sidebar's workspace
  /// name, the account name and every selected nav label. Keep [inverse] for
  /// genuinely inverted surfaces (tooltips, snackbars) and use this for
  /// anything permanently dark.
  final Color onDark;

  final Color onDarkMuted;

  /// Between [onDark] and [onDarkMuted]. For text that is not the active item
  /// but still has to be readable at a glance — the unselected sidebar
  /// destinations, which at 70% white were reported as hard to notice.
  final Color onDarkSubtle;

  final Color link;

  /// Text on a filled brand button.
  final Color onBrand;

  static const light = AppTextTokens(
    primary: AppPalette.neutral900,
    secondary: AppPalette.neutral500,
    tertiary: AppPalette.neutral400,
    disabled: AppPalette.neutral300,
    inverse: AppPalette.neutral0,
    inverseMuted: Color(0xB3FFFFFF),
    onDark: AppPalette.neutral0,
    onDarkMuted: Color(0xB3FFFFFF),
    onDarkSubtle: Color(0xDBFFFFFF),
    link: AppPalette.brand600,
    onBrand: AppPalette.neutral0,
  );

  static const dark = AppTextTokens(
    primary: AppPalette.neutral50,
    secondary: AppPalette.neutral400,
    tertiary: AppPalette.neutral500,
    disabled: AppPalette.neutral600,
    inverse: AppPalette.neutral900,
    inverseMuted: Color(0xB3FFFFFF),
    // Identical to the light theme on purpose: the surfaces these sit on do not
    // change between themes, so neither should the text.
    onDark: AppPalette.neutral0,
    onDarkMuted: Color(0xB3FFFFFF),
    onDarkSubtle: Color(0xDBFFFFFF),
    link: AppPalette.brand400,
    onBrand: AppPalette.neutral0,
  );

  static AppTextTokens lerp(AppTextTokens a, AppTextTokens b, double t) {
    return AppTextTokens(
      primary: Color.lerp(a.primary, b.primary, t)!,
      secondary: Color.lerp(a.secondary, b.secondary, t)!,
      tertiary: Color.lerp(a.tertiary, b.tertiary, t)!,
      disabled: Color.lerp(a.disabled, b.disabled, t)!,
      inverse: Color.lerp(a.inverse, b.inverse, t)!,
      inverseMuted: Color.lerp(a.inverseMuted, b.inverseMuted, t)!,
      onDark: Color.lerp(a.onDark, b.onDark, t)!,
      onDarkMuted: Color.lerp(a.onDarkMuted, b.onDarkMuted, t)!,
      onDarkSubtle: Color.lerp(a.onDarkSubtle, b.onDarkSubtle, t)!,
      link: Color.lerp(a.link, b.link, t)!,
      onBrand: Color.lerp(a.onBrand, b.onBrand, t)!,
    );
  }
}

// ── Borders ─────────────────────────────────────────────────────────────────

@immutable
class AppBorderTokens {
  const AppBorderTokens({
    required this.subtle,
    required this.normal,
    required this.strong,
    required this.focus,
    required this.onSidebar,
  });

  /// Dividers between rows — barely there on purpose.
  final Color subtle;

  /// Card and input outlines.
  final Color normal;

  /// Hovered inputs and emphasised separators.
  final Color strong;

  /// The keyboard focus ring. Never remove it; recolour it if you must.
  final Color focus;

  final Color onSidebar;

  static const light = AppBorderTokens(
    subtle: AppPalette.neutral100,
    normal: AppPalette.neutral200,
    strong: AppPalette.neutral300,
    focus: AppPalette.brand500,
    onSidebar: Color(0x1FFFFFFF),
  );

  static const dark = AppBorderTokens(
    subtle: Color(0xFF1B283F),
    normal: AppPalette.neutral800,
    strong: AppPalette.neutral700,
    focus: AppPalette.brand400,
    onSidebar: Color(0x1FFFFFFF),
  );

  static AppBorderTokens lerp(AppBorderTokens a, AppBorderTokens b, double t) {
    return AppBorderTokens(
      subtle: Color.lerp(a.subtle, b.subtle, t)!,
      normal: Color.lerp(a.normal, b.normal, t)!,
      strong: Color.lerp(a.strong, b.strong, t)!,
      focus: Color.lerp(a.focus, b.focus, t)!,
      onSidebar: Color.lerp(a.onSidebar, b.onSidebar, t)!,
    );
  }
}

// ── Brand ───────────────────────────────────────────────────────────────────

@immutable
class AppBrandTokens {
  const AppBrandTokens({
    required this.primary,
    required this.hover,
    required this.pressed,
    required this.subtle,
    required this.subtleText,
  });

  /// Primary actions and the active-nav indicator.
  final Color primary;
  final Color hover;
  final Color pressed;

  /// Tinted background for selected states and ghost buttons.
  final Color subtle;

  /// Text sitting on [subtle].
  final Color subtleText;

  static const light = AppBrandTokens(
    primary: AppPalette.brand700,
    hover: AppPalette.brand800,
    pressed: AppPalette.brand900,
    subtle: AppPalette.brand50,
    subtleText: AppPalette.brand800,
  );

  static const dark = AppBrandTokens(
    primary: AppPalette.brand500,
    hover: AppPalette.brand400,
    pressed: AppPalette.brand300,
    subtle: Color(0xFF16294D),
    subtleText: AppPalette.brand200,
  );

  static AppBrandTokens lerp(AppBrandTokens a, AppBrandTokens b, double t) {
    return AppBrandTokens(
      primary: Color.lerp(a.primary, b.primary, t)!,
      hover: Color.lerp(a.hover, b.hover, t)!,
      pressed: Color.lerp(a.pressed, b.pressed, t)!,
      subtle: Color.lerp(a.subtle, b.subtle, t)!,
      subtleText: Color.lerp(a.subtleText, b.subtleText, t)!,
    );
  }
}

// ── Status ──────────────────────────────────────────────────────────────────

/// The three colours a status needs: a tinted background, readable text on that
/// tint, and a solid version for dots, bars and filled chips.
///
/// Keeping them together is what stops the "green text on green background you
/// can't read" bug — the pairing is decided once, here.
@immutable
class StatusColors {
  const StatusColors({
    required this.bg,
    required this.fg,
    required this.border,
    required this.solid,
  });

  final Color bg;
  final Color fg;
  final Color border;
  final Color solid;

  static StatusColors lerp(StatusColors a, StatusColors b, double t) {
    return StatusColors(
      bg: Color.lerp(a.bg, b.bg, t)!,
      fg: Color.lerp(a.fg, b.fg, t)!,
      border: Color.lerp(a.border, b.border, t)!,
      solid: Color.lerp(a.solid, b.solid, t)!,
    );
  }
}

/// Semantic intent of a piece of state, independent of which screen shows it.
///
/// Domains disagree about what a word means — an *appeal* that is `Dismissed`
/// is a win for the admin, an *incident* that is `Dismissed` is not — so the
/// mapping from a domain's string to an intent lives with that domain, in
/// `StatusIntents`, never inside the pill widget.
enum StatusIntent { neutral, info, success, warning, danger, accent }

@immutable
class AppStatusTokens {
  const AppStatusTokens({
    required this.neutral,
    required this.info,
    required this.success,
    required this.warning,
    required this.danger,
    required this.accent,
  });

  final StatusColors neutral;
  final StatusColors info;
  final StatusColors success;
  final StatusColors warning;
  final StatusColors danger;
  final StatusColors accent;

  StatusColors of(StatusIntent intent) => switch (intent) {
        StatusIntent.neutral => neutral,
        StatusIntent.info => info,
        StatusIntent.success => success,
        StatusIntent.warning => warning,
        StatusIntent.danger => danger,
        StatusIntent.accent => accent,
      };

  static const light = AppStatusTokens(
    neutral: StatusColors(
      bg: AppPalette.neutral100,
      fg: AppPalette.neutral600,
      border: AppPalette.neutral200,
      solid: AppPalette.neutral500,
    ),
    info: StatusColors(
      bg: AppPalette.sky50,
      fg: AppPalette.sky700,
      border: AppPalette.sky200,
      solid: AppPalette.sky600,
    ),
    success: StatusColors(
      bg: AppPalette.green50,
      fg: AppPalette.green700,
      border: AppPalette.green200,
      solid: AppPalette.green600,
    ),
    warning: StatusColors(
      bg: AppPalette.amber50,
      fg: AppPalette.amber700,
      border: AppPalette.amber200,
      solid: AppPalette.amber500,
    ),
    danger: StatusColors(
      bg: AppPalette.red50,
      fg: AppPalette.red700,
      border: AppPalette.red200,
      solid: AppPalette.red600,
    ),
    accent: StatusColors(
      bg: AppPalette.violet100,
      fg: AppPalette.violet700,
      border: AppPalette.violet400,
      solid: AppPalette.violet600,
    ),
  );

  // On dark surfaces the tints invert: a low-alpha wash of the hue, with the
  // light end of the ramp carrying the text.
  static const dark = AppStatusTokens(
    neutral: StatusColors(
      bg: Color(0x1F94A3B8),
      fg: AppPalette.neutral300,
      border: Color(0x3D94A3B8),
      solid: AppPalette.neutral400,
    ),
    info: StatusColors(
      bg: Color(0x2438BDF8),
      fg: AppPalette.sky200,
      border: Color(0x4D38BDF8),
      solid: AppPalette.sky400,
    ),
    success: StatusColors(
      bg: Color(0x2434D399),
      fg: AppPalette.green200,
      border: Color(0x4D34D399),
      solid: AppPalette.green400,
    ),
    warning: StatusColors(
      bg: Color(0x24FBBF24),
      fg: AppPalette.amber200,
      border: Color(0x4DFBBF24),
      solid: AppPalette.amber400,
    ),
    danger: StatusColors(
      bg: Color(0x24F87171),
      fg: AppPalette.red200,
      border: Color(0x4DF87171),
      solid: AppPalette.red400,
    ),
    accent: StatusColors(
      bg: Color(0x24A78BFA),
      fg: AppPalette.violet100,
      border: Color(0x4DA78BFA),
      solid: AppPalette.violet400,
    ),
  );

  static AppStatusTokens lerp(AppStatusTokens a, AppStatusTokens b, double t) {
    return AppStatusTokens(
      neutral: StatusColors.lerp(a.neutral, b.neutral, t),
      info: StatusColors.lerp(a.info, b.info, t),
      success: StatusColors.lerp(a.success, b.success, t),
      warning: StatusColors.lerp(a.warning, b.warning, t),
      danger: StatusColors.lerp(a.danger, b.danger, t),
      accent: StatusColors.lerp(a.accent, b.accent, t),
    );
  }
}

// ── Charts ──────────────────────────────────────────────────────────────────

/// A fixed categorical sequence for charts and legends.
///
/// Reports currently picks Material colours ad hoc, so the same series can
/// change colour between two charts on one screen. Always index into
/// [categorical] in order instead.
@immutable
class AppChartTokens {
  const AppChartTokens({required this.categorical, required this.grid});

  final List<Color> categorical;
  final Color grid;

  static const light = AppChartTokens(
    categorical: [
      AppPalette.brand600,
      AppPalette.teal500,
      AppPalette.violet500,
      AppPalette.amber500,
      AppPalette.sky500,
      AppPalette.green500,
      AppPalette.red500,
      AppPalette.neutral400,
    ],
    grid: AppPalette.neutral200,
  );

  static const dark = AppChartTokens(
    categorical: [
      AppPalette.brand400,
      AppPalette.teal500,
      AppPalette.violet400,
      AppPalette.amber400,
      AppPalette.sky400,
      AppPalette.green400,
      AppPalette.red400,
      AppPalette.neutral500,
    ],
    grid: AppPalette.neutral800,
  );

  /// Colour for series [index], wrapping if there are more series than colours.
  Color series(int index) => categorical[index % categorical.length];

  static AppChartTokens lerp(AppChartTokens a, AppChartTokens b, double t) {
    return AppChartTokens(
      categorical: [
        for (var i = 0; i < a.categorical.length; i++)
          Color.lerp(a.categorical[i], b.categorical[i], t)!,
      ],
      grid: Color.lerp(a.grid, b.grid, t)!,
    );
  }
}
