import 'package:flutter/material.dart';

/// LAYER 1 + 2 — Type scale.
///
/// Nine sizes, each mapped onto the Material [TextTheme] slot that Flutter's
/// own widgets already read. That mapping matters: because `bodyMedium` *is*
/// the 15px body style, an unstyled `Text` inside an `AlertDialog`, a
/// `SnackBar` or a `DatePicker` comes out correct without anyone passing a
/// `TextStyle`.
///
/// The scale is the one the app already had. What changed is where the colour
/// comes from: these used to be `static final` styles that baked in
/// `AppColors.textPrimary`, which is the single reason dark mode was
/// impossible — every heading in the app was hardcoded near-black. Colour is
/// now applied once, here, from the active theme's tokens.
abstract class AppTypography {
  /// Fredoka for display and headings — chunky, rounded, the closest
  /// freely-licensed match to Duolingo's proprietary Feather.
  static const String display = 'Fredoka';

  /// Nunito for body and labels — rounded to match, but drawn to stay legible
  /// at 12px where Fredoka starts to lose its counters.
  static const String body = 'Nunito';

  /// Both families are bundled under `assets/fonts/` and declared in
  /// `pubspec.yaml` rather than fetched at runtime by `google_fonts`.
  ///
  /// The package downloads its faces from Google's CDN on first use and falls
  /// back to Roboto if that fetch fails — silently, with no error. A fresh
  /// install in a defence room with no working Wi-Fi would therefore have
  /// rendered the entire app in the wrong typeface, and nobody would have found
  /// out until it was on the projector.
  static TextStyle _display(TextStyle style) =>
      style.copyWith(fontFamily: display);

  static TextStyle _body(TextStyle style) => style.copyWith(fontFamily: body);

  /// Digits that line up in a column. Use for money, points, counts and
  /// anything that changes in place — without it a ticking duration or an
  /// animating points total visibly wobbles.
  static TextStyle tabular(TextStyle style) =>
      style.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

  /// The full scale, in one place.
  ///
  /// [primary] colours everything except [secondary], which carries the two
  /// muted roles the app reaches for constantly — `bodySmall` (timestamps,
  /// helper text) and `labelSmall` (field labels, captions). Those two default
  /// muted so that the common case needs no `copyWith` at the call site.
  static TextTheme textTheme({
    required Color primary,
    required Color secondary,
  }) {
    return TextTheme(
      // The one-per-screen hero number: the splash wordmark, an availability
      // count, a plate number.
      displayLarge: _display(TextStyle(
        fontSize: 32,
        height: 40 / 32,
        fontWeight: FontWeight.w700,
        color: primary,
      )),

      // Screen titles.
      headlineLarge: _display(TextStyle(
        fontSize: 28,
        height: 36 / 28,
        fontWeight: FontWeight.w700,
        color: primary,
      )),

      // Section titles, and the title of a scrolling screen.
      headlineMedium: _display(TextStyle(
        fontSize: 22,
        height: 28 / 22,
        fontWeight: FontWeight.w600,
        color: primary,
      )),

      // Sub-section headings, app bar titles, card headings.
      headlineSmall: _display(TextStyle(
        fontSize: 18,
        height: 24 / 18,
        fontWeight: FontWeight.w600,
        color: primary,
      )),

      // The three `title*` slots are not part of the app's own scale, but
      // Material widgets read them — a `ListTile`, a `SegmentedButton`, the
      // date picker's mode switch. Left unset they fall back to Material's
      // defaults in Material's font, which is how a themed app ends up with
      // one dialog in Roboto. Mapped onto the nearest display sizes here so an
      // unstyled widget is right without anyone noticing it needed to be.
      titleLarge: _display(TextStyle(
        fontSize: 20,
        height: 26 / 20,
        fontWeight: FontWeight.w600,
        color: primary,
      )),

      titleMedium: _display(TextStyle(
        fontSize: 17,
        height: 22 / 17,
        fontWeight: FontWeight.w600,
        color: primary,
      )),

      titleSmall: _body(TextStyle(
        fontSize: 15,
        height: 20 / 15,
        fontWeight: FontWeight.w700,
        color: primary,
      )),

      // Emphasised body — the primary line of a list row, an input's value.
      bodyLarge: _body(TextStyle(
        fontSize: 17,
        height: 24 / 17,
        fontWeight: FontWeight.w400,
        color: primary,
      )),

      // The default. Paragraphs, row titles, dialog copy.
      bodyMedium: _body(TextStyle(
        fontSize: 15,
        height: 21 / 15,
        fontWeight: FontWeight.w400,
        color: primary,
      )),

      // Secondary metadata: timestamps, helper text, a row's second line.
      bodySmall: _body(TextStyle(
        fontSize: 13,
        height: 18 / 13,
        fontWeight: FontWeight.w400,
        color: secondary,
      )),

      // Button labels and the bold lead line of a row.
      labelLarge: _body(TextStyle(
        fontSize: 14,
        height: 20 / 14,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
        color: primary,
      )),

      // Badges and status pills.
      labelMedium: _body(TextStyle(
        fontSize: 13,
        height: 18 / 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
        color: primary,
      )),

      // Field labels, captions, legend keys.
      labelSmall: _body(TextStyle(
        fontSize: 12,
        height: 16 / 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: secondary,
      )),
    );
  }
}
