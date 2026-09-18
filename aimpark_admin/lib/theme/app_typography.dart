import 'package:flutter/material.dart';

/// LAYER 1 + 2 — Type scale.
///
/// Nine sizes, each mapped onto the Material [TextTheme] slot that Flutter's
/// own widgets already read. That mapping matters: because `bodyMedium` *is*
/// the 14px body style, an unstyled `Text` inside a `DataTable` or an
/// `AlertDialog` comes out correct without anyone passing a `TextStyle`.
///
/// The panel is desktop-dense, so the base size is 14 rather than the Material
/// default of 16 — a table showing fifteen rows on a laptop is worth more to an
/// admin than a slightly more comfortable line of prose.
class AppTypography {
  AppTypography._();

  /// Inter carries every dense, small-size surface: table cells, form values,
  /// labels, badges. It was drawn for exactly this job — small sizes, tabular
  /// data, tall x-height — and stays the workhorse for the eleven slots below
  /// that read as data rather than as a title.
  ///
  /// All bundled under `assets/fonts/` and declared in `pubspec.yaml`, not
  /// fetched from a CDN: the defence demo has to survive a room with no
  /// working Wi-Fi.
  static TextStyle _base(TextStyle style) =>
      style.copyWith(fontFamily: 'Inter');

  /// Plus Jakarta Sans carries the three slots that behave like a title
  /// rather than like data: metric numerals, page titles, and dialog headers.
  /// Inter is tuned for legibility at 12-14px in a table; at 18px+ in a
  /// heading its default weights read as generic — the exact "Inter for
  /// everything" flatness a template dashboard has. Jakarta's rounder,
  /// warmer letterforms give AimPark a title voice that is still a sans, not
  /// a display face, so it never fights the data underneath it.
  static TextStyle _display(TextStyle style) =>
      style.copyWith(fontFamily: 'Plus Jakarta Sans');

  /// Digits that line up in a column. Use for money, counts, IDs and any
  /// numeric table cell, otherwise the columns visibly wobble row to row.
  static TextStyle tabular(TextStyle style) =>
      style.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

  static const double _tight = 1.25;
  static const double _normal = 1.45;

  /// The full scale, in one place. [color] is applied to every slot; per-role
  /// colours (secondary text, etc.) are applied at the call site from tokens.
  static TextTheme textTheme(Color color) {
    return TextTheme(
      // Oversized figures — metric tiles and empty-state numerals.
      displaySmall: _display(
        TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          height: _tight,
          letterSpacing: -0.4,
          color: color,
        ),
      ),

      // Page titles. One per screen.
      headlineSmall: _display(
        TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          height: _tight,
          letterSpacing: -0.3,
          color: color,
        ),
      ),

      // Dialog titles and slide-over headers.
      titleLarge: _display(
        TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          height: _tight,
          letterSpacing: -0.2,
          color: color,
        ),
      ),

      // Card and section headings.
      titleMedium: _base(
        TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          height: 1.35,
          color: color,
        ),
      ),

      // Emphasised body — the primary value in a row, a field's name.
      titleSmall: _base(
        TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          height: 1.35,
          color: color,
        ),
      ),

      bodyLarge: _base(
        TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          height: _normal,
          color: color,
        ),
      ),

      // The default. Table cells, form values, paragraphs.
      bodyMedium: _base(
        TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          height: _normal,
          color: color,
        ),
      ),

      // Secondary metadata: timestamps, helper text, captions.
      bodySmall: _base(
        TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          height: 1.4,
          color: color,
        ),
      ),

      // Button labels.
      labelLarge: _base(
        TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          height: 1.2,
          letterSpacing: 0.1,
          color: color,
        ),
      ),

      // Table column headers and status pills.
      labelMedium: _base(
        TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          height: 1.2,
          letterSpacing: 0.2,
          color: color,
        ),
      ),

      // Micro-labels: badge counts, legend keys.
      labelSmall: _base(
        TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          height: 1.2,
          letterSpacing: 0.3,
          color: color,
        ),
      ),
    );
  }
}
