import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

/// Replaces Duolingo's "hearts" mechanic with an opposite-psychology meter:
/// it builds up with compliant parking rather than draining on mistakes, and
/// never blocks access — it's a trust signal, not a gate. See design notes:
/// a parking violation already has real consequences (fines/suspension)
/// handled elsewhere, so the UI shouldn't add punitive game-feel on top.
class GoodStandingMeter extends StatelessWidget {
  const GoodStandingMeter({
    super.key,
    required this.level,
    required this.tierLabel,
  });

  /// 0.0–1.0 fill amount.
  final double level;
  final String tierLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Good Standing', style: AppTextStyles.labelSmall),
            Text(
              tierLabel,
              style: AppTextStyles.labelBold.copyWith(
                color: AppColors.successPressed,
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.full),
          child: LinearProgressIndicator(
            value: level.clamp(0.0, 1.0),
            minHeight: 10,
            backgroundColor: AppColors.successSubtle,
            valueColor: const AlwaysStoppedAnimation(AppColors.successDefault),
          ),
        ),
      ],
    );
  }
}
