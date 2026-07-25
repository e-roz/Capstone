import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

enum AppBadgeTone { brand, accent, tertiary, success, error }

/// Small pill label — used for status tags (e.g. "Available", "Pending").
class AppBadge extends StatelessWidget {
  const AppBadge({super.key, required this.label, this.tone = AppBadgeTone.brand});

  final String label;
  final AppBadgeTone tone;

  ({Color bg, Color fg}) _colorsFor(AppBadgeTone tone) {
    switch (tone) {
      case AppBadgeTone.brand:
        return (bg: AppColors.brandSubtle, fg: AppColors.brandPressed);
      case AppBadgeTone.accent:
        return (bg: AppColors.accentSubtle, fg: AppColors.accentPressed);
      case AppBadgeTone.tertiary:
        return (bg: AppColors.tertiarySubtle, fg: AppColors.tertiaryPressed);
      case AppBadgeTone.success:
        return (bg: AppColors.successSubtle, fg: AppColors.successPressed);
      case AppBadgeTone.error:
        return (bg: AppColors.errorSubtle, fg: AppColors.errorPressed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = _colorsFor(tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(color: colors.fg),
      ),
    );
  }
}
