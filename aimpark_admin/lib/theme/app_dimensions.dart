import 'package:flutter/material.dart';

/// LAYER 1 + 2 — Spacing primitives and their semantic aliases.
///
/// Every gap in the panel is a multiple of 4. That single rule is what makes
/// unrelated screens built months apart still line up, so reach for the named
/// alias first ([pagePadding], [cardPadding], …) and only drop to a raw step
/// when nothing named fits.
class AppSpacing {
  AppSpacing._();

  // Primitive steps — the 4px grid.
  static const double x0 = 0;
  static const double x1 = 4;
  static const double x2 = 8;
  static const double x3 = 12;
  static const double x4 = 16;
  static const double x5 = 20;
  static const double x6 = 24;
  static const double x8 = 32;
  static const double x10 = 40;
  static const double x12 = 48;
  static const double x16 = 64;

  // Semantic aliases — prefer these in screens and components.
  /// Outer padding around a page's content area.
  static const double pagePadding = x6;

  /// Padding inside a card or panel.
  static const double cardPadding = x4;

  /// Space between two cards or tiles in a grid.
  static const double gutter = x3;

  /// Space between major blocks within one page.
  static const double sectionGap = x6;

  /// Space between a heading and the content it introduces.
  static const double headingGap = x4;

  /// Space between adjacent controls in a toolbar or button row.
  static const double controlGap = x2;

  /// Space between a label and the value beneath it.
  static const double labelGap = x1;

  /// Horizontal padding inside a table cell.
  static const double cellPaddingX = x4;
}

/// LAYER 1 + 2 — Corner radii.
///
/// Three sizes, used consistently: [sm] for dense inline things, [md] for
/// controls, [lg] for containers. A fourth value would only invite drift.
class AppRadii {
  AppRadii._();

  static const double sm = 6;
  static const double md = 8;
  static const double lg = 12;
  static const double xl = 16;

  /// Pill shape for status chips and avatars.
  static const double full = 999;

  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlAll = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius fullAll = BorderRadius.all(Radius.circular(full));
}

/// LAYER 2 — Elevation as explicit shadows rather than Material's numeric
/// elevation, because Material 3 renders elevation as a surface *tint* and the
/// panel wants a genuine lift off the canvas.
///
/// The recipe is a doubling ladder — each layer twice the blur and offset of
/// the one before, pulled back by a negative spread of half its blur. That is
/// what separates a modern SaaS surface from a Material one: instead of a
/// single soft blob, the shadow is dense right under the edge and fades over a
/// long tail, so a card reads as *lifted* rather than *smudged*. Taken from
/// ClickUp's elevation tokens (`docs/clickup-skill/DESIGN.md` §6), whose own
/// shadows are tinted blue rather than black.
///
/// Every layer below is `0x??0F172A` — the darkest slate neutral, never pure
/// black. Black on a blue-slate canvas turns the shadow grey and slightly
/// dirty. Only the alpha byte varies.
class AppElevation {
  AppElevation._();

  /// Resting state for cards and tables.
  static const List<BoxShadow> sm = [
    BoxShadow(color: Color(0x0D0F172A), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(
      color: Color(0x0D0F172A),
      blurRadius: 3,
      spreadRadius: -1.5,
      offset: Offset(0, 3),
    ),
  ];

  /// Hovered cards and dropdown surfaces.
  static const List<BoxShadow> md = [
    BoxShadow(
      color: Color(0x0A0F172A),
      blurRadius: 1,
      spreadRadius: -0.5,
      offset: Offset(0, 1),
    ),
    BoxShadow(
      color: Color(0x0A0F172A),
      blurRadius: 3,
      spreadRadius: -1.5,
      offset: Offset(0, 3),
    ),
    BoxShadow(
      color: Color(0x0A0F172A),
      blurRadius: 6,
      spreadRadius: -3,
      offset: Offset(0, 6),
    ),
    BoxShadow(
      color: Color(0x0A0F172A),
      blurRadius: 12,
      spreadRadius: -6,
      offset: Offset(0, 12),
    ),
  ];

  /// Dialogs and slide-over panels — [md]'s ladder carried two rungs further,
  /// which is how the panel reads as floating above a still-visible table.
  static const List<BoxShadow> lg = [
    ...md,
    BoxShadow(
      color: Color(0x0F0F172A),
      blurRadius: 24,
      spreadRadius: -12,
      offset: Offset(0, 24),
    ),
    BoxShadow(
      color: Color(0x0F0F172A),
      blurRadius: 48,
      spreadRadius: -24,
      offset: Offset(0, 48),
    ),
  ];

  static const List<BoxShadow> none = [];
}

/// LAYER 2 — Motion.
///
/// Admin tools should feel instant; anything above ~200ms on a hover state
/// reads as lag rather than polish.
class AppMotion {
  AppMotion._();

  /// Hover and focus feedback.
  static const Duration fast = Duration(milliseconds: 120);

  /// Expand/collapse, tab switches, panel slides.
  static const Duration normal = Duration(milliseconds: 180);

  /// Full-surface transitions such as the slide-over panel.
  static const Duration slow = Duration(milliseconds: 280);

  static const Curve standard = Curves.easeOutCubic;
  static const Curve emphasized = Curves.easeInOutCubicEmphasized;
}

/// LAYER 2 — Fixed sizes that several components must agree on.
class AppSizes {
  AppSizes._();

  /// Sidebar width when labels are visible.
  static const double sidebarExpanded = 248;

  /// Sidebar width when collapsed to icons.
  static const double sidebarCollapsed = 72;

  /// Height of the top bar above page content.
  static const double topBarHeight = 60;

  /// Table row height. 44 rather than Material's 52: an admin scanning for one
  /// row among sixty is served better by seeing more of them at once than by
  /// the extra 8px of breathing room, and the hairline divider plus whole-row
  /// hover carry the separation that the padding used to.
  static const double tableRowHeight = 44;
  static const double tableHeaderHeight = 40;

  /// Standard control height, so buttons and inputs align in a toolbar.
  static const double controlHeight = 40;
  static const double controlHeightSm = 32;

  /// Width of a metric tile in the reports grid.
  static const double metricCardWidth = 210;

  /// Label column in a check row on the registration review screen. Fixed so
  /// every check's evidence starts on the same line down the card — a ragged
  /// left edge there makes six rows read as six unrelated statements.
  static const double checkLabelWidth = 158;

  /// The tinted square holding a banner's icon. Larger than [iconLg] because it
  /// is the first thing on the page and has to hold its own against a headline.
  static const double bannerIcon = 34;

  /// Icon sizes.
  static const double iconSm = 16;
  static const double iconMd = 20;
  static const double iconLg = 24;

  /// Widest a form or detail column should ever grow — long lines are hard to
  /// scan on an ultrawide monitor.
  static const double contentMaxWidth = 1440;
  static const double formMaxWidth = 560;
}
