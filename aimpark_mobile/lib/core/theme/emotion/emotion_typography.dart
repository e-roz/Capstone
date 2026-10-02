import 'package:flutter/material.dart';

/// LAYER 1 + 2 — Type scale, brief §4.
///
/// Single family (Barlow), weight-differentiated, chosen because it descends
/// from American road signage and gives clean, unambiguous numerals for slot
/// IDs and counts. [EmotionFontFamily.condensed] (Barlow Semi Condensed) is
/// used only for the two large numerals, where horizontal space is tight and
/// the number must dominate — every other role stays on the regular width.
///
/// Styles carry no colour: pair with [EmotionTokens.paint] at the call site
/// (`emotion.type.body.copyWith(color: emotion.paint.white)`), the same way
/// the type scale is layered under colour everywhere else in this codebase.
/// The brief does not specify line-heights, so none are set here — each style
/// uses the font's own natural leading rather than an invented number.
abstract class EmotionFontFamily {
  EmotionFontFamily._();

  static const regular = 'Barlow';
  static const condensed = 'BarlowSemiCondensed';
}

@immutable
class EmotionTypeTokens {
  const EmotionTypeTokens({
    required this.slotCount,
    required this.slotId,
    required this.screenTitle,
    required this.sectionHeading,
    required this.body,
    required this.caption,
  });

  /// The hero number on the availability screen. 48/600, Semi Condensed.
  final TextStyle slotCount;

  /// e.g. "B-14". 32/600, Semi Condensed.
  final TextStyle slotId;

  /// 24/600, regular width.
  final TextStyle screenTitle;

  /// 18/600, regular width.
  final TextStyle sectionHeading;

  /// 16/400. Minimum body size — outdoor legibility.
  final TextStyle body;

  /// 14/400. Never smaller than this anywhere in the app.
  final TextStyle caption;

  static const instance = EmotionTypeTokens(
    slotCount: TextStyle(
      fontFamily: EmotionFontFamily.condensed,
      fontSize: 48,
      fontWeight: FontWeight.w600,
    ),
    slotId: TextStyle(
      fontFamily: EmotionFontFamily.condensed,
      fontSize: 32,
      fontWeight: FontWeight.w600,
    ),
    screenTitle: TextStyle(
      fontFamily: EmotionFontFamily.regular,
      fontSize: 24,
      fontWeight: FontWeight.w600,
    ),
    sectionHeading: TextStyle(
      fontFamily: EmotionFontFamily.regular,
      fontSize: 18,
      fontWeight: FontWeight.w600,
    ),
    body: TextStyle(
      fontFamily: EmotionFontFamily.regular,
      fontSize: 16,
      fontWeight: FontWeight.w400,
    ),
    caption: TextStyle(
      fontFamily: EmotionFontFamily.regular,
      fontSize: 14,
      fontWeight: FontWeight.w400,
    ),
  );

  EmotionTypeTokens lerp(EmotionTypeTokens? other, double t) {
    if (other == null) return this;
    return EmotionTypeTokens(
      slotCount: TextStyle.lerp(slotCount, other.slotCount, t)!,
      slotId: TextStyle.lerp(slotId, other.slotId, t)!,
      screenTitle: TextStyle.lerp(screenTitle, other.screenTitle, t)!,
      sectionHeading: TextStyle.lerp(sectionHeading, other.sectionHeading, t)!,
      body: TextStyle.lerp(body, other.body, t)!,
      caption: TextStyle.lerp(caption, other.caption, t)!,
    );
  }
}
