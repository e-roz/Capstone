import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'app_button.dart';

/// The "nothing here yet" view. Five screens each declared their own private
/// `_EmptyState` with this exact shape; this is that shape, once.
///
/// Every empty state should say what *will* appear here, not just that nothing
/// has — "Your entries and exits will show up here" tells a new user the screen
/// works and is waiting, where a bare "No data" reads as a failure.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.iconColor = AppColors.textDisabled,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;

  /// Defaults to the muted grey of an absence. Pass a status colour when the
  /// emptiness is itself good news — no violations, for instance.
  final Color iconColor;

  /// Optional call to action. Shown only when [onAction] is also given.
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: iconColor),
            const SizedBox(height: AppSpacing.md),
            Text(title, style: AppTextStyles.h2, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.lg),
              AppButton(label: actionLabel!, onPressed: onAction),
            ],
          ],
        ),
      ),
    );
  }
}

/// The "that didn't load" view.
///
/// Ten screens previously rendered a failed load as a bare blue `Retry` word
/// floating in the middle of an otherwise blank page — no icon, no sentence, no
/// indication of whether the app was broken or the phone was offline. This
/// always names what failed to load, so the retry button has a subject.
class AppErrorState extends StatelessWidget {
  const AppErrorState({
    super.key,
    required this.title,
    required this.onRetry,
    this.message = 'Check your connection and try again.',
  });

  /// What could not be loaded, e.g. "Couldn't load your payments".
  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 48,
              color: AppColors.errorDefault,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(title, style: AppTextStyles.h2, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: 160,
              child: AppButton(
                label: 'Try Again',
                style: AppButtonStyle.ghost,
                onPressed: onRetry,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
