import 'package:flutter/material.dart';

/// A duration paired with the curve it always plays with. Motion in this
/// system is never a bare `Duration` or a bare `Curve` at the call site —
/// the two are chosen together, so the token bundles them together.
@immutable
class MotionSpec {
  const MotionSpec(this.duration, this.curve);

  final Duration duration;
  final Curve curve;
}

/// LAYER 2 — Motion, brief §5.
///
/// One curve for the whole system — firm ease-out, no bounce — with exactly
/// one deliberate exception. [gate] is the only overshoot in the entire app,
/// reserved for the gate-open confirmation. Reusing it anywhere else
/// (a toggle, a snackbar, a list item) destroys the one moment it exists to
/// mark — don't.
@immutable
class EmotionMotionTokens {
  const EmotionMotionTokens({
    required this.micro,
    required this.standard,
    required this.gate,
  });

  /// Taps, toggles, state flips.
  final MotionSpec micro;

  /// Transitions, sheets, map updates.
  final MotionSpec standard;

  /// The gate-open confirmation. Nowhere else — see class doc.
  final MotionSpec gate;

  static const instance = EmotionMotionTokens(
    micro: MotionSpec(Duration(milliseconds: 120), Curves.easeOutCubic),
    standard: MotionSpec(Duration(milliseconds: 200), Curves.easeOutCubic),
    gate: MotionSpec(Duration(milliseconds: 380), Curves.easeOutBack),
  );

  EmotionMotionTokens lerp(EmotionMotionTokens? other, double t) {
    if (other == null) return this;
    // None of these three specs vary between instances today — there is only
    // one palette in this system — so there is nothing meaningful to
    // interpolate. Snap at the midpoint rather than fabricate an in-between
    // curve, matching how Flutter itself treats non-interpolatable
    // ThemeExtension fields.
    return t < 0.5 ? this : other;
  }
}
