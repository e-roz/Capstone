import 'package:flutter/material.dart';

import '../theme/theme.dart';
import 'app_button.dart';
import 'app_card.dart';

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

    return _StateCard(
      borderColor: c?.border,
      iconColor: c?.fg ?? t.text.disabled,
      iconBackground: c?.bg ?? t.surface.muted,
      icon: icon,
      title: title,
      message: message,
      action: actionLabel != null && onAction != null
          ? AppButton(label: actionLabel!, onPressed: onAction)
          : null,
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

    final c = t.status.danger;

    return _StateCard(
      borderColor: c.border,
      iconColor: c.fg,
      iconBackground: c.bg,
      icon: Icons.cloud_off_rounded,
      title: title,
      message: message,
      // Primary, not ghost. Retrying is the only thing this screen is for, and
      // a quiet outlined button on a screen with nothing else on it was reading
      // as disabled.
      action: onRetry == null
          ? null
          : SizedBox(
              width: 180,
              child: AppButton(label: 'Try again', onPressed: onRetry),
            ),
    );
  }
}

/// The shared shape behind [AppEmptyState] and [AppErrorState]: a centred card
/// carrying a tinted icon disc, a title, a sentence and an optional action.
///
/// These used to be bare columns floating on the canvas, which left them as the
/// only full-screen surfaces in the app with no card under them — a blank page
/// with a picture in the middle reads as a crash more than as a state.
class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.message,
    this.borderColor,
    this.action,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String message;
  final Color? borderColor;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSizes.contentMaxWidth),
          child: AppCard(
            borderColor: borderColor,
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: AppSizes.iconHero,
                  height: AppSizes.iconHero,
                  decoration: BoxDecoration(
                    color: iconBackground,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: AppSizes.iconLg, color: iconColor),
                ),
                const SizedBox(height: AppSpacing.sm + 4),
                Text(
                  title,
                  style: context.text.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: context.text.bodyMedium
                      ?.copyWith(color: t.text.secondary),
                ),
                if (action != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  action!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
