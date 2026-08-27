import 'package:flutter/material.dart';

/// LAYER 1 + 2 — Spacing primitives and their semantic aliases.
///
/// Every gap in the app is a multiple of 4. That single rule is what makes
/// unrelated screens built months apart still line up, so reach for the named
/// alias first ([screenPadding], [cardPadding], …) and only drop to a raw step
/// when nothing named fits.
///
/// The original t-shirt names ([xs] … [xxl]) are kept because the whole app
/// speaks them and renaming 400 call sites would be churn for its own sake.
/// They now sit alongside the numeric grid the admin panel uses, so the two
/// codebases can be read against each other.
abstract class AppSpacing {
  // Primitive steps — the 4px grid.
  static const double x1 = 4;
  static const double x2 = 8;
  static const double x3 = 12;
  static const double x4 = 16;
  static const double x5 = 20;
  static const double x6 = 24;
  static const double x8 = 32;
  static const double x10 = 40;
  static const double x12 = 48;

  // T-shirt aliases for the same steps.
  static const double xs = x1;
  static const double sm = x2;
  static const double md = x4;
  static const double lg = x6;
  static const double xl = x8;
  static const double xxl = x12;

  // Semantic aliases — prefer these in screens and components.

  /// Outer padding around a screen's content. Narrower than the admin panel's
  /// 24: on a 360dp phone every point of horizontal padding is a point the
  /// content does not get.
  static const double screenPadding = x4;

  /// Padding inside a card.
  static const double cardPadding = x4;

  /// Space between two cards in a list.
  static const double gutter = x2;

  /// Space between major blocks within one screen.
  static const double sectionGap = x6;

  /// Space between a section heading and what it introduces.
  static const double headingGap = x2;

  /// Space between adjacent controls in a button row.
  static const double controlGap = x2;

  /// Space between a label and the value beneath it.
  static const double labelGap = x1;

  /// Extra room below the last item in a scroll view, so the bottom nav and
  /// the home indicator never sit on top of content.
  static const double listBottomPadding = x8;
}

/// LAYER 1 + 2 — Corner radii.
///
/// Generous by design: the rounded geometry is half of what makes the app read
/// as friendly rather than administrative, and it is the one place the mobile
/// and desk products deliberately diverge (the panel tops out at 16).
abstract class AppRadius {
  static const double sm = 12.0;
  static const double md = 16.0;
  static const double lg = 20.0;
  static const double full = 9999.0;

  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius fullAll = BorderRadius.all(Radius.circular(full));
}

/// Vertical offset of the pressed-shadow layer behind buttons that use the
/// two-layer tactile depth effect. See `AppButton`.
const double kPressedShadowOffset = 5.0;

/// LAYER 2 — Elevation.
///
/// Used sparingly. This app separates surfaces with a 1.5px border rather than
/// a shadow — a flat card with a crisp edge is the register the component set
/// was drawn in, and it survives dark mode, where shadows are close to
/// invisible. These exist for the two things that genuinely float above the
/// page: dialogs, and the bottom nav.
abstract class AppElevation {
  static const List<BoxShadow> none = [];

  /// Bottom nav and sticky footers — a hairline of lift so content scrolling
  /// underneath is visibly behind rather than merged with it.
  static const List<BoxShadow> sm = [
    BoxShadow(color: Color(0x0F0A0A0A), blurRadius: 8, offset: Offset(0, -2)),
  ];

  /// Dialogs and bottom sheets.
  static const List<BoxShadow> lg = [
    BoxShadow(
      color: Color(0x1A0A0A0A),
      blurRadius: 24,
      spreadRadius: -8,
      offset: Offset(0, 12),
    ),
    BoxShadow(
      color: Color(0x140A0A0A),
      blurRadius: 48,
      spreadRadius: -24,
      offset: Offset(0, 24),
    ),
  ];
}

/// LAYER 2 — Motion.
///
/// Slower than the admin panel's, on purpose. A desk tool should feel instant;
/// a phone app people open several times a day can afford the extra frames that
/// make a press feel physical.
abstract class AppMotion {
  /// A press: the button collapsing onto its shadow layer, a card scaling down.
  static const Duration press = Duration(milliseconds: 100);

  /// Focus rings, chip selection, nav pill.
  static const Duration fast = Duration(milliseconds: 150);

  /// Progress bars filling, panels expanding.
  static const Duration normal = Duration(milliseconds: 200);

  /// The skeleton pulse, one direction.
  static const Duration slow = Duration(milliseconds: 900);

  static const Curve standard = Curves.easeOut;
  static const Curve emphasized = Curves.easeInOutCubic;

  /// For the celebration beat, where overshoot is the whole point.
  static const Curve bouncy = Curves.elasticOut;
}

/// LAYER 2 — Fixed sizes several components must agree on.
abstract class AppSizes {
  /// Standard control height, so a button and an input line up in a row.
  ///
  /// Comfortably above the 48dp minimum touch target — this is a phone app
  /// used one-handed, often outdoors, sometimes in a hurry.
  static const double controlHeight = 48;

  /// The round icon chip that leads a list row.
  static const double rowIcon = 40;

  /// Icon sizes.
  static const double iconSm = 16;
  static const double iconMd = 20;
  static const double iconLg = 24;

  /// The icon in an empty or error state.
  static const double iconHero = 48;

  /// Widest a form or a block of prose should grow, so the app still reads
  /// correctly on a tablet or a foldable rather than stretching to the edges.
  static const double contentMaxWidth = 560;
}
