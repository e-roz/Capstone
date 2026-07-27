import 'package:flutter/material.dart';

/// Layout breakpoints for the admin panel.
///
/// This is a desktop-first tool — nobody manages a parking lot from a phone by
/// choice — but it still has to be usable when someone opens it on one, so the
/// shell degrades rather than breaking.
class Breakpoints {
  Breakpoints._();

  /// Below this the nav rail becomes a drawer behind a hamburger button;
  /// an expanded rail would leave almost no room for content.
  static const double compact = 600;

  /// Below this the rail shows icons only instead of icons plus labels.
  static const double medium = 900;
}

extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;

  /// Phone-sized: navigation collapses into a drawer.
  bool get isCompact => screenWidth < Breakpoints.compact;

  /// Tablet / small laptop: rail visible but unlabelled.
  bool get isMedium => screenWidth < Breakpoints.medium;

  double get screenHeight => MediaQuery.sizeOf(this).height;

  /// Dialogs are sized for desktop; on a narrow screen a fixed width overflows,
  /// so clamp to whatever the window actually has, minus room for insets.
  double dialogWidth(double preferred) {
    final available = screenWidth - 80;
    return available < preferred ? available : preferred;
  }

  /// Same problem vertically, and worse in landscape on a phone — an iPhone in
  /// landscape is only ~414px tall, less than several of these dialogs.
  /// The reserve covers the dialog's title and action buttons.
  double dialogHeight(double preferred) {
    final available = screenHeight - 220;
    return available < preferred ? available : preferred;
  }
}
