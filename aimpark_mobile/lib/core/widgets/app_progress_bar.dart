import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// Generic rounded progress bar. Flat fill, no gradient — matches the rest of
/// the flat/bold AimPark visual language.
class AppProgressBar extends StatelessWidget {
  const AppProgressBar({
    super.key,
    required this.value,
    this.color,
    this.trackColor,
    this.height = 12.0,
  });

  /// 0.0–1.0 fill amount. Clamped, so a caller doing its own arithmetic cannot
  /// produce a bar that overshoots its track.
  final double value;

  /// Defaults to the brand fill.
  final Color? color;

  /// Defaults to the muted well.
  final Color? trackColor;

  final double height;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return ClipRRect(
      borderRadius: AppRadius.fullAll,
      child: TweenAnimationBuilder<double>(
        // Animated rather than snapping: these bars are almost always filling
        // in as data arrives, and a value that jumps from 0 to 0.65 in one
        // frame reads as a layout glitch rather than as progress.
        tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
        duration: AppMotion.normal,
        curve: AppMotion.emphasized,
        builder: (context, animated, _) => LinearProgressIndicator(
          value: animated,
          minHeight: height,
          backgroundColor: trackColor ?? t.surface.muted,
          valueColor: AlwaysStoppedAnimation(color ?? t.brand.primary),
        ),
      ),
    );
  }
}
