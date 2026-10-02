import 'package:flutter/material.dart';

import 'emotion_haptics.dart';
import 'emotion_motion.dart';
import 'emotion_palette.dart';
import 'emotion_typography.dart';

/// LAYER 2 — The emotional design system's token bundle, brief §3–§6.
///
/// A second, additive `ThemeExtension` alongside the app's existing
/// [AppTokens][app_tokens.dart]. It does not replace that system and nothing
/// about it changes for the ~30 screens that already read `context.tokens` —
/// this exists purely for the small set of "peak emotional moment" surfaces
/// the brief calls out: the gate feedback view, the failure/alternative
/// card, and whatever from brief §8 comes after them.
///
/// Read it with `context.emotion`:
///
/// ```dart
/// final e = context.emotion;
/// Container(color: e.surface.asphalt, child: Text('B-14', style: e.typography.slotId));
/// ```
///
/// Unlike [AppTokens] this has exactly one instance, not a light/dark pair —
/// the brief's palette is a single fixed dark theme tuned for direct
/// sunlight, not something that should invert with the phone's system
/// setting (brief §3 note on outdoor legibility, §9 accessibility floor).
@immutable
class EmotionTokens extends ThemeExtension<EmotionTokens> {
  const EmotionTokens({
    required this.surface,
    required this.paint,
    required this.signal,
    required this.avail,
    required this.typography,
    required this.motion,
    required this.haptic,
  });

  final EmotionSurfaceTokens surface;
  final EmotionPaintTokens paint;
  final EmotionSignalTokens signal;

  /// Availability confidence colours. **Status only — never an interactive
  /// element.** Never use [avail] for a confirm button, a link, or any
  /// tappable control; interactive intent is always [signal]. Green-for-open
  /// next to green-for-confirm is exactly the ambiguity this rule exists to
  /// prevent — see brief §3, "Hard rule".
  final EmotionAvailTokens avail;

  /// The type scale (brief §4). Named `typography`, not `type` — [type] is
  /// already taken by [ThemeExtension] itself, which uses it internally for
  /// extension lookup.
  final EmotionTypeTokens typography;

  final EmotionMotionTokens motion;
  final EmotionHapticTokens haptic;

  static const instance = EmotionTokens(
    surface: EmotionSurfaceTokens.instance,
    paint: EmotionPaintTokens.instance,
    signal: EmotionSignalTokens.instance,
    avail: EmotionAvailTokens.instance,
    typography: EmotionTypeTokens.instance,
    motion: EmotionMotionTokens.instance,
    haptic: EmotionHapticTokens.instance,
  );

  @override
  EmotionTokens copyWith({
    EmotionSurfaceTokens? surface,
    EmotionPaintTokens? paint,
    EmotionSignalTokens? signal,
    EmotionAvailTokens? avail,
    EmotionTypeTokens? typography,
    EmotionMotionTokens? motion,
    EmotionHapticTokens? haptic,
  }) {
    return EmotionTokens(
      surface: surface ?? this.surface,
      paint: paint ?? this.paint,
      signal: signal ?? this.signal,
      avail: avail ?? this.avail,
      typography: typography ?? this.typography,
      motion: motion ?? this.motion,
      haptic: haptic ?? this.haptic,
    );
  }

  @override
  EmotionTokens lerp(covariant EmotionTokens? other, double t) {
    if (other == null) return this;
    return EmotionTokens(
      surface: EmotionSurfaceTokens.lerp(surface, other.surface, t),
      paint: EmotionPaintTokens.lerp(paint, other.paint, t),
      signal: EmotionSignalTokens.lerp(signal, other.signal, t),
      avail: EmotionAvailTokens.lerp(avail, other.avail, t),
      typography: typography.lerp(other.typography, t),
      motion: motion.lerp(other.motion, t),
      haptic: t < 0.5 ? haptic : other.haptic,
    );
  }
}

/// Reads [EmotionTokens] off the nearest theme.
extension EmotionTokensContext on BuildContext {
  /// The emotional design system's tokens. Non-null by construction: both
  /// [AppTheme.light] and [AppTheme.dark] register [EmotionTokens.instance]
  /// alongside the app's own [AppTokens].
  EmotionTokens get emotion => Theme.of(this).extension<EmotionTokens>()!;
}

// ── Surfaces ────────────────────────────────────────────────────────────────

@immutable
class EmotionSurfaceTokens {
  const EmotionSurfaceTokens({required this.asphalt, required this.raised});

  /// Primary dark surface, map background.
  final Color asphalt;

  /// Cards, sheets on dark.
  final Color raised;

  static const instance = EmotionSurfaceTokens(
    asphalt: EmotionPalette.asphalt,
    raised: EmotionPalette.raised,
  );

  static EmotionSurfaceTokens lerp(
    EmotionSurfaceTokens a,
    EmotionSurfaceTokens b,
    double t,
  ) {
    return EmotionSurfaceTokens(
      asphalt: Color.lerp(a.asphalt, b.asphalt, t)!,
      raised: Color.lerp(a.raised, b.raised, t)!,
    );
  }
}

// ── Paint (text / markings) ────────────────────────────────────────────────

@immutable
class EmotionPaintTokens {
  const EmotionPaintTokens({required this.white, required this.muted});

  /// Primary text on dark, lot markings.
  final Color white;

  /// Secondary text, inactive markings.
  final Color muted;

  static const instance = EmotionPaintTokens(
    white: EmotionPalette.paintWhite,
    muted: EmotionPalette.paintMuted,
  );

  static EmotionPaintTokens lerp(
    EmotionPaintTokens a,
    EmotionPaintTokens b,
    double t,
  ) {
    return EmotionPaintTokens(
      white: Color.lerp(a.white, b.white, t)!,
      muted: Color.lerp(a.muted, b.muted, t)!,
    );
  }
}

// ── Signal (interactive intent) ────────────────────────────────────────────

@immutable
class EmotionSignalTokens {
  const EmotionSignalTokens({required this.blue});

  /// All interactive elements — buttons, links, controls. The *only* colour
  /// that means "tap this" in this system; see [EmotionTokens.avail].
  final Color blue;

  static const instance = EmotionSignalTokens(blue: EmotionPalette.signalBlue);

  static EmotionSignalTokens lerp(
    EmotionSignalTokens a,
    EmotionSignalTokens b,
    double t,
  ) {
    return EmotionSignalTokens(blue: Color.lerp(a.blue, b.blue, t)!);
  }
}

// ── Availability confidence ─────────────────────────────────────────────────

/// Status colours only. **Never bind these to a `GestureDetector`, a button,
/// a link, or any other tappable widget** — see [EmotionTokens.avail]. If a
/// screen needs a green or red *action*, that is a sign the action should not
/// exist; a red state gets an alternative (the failure card), never a red
/// button.
@immutable
class EmotionAvailTokens {
  const EmotionAvailTokens({
    required this.open,
    required this.filling,
    required this.full,
  });

  /// Comfortable — plenty of space.
  final Color open;

  /// Filling up — the emotional state; user decides whether to hurry. The
  /// most important state in the system; see brief §3.
  final Color filling;

  /// Full — muted brick, not alarm red.
  final Color full;

  static const instance = EmotionAvailTokens(
    open: EmotionPalette.availOpen,
    filling: EmotionPalette.availFilling,
    full: EmotionPalette.availFull,
  );

  static EmotionAvailTokens lerp(
    EmotionAvailTokens a,
    EmotionAvailTokens b,
    double t,
  ) {
    return EmotionAvailTokens(
      open: Color.lerp(a.open, b.open, t)!,
      filling: Color.lerp(a.filling, b.filling, t)!,
      full: Color.lerp(a.full, b.full, t)!,
    );
  }
}
