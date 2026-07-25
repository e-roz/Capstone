import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

/// Parking Points indicator — earned for on-time entry/exit, correct zone,
/// and rule adherence. AimPark's XP equivalent.
class PointsCounter extends StatelessWidget {
  const PointsCounter({super.key, required this.points});

  final int points;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.brandSubtle,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, color: AppColors.brandPressed, size: 20),
          const SizedBox(width: 4),
          Text(
            '$points',
            style: AppTextStyles.labelBold.copyWith(
              color: AppColors.brandPressed,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}
