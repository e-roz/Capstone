import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Generic rounded progress bar (e.g. monthly permit renewal, parking-history
/// timeline). Flat fill, no gradient — matches the rest of the flat/bold
/// AimPark visual language.
class AppProgressBar extends StatelessWidget {
  const AppProgressBar({
    super.key,
    required this.value,
    this.color = AppColors.brandDefault,
    this.trackColor = AppColors.bgSurfaceAlt,
    this.height = 12.0,
  });

  /// 0.0–1.0 fill amount.
  final double value;
  final Color color;
  final Color trackColor;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: height,
        backgroundColor: trackColor,
        valueColor: AlwaysStoppedAnimation(color),
      ),
    );
  }
}
