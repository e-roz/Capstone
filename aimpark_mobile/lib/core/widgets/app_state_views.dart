import 'package:flutter/material.dart';

import '../theme/theme.dart';
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
    this.intent,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;

  /// Colours the icon by meaning. Left null the icon is muted, which is right
  /// for an ordinary absence. Pass [StatusIntent.success] when the emptiness is
  /// itself good news — a clean violation record is an achievement, not a void,
  /// and it should not be greeted with the same grey inbox as an empty list.
  final StatusIntent? intent;

  /// Optional call to action. Shown only when [onAction] is also given.
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = intent == null ? null : t.status.of(intent!);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: c?.bg ?? t.surface.muted,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: AppSizes.iconHero,
                color: c?.fg ?? t.text.disabled,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              style: context.text.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: context.text.bodyMedium?.copyWith(color: t.text.secondary),
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
    this.onRetry,
    this.message = 'Check your connection and try again.',
  });

  /// What could not be loaded, e.g. "Couldn't load your payments".
  final String title;
  final String message;

  /// Omitted only where there is genuinely nothing to retry.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: t.status.danger.bg,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.cloud_off_rounded,
                size: AppSizes.iconHero,
                color: t.status.danger.fg,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              style: context.text.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: context.text.bodyMedium?.copyWith(color: t.text.secondary),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: 180,
                child: AppButton(
                  label: 'Try Again',
                  icon: const Icon(Icons.refresh_rounded),
                  style: AppButtonStyle.ghost,
                  onPressed: onRetry,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
