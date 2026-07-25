import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

/// Consecutive-day compliance streak indicator — AimPark's answer to
/// Duolingo's daily streak. Counts days parked without a violation.
class StreakBadge extends StatelessWidget {
  const StreakBadge({super.key, required this.days});

  final int days;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.tertiarySubtle,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.local_fire_department_rounded,
              color: AppColors.tertiaryPressed, size: 20),
          const SizedBox(width: 4),
          Text(
            '$days',
            style: AppTextStyles.labelBold.copyWith(
              color: AppColors.tertiaryPressed,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}
