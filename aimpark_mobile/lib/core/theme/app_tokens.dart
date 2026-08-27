import 'package:flutter/material.dart';

import 'app_palette.dart';

/// LAYER 2 — Semantic tokens.
///
/// This is the only colour vocabulary screens are allowed to speak. A token
/// names a *role* ("the canvas behind a page", "the text you read second")
/// rather than a hue, which is what lets the whole app switch to dark mode, or
/// change brand colour, by editing this one file.
///
/// Tokens are carried on [ThemeData.extensions] rather than as `static const`
/// so they resolve per-brightness through the widget tree. Read them with
/// `context.tokens`:
///
/// ```dart
/// final t = context.tokens;
/// AppCard(color: t.surface.card, child: Text('Hi', style: TextStyle(color: t.text.primary)));
/// ```
///
/// The names here match `aimpark_admin/lib/theme/app_tokens.dart` deliberately.
/// The two apps look different on purpose — this one is a phone app with a
/// playful register, that one is a dense desk tool — but `t.surface.canvas`,
/// `t.text.secondary` and `t.status.of(intent)` mean the same thing in both, so
/// moving between the codebases costs nothing.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.surface,
    required this.text,
    required this.border,
    required this.brand,
    required this.accent,
    required this.tertiary,
    required this.status,
  });

  final AppSurfaceTokens surface;
  final AppTextTokens text;
  final AppBorderTokens border;

  /// Orange. Primary actions, the active nav pill, the points counter.
  final AppAccentTokens brand;

  /// Sky blue. Secondary actions and anything informational.
  final AppAccentTokens accent;

  /// Amber. The streak hue — deliberately a third colour rather than a second
  /// brand, so "you have a streak" never reads as "this is a button".
  final AppAccentTokens tertiary;

  final AppStatusTokens status;

  static const light = AppTokens(
    surface: AppSurfaceTokens.light,
    text: AppTextTokens.light,
    border: AppBorderTokens.light,
    brand: AppAccentTokens.brandLight,
    accent: AppAccentTokens.accentLight,
    tertiary: AppAccentTokens.tertiaryLight,
    status: AppStatusTokens.light,
  );

  static const dark = AppTokens(
    surface: AppSurfaceTokens.dark,
    text: AppTextTokens.dark,
    border: AppBorderTokens.dark,
    brand: AppAccentTokens.brandDark,
    accent: AppAccentTokens.accentDark,
    tertiary: AppAccentTokens.tertiaryDark,
    status: AppStatusTokens.dark,
  );

  @override
  AppTokens copyWith({
    AppSurfaceTokens? surface,
    AppTextTokens? text,
    AppBorderTokens? border,
    AppAccentTokens? brand,
    AppAccentTokens? accent,
    AppAccentTokens? tertiary,
    AppStatusTokens? status,
  }) {
    return AppTokens(
      surface: surface ?? this.surface,
      text: text ?? this.text,
      border: border ?? this.border,
      brand: brand ?? this.brand,
      accent: accent ?? this.accent,
      tertiary: tertiary ?? this.tertiary,
      status: status ?? this.status,
    );
  }

  @override
  AppTokens lerp(covariant AppTokens? other, double t) {
    if (other == null) return this;
    return AppTokens(
      surface: AppSurfaceTokens.lerp(surface, other.surface, t),
      text: AppTextTokens.lerp(text, other.text, t),
      border: AppBorderTokens.lerp(border, other.border, t),
      brand: AppAccentTokens.lerp(brand, other.brand, t),
      accent: AppAccentTokens.lerp(accent, other.accent, t),
      tertiary: AppAccentTokens.lerp(tertiary, other.tertiary, t),
      status: AppStatusTokens.lerp(status, other.status, t),
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

  /// The type scale. Shorthand for `Theme.of(context).textTheme`, which every
  /// screen now needs on nearly every line: styles carry no colour of their
  /// own any more, so they have to be read from the theme rather than from a
  /// `static` that baked in the light-mode ink.
  TextTheme get text => Theme.of(this).textTheme;

  /// True when the app is rendering its dark theme. Only for the handful of
  /// places where a token cannot express the difference — swapping an asset,
  /// choosing a blend mode. Reach for a token first.
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}

/// Colours that are deliberately the same in both themes, because something
/// outside Flutter has to match them.
///
/// This is the only sanctioned way past the token layer, and it exists so the
/// splash screen does not have to import `app_palette.dart` — which would open
/// the door to every screen doing the same.
abstract class AppFixedColors {
  /// The launch canvas. Matched by the native Android splash and by the
  /// adaptive icon's background, neither of which knows what a theme is, so a
  /// dark-mode variant here would show as a colour flash on cold start.
  static const splashBackground = AppPalette.splashOrange;
}

// ── Surfaces ────────────────────────────────────────────────────────────────

/// Backgrounds, from the furthest-back canvas to the closest-forward overlay.
@immutable
class AppSurfaceTokens {
  const AppSurfaceTokens({
    required this.canvas,
    required this.card,
    required this.muted,
    required this.pressed,
    required this.inverse,
    required this.overlay,
    required this.scrim,
  });

  /// The page background behind all cards.
  final Color canvas;

  /// Cards, sheets, the bottom nav — anything sitting on the canvas.
  final Color card;

  /// Inset wells: the round icon chip on a list row, a progress track, a
  /// skeleton placeholder, a disabled button.
  final Color muted;

  /// A card's fill while the thumb is down.
  final Color pressed;

  /// A block that is dark in light mode and light in dark mode — snackbars and
  /// tooltips. Pair with [AppTextTokens.inverse].
  final Color inverse;

  /// Dialogs and menus. Lifted one step off [card] in dark mode, where a
  /// shadow alone cannot separate two dark surfaces.
  final Color overlay;

  /// Dimming behind a modal.
  final Color scrim;

  static const light = AppSurfaceTokens(
    canvas: AppPalette.neutral50,
    card: AppPalette.neutral0,
    muted: AppPalette.neutral100,
    pressed: AppPalette.neutral100,
    inverse: AppPalette.neutral900,
    overlay: AppPalette.neutral0,
    scrim: Color(0x800A0A0A),
  );

  static const dark = AppSurfaceTokens(
    canvas: AppPalette.neutral950,
    card: AppPalette.neutral900,
    muted: AppPalette.neutral800,
    pressed: AppPalette.neutral800,
    inverse: AppPalette.neutral100,
    overlay: AppPalette.neutral800,
    scrim: Color(0xB3000000),
  );

  static AppSurfaceTokens lerp(
      AppSurfaceTokens a, AppSurfaceTokens b, double t) {
    return AppSurfaceTokens(
      canvas: Color.lerp(a.canvas, b.canvas, t)!,
      card: Color.lerp(a.card, b.card, t)!,
      muted: Color.lerp(a.muted, b.muted, t)!,
      pressed: Color.lerp(a.pressed, b.pressed, t)!,
      inverse: Color.lerp(a.inverse, b.inverse, t)!,
      overlay: Color.lerp(a.overlay, b.overlay, t)!,
      scrim: Color.lerp(a.scrim, b.scrim, t)!,
    );
  }
}

// ── Text ────────────────────────────────────────────────────────────────────

/// Foreground colours, ordered by how much attention they should attract.
@immutable
class AppTextTokens {
  const AppTextTokens({
    required this.primary,
    required this.secondary,
    required this.disabled,
    required this.inverse,
    required this.onDark,
    required this.onDarkMuted,
  });

  /// Headings, values, anything read first.
  final Color primary;

  /// Labels, timestamps, helper text, placeholders.
  final Color secondary;

  final Color disabled;

  /// Text on [AppSurfaceTokens.inverse] — a surface that flips with the theme,
  /// such as a snackbar. **Not** the camera screen; see [onDark].
  final Color inverse;

  /// Text on a surface that is dark in **both** themes: the camera viewfinder,
  /// the splash screen, the scrim over a captured photo.
  ///
  /// [inverse] cannot do this job. It means "the opposite of the current
  /// theme's text", so it is white in light mode and *dark* in dark mode. On a
  /// surface that stays dark either way that renders dark-on-dark and the text
  /// disappears.
  final Color onDark;

  final Color onDarkMuted;

  static const light = AppTextTokens(
    primary: AppPalette.neutral900,
    secondary: AppPalette.neutral500,
    disabled: AppPalette.neutral400,
    inverse: AppPalette.neutral0,
    onDark: AppPalette.neutral0,
    onDarkMuted: Color(0xB3FFFFFF),
  );

  static const dark = AppTextTokens(
    primary: AppPalette.neutral50,
    secondary: AppPalette.neutral400,
    disabled: AppPalette.neutral600,
    inverse: AppPalette.neutral900,
    // Identical to the light theme on purpose: the surfaces these sit on do
    // not change between themes, so neither should the text.
    onDark: AppPalette.neutral0,
    onDarkMuted: Color(0xB3FFFFFF),
  );

  static AppTextTokens lerp(AppTextTokens a, AppTextTokens b, double t) {
    return AppTextTokens(
      primary: Color.lerp(a.primary, b.primary, t)!,
      secondary: Color.lerp(a.secondary, b.secondary, t)!,
      disabled: Color.lerp(a.disabled, b.disabled, t)!,
      inverse: Color.lerp(a.inverse, b.inverse, t)!,
      onDark: Color.lerp(a.onDark, b.onDark, t)!,
      onDarkMuted: Color.lerp(a.onDarkMuted, b.onDarkMuted, t)!,
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
  });

  /// Dividers — barely there on purpose.
  final Color subtle;

  /// Card and input outlines. These carry real weight in this app: cards are
  /// drawn with a 1.5px border and no shadow, so this token is the only thing
  /// separating a card from the canvas.
  final Color normal;

  /// A pressed card, an emphasised separator.
  final Color strong;

  /// The focus ring on an input. Never remove it; recolour it if you must.
  final Color focus;

  static const light = AppBorderTokens(
    subtle: AppPalette.neutral100,
    normal: AppPalette.neutral200,
    strong: AppPalette.neutral400,
    focus: AppPalette.orange500,
  );

  static const dark = AppBorderTokens(
    subtle: AppPalette.neutral800,
    normal: AppPalette.neutral700,
    strong: AppPalette.neutral500,
    focus: AppPalette.orange400,
  );

  static AppBorderTokens lerp(AppBorderTokens a, AppBorderTokens b, double t) {
    return AppBorderTokens(
      subtle: Color.lerp(a.subtle, b.subtle, t)!,
      normal: Color.lerp(a.normal, b.normal, t)!,
      strong: Color.lerp(a.strong, b.strong, t)!,
      focus: Color.lerp(a.focus, b.focus, t)!,
    );
  }
}

// ── Accents ─────────────────────────────────────────────────────────────────

/// One hue's worth of roles: the solid fill, the darker layer under it, the
/// tint, and the two foregrounds that have to stay readable on each.
///
/// Three instances of this class carry the app's three hues ([AppTokens.brand],
/// [AppTokens.accent], [AppTokens.tertiary]) so a component can be handed "the
/// amber one" without knowing which hue that is.
///
/// The admin panel's equivalent has a `hover` role. There is no hover on a
/// phone, so it is deliberately absent here rather than defined and unused.
@immutable
class AppAccentTokens {
  const AppAccentTokens({
    required this.primary,
    required this.pressed,
    required this.subtle,
    required this.subtleText,
    required this.onSolid,
  });

  /// The solid fill: a primary button, the parking status card.
  final Color primary;

  /// The layer sitting behind [primary] in the two-layer button press, and the
  /// fill once the thumb is down. Must be darker than [primary] or the button
  /// reads as lit rather than as pushed.
  final Color pressed;

  /// Tinted background for chips, badges and selected states.
  final Color subtle;

  /// Text and icons sitting on [subtle].
  final Color subtleText;

  /// Text and icons sitting on [primary]. Per-hue rather than one global
  /// "on brand" colour, because white on amber fails contrast where white on
  /// orange passes.
  final Color onSolid;

  static const brandLight = AppAccentTokens(
    primary: AppPalette.orange500,
    pressed: AppPalette.orange600,
    subtle: AppPalette.orange100,
    subtleText: AppPalette.orange700,
    onSolid: AppPalette.neutral0,
  );

  static const brandDark = AppAccentTokens(
    primary: AppPalette.orange500,
    pressed: AppPalette.orange700,
    // A low-alpha wash of the hue rather than a tint from the ramp: orange-100
    // on a near-black canvas is a glowing slab, and every chip on the screen
    // becomes the brightest thing on it.
    subtle: Color(0x33F97316),
    subtleText: AppPalette.orange300,
    onSolid: AppPalette.neutral0,
  );

  static const accentLight = AppAccentTokens(
    primary: AppPalette.sky500,
    pressed: AppPalette.sky600,
    subtle: AppPalette.sky100,
    subtleText: AppPalette.sky700,
    onSolid: AppPalette.neutral0,
  );

  static const accentDark = AppAccentTokens(
    primary: AppPalette.sky500,
    pressed: AppPalette.sky700,
    subtle: Color(0x330EA5E9),
    subtleText: AppPalette.sky300,
    onSolid: AppPalette.neutral0,
  );

  static const tertiaryLight = AppAccentTokens(
    primary: AppPalette.amber500,
    pressed: AppPalette.amber600,
    subtle: AppPalette.amber100,
    subtleText: AppPalette.amber700,
    // Dark, unlike the other two: amber-500 is bright enough that white on it
    // fails contrast at label sizes.
    onSolid: AppPalette.neutral900,
  );

  static const tertiaryDark = AppAccentTokens(
    primary: AppPalette.amber500,
    pressed: AppPalette.amber700,
    subtle: Color(0x33F59E0B),
    subtleText: AppPalette.amber300,
    onSolid: AppPalette.neutral900,
  );

  static AppAccentTokens lerp(AppAccentTokens a, AppAccentTokens b, double t) {
    return AppAccentTokens(
      primary: Color.lerp(a.primary, b.primary, t)!,
      pressed: Color.lerp(a.pressed, b.pressed, t)!,
      subtle: Color.lerp(a.subtle, b.subtle, t)!,
      subtleText: Color.lerp(a.subtleText, b.subtleText, t)!,
      onSolid: Color.lerp(a.onSolid, b.onSolid, t)!,
    );
  }
}

// ── Status ──────────────────────────────────────────────────────────────────

/// The four colours a status needs: a tinted background, readable text on that
/// tint, a border, and a solid version for dots and filled chips.
///
/// Keeping them together is what stops the "green text on a green background
/// you cannot read" bug — the pairing is decided once, here.
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
/// Domains disagree about what a word means — a *violation* that is `Dismissed`
/// is good news for the user, an *incident* that is `Dismissed` is not — so the
/// mapping from a domain's string to an intent lives with that domain, in
/// `StatusIntents`, never inside the badge widget.
enum StatusIntent { neutral, info, success, warning, danger, brand }

@immutable
class AppStatusTokens {
  const AppStatusTokens({
    required this.neutral,
    required this.info,
    required this.success,
    required this.warning,
    required this.danger,
    required this.brand,
  });

  final StatusColors neutral;
  final StatusColors info;
  final StatusColors success;
  final StatusColors warning;
  final StatusColors danger;
  final StatusColors brand;

  StatusColors of(StatusIntent intent) => switch (intent) {
        StatusIntent.neutral => neutral,
        StatusIntent.info => info,
        StatusIntent.success => success,
        StatusIntent.warning => warning,
        StatusIntent.danger => danger,
        StatusIntent.brand => brand,
      };

  static const light = AppStatusTokens(
    neutral: StatusColors(
      bg: AppPalette.neutral100,
      fg: AppPalette.neutral600,
      border: AppPalette.neutral200,
      solid: AppPalette.neutral500,
    ),
    info: StatusColors(
      bg: AppPalette.sky100,
      fg: AppPalette.sky700,
      border: AppPalette.sky200,
      solid: AppPalette.sky500,
    ),
    success: StatusColors(
      bg: AppPalette.green100,
      fg: AppPalette.green700,
      border: AppPalette.green200,
      solid: AppPalette.green500,
    ),
    warning: StatusColors(
      bg: AppPalette.amber100,
      fg: AppPalette.amber700,
      border: AppPalette.amber200,
      solid: AppPalette.amber500,
    ),
    danger: StatusColors(
      bg: AppPalette.red100,
      fg: AppPalette.red700,
      border: AppPalette.red200,
      solid: AppPalette.red500,
    ),
    brand: StatusColors(
      bg: AppPalette.orange100,
      fg: AppPalette.orange700,
      border: AppPalette.orange200,
      solid: AppPalette.orange500,
    ),
  );

  // On dark surfaces the tints invert: a low-alpha wash of the hue, with the
  // light end of the ramp carrying the text.
  static const dark = AppStatusTokens(
    neutral: StatusColors(
      bg: Color(0x1FA3A3A3),
      fg: AppPalette.neutral300,
      border: Color(0x3DA3A3A3),
      solid: AppPalette.neutral400,
    ),
    info: StatusColors(
      bg: Color(0x2438BDF8),
      fg: AppPalette.sky200,
      border: Color(0x4D38BDF8),
      solid: AppPalette.sky400,
    ),
    success: StatusColors(
      bg: Color(0x244ADE80),
      fg: AppPalette.green200,
      border: Color(0x4D4ADE80),
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
    brand: StatusColors(
      bg: Color(0x24FB923C),
      fg: AppPalette.orange200,
      border: Color(0x4DFB923C),
      solid: AppPalette.orange400,
    ),
  );

  static AppStatusTokens lerp(AppStatusTokens a, AppStatusTokens b, double t) {
    return AppStatusTokens(
      neutral: StatusColors.lerp(a.neutral, b.neutral, t),
      info: StatusColors.lerp(a.info, b.info, t),
      success: StatusColors.lerp(a.success, b.success, t),
      warning: StatusColors.lerp(a.warning, b.warning, t),
      danger: StatusColors.lerp(a.danger, b.danger, t),
      brand: StatusColors.lerp(a.brand, b.brand, t),
    );
  }
}
