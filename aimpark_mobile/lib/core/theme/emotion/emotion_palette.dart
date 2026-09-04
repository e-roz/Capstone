import 'package:flutter/material.dart';

/// LAYER 1 — Primitives for the emotional design system.
///
/// Raw hex values with no meaning attached, taken verbatim from
/// `MD files/aim-park-design-system-brief.md` §3. Nothing outside
/// `emotion_tokens.dart` may import this file — screens speak [EmotionTokens],
/// never a hex value, so the palette can be retuned in one place.
///
/// This is a second, parallel primitive layer to `app_palette.dart`. The two
/// are not meant to mix: `AppPalette` is the existing gamified theme's warm
/// orange register, this is the calm asphalt-and-sodium-lamp register the
/// brief specifies for outdoor, in-vehicle, one-handed use. A screen that
/// pulls colours from both will look like two different products stitched
/// together.
abstract class EmotionPalette {
  EmotionPalette._();

  // ── Base ──────────────────────────────────────────────────────────────────
  static const asphalt = Color(0xFF23262B);
  static const raised = Color(0xFF2E3238);
  static const paintWhite = Color(0xFFF2F4F1);
  static const paintMuted = Color(0xFFA3A9A6);
  static const signalBlue = Color(0xFF2F6FD0);

  // ── Availability confidence ──────────────────────────────────────────────
  static const availOpen = Color(0xFF1E9E5A);
  static const availFilling = Color(0xFFE08A18);
  static const availFull = Color(0xFFC0492F);
}
