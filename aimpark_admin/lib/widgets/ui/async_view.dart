import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/theme.dart';

/// Renders an [AsyncValue] with the panel's standard loading, error and empty
/// treatments.
///
/// Every screen previously wrote its own `async.when(...)` block — ten copies,
/// with three different error layouts and four different empty messages. This
/// collapses them, and means a future feature gets correct loading and error
/// states for free instead of inventing a fourth variant.
///
/// ```dart
/// AsyncView(
///   value: ref.watch(pendingRegistrationsProvider),
///   onRetry: () => ref.invalidate(pendingRegistrationsProvider),
///   isEmpty: (list) => list.isEmpty,
///   empty: const AppEmptyState(
///     icon: Icons.check_circle_outline,
///     title: 'Nothing waiting',
///     message: 'New registrations will appear here as students submit them.',
///   ),
///   data: (list) => RegistrationTable(rows: list),
/// );
/// ```
class AsyncView<T> extends StatelessWidget {
  const AsyncView({
    super.key,
    required this.value,
    required this.data,
    this.onRetry,
    this.isEmpty,
    this.empty,
    this.loading,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;

  /// Wired to the Retry button on the error state. Almost always
  /// `() => ref.invalidate(theProvider)`.
  final VoidCallback? onRetry;

  /// Lets the caller decide what "empty" means for its own data shape.
  final bool Function(T data)? isEmpty;

  final Widget? empty;
  final Widget? loading;

  @override
  Widget build(BuildContext context) {
    return value.when(
      loading: () => loading ?? const AppLoadingState(),
      error: (e, _) => AppErrorState(error: e, onRetry: onRetry),
      data: (d) {
        if (isEmpty != null && isEmpty!(d)) {
          return empty ?? const AppEmptyState(title: 'Nothing here yet');
        }
        return data(d);
      },
    );
  }
}

/// Centred spinner. Deliberately plain — a skeleton screen would be nicer but
/// only if every screen has one, and half-skeletons look broken.
class AppLoadingState extends StatelessWidget {
  const AppLoadingState({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.x3),
            Text(
              message!,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: t.text.secondary),
            ),
          ],
        ],
      ),
    );
  }
}

/// The empty state. A title plus a sentence explaining what would make content
/// appear — an empty table with no explanation reads as a bug to a first-time
/// user, which is most of a defence panel.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.inbox_outlined,
    this.action,
  });

  final String title;
  final String? message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: t.surface.muted,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 26, color: t.text.tertiary),
            ),
            const SizedBox(height: AppSpacing.x4),
            Text(title, style: text.titleMedium, textAlign: TextAlign.center),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.x2),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: text.bodySmall?.copyWith(color: t.text.secondary),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: AppSpacing.x5),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// The error state.
///
/// The raw exception is shown in a monospace-ish muted block rather than as the
/// headline: an admin needs "this failed, try again", and a developer needs the
/// detail, and burying the detail one visual level down serves both.
class AppErrorState extends StatelessWidget {
  const AppErrorState({
    super.key,
    required this.error,
    this.onRetry,
    this.title = 'Could not load this',
  });

  final Object error;
  final VoidCallback? onRetry;
  final String title;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: t.status.danger.bg,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outline,
                  size: 26, color: t.status.danger.fg),
            ),
            const SizedBox(height: AppSpacing.x4),
            Text(title, style: text.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.x2),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.x3),
              decoration: BoxDecoration(
                color: t.surface.muted,
                borderRadius: AppRadii.smAll,
                border: Border.all(color: t.border.subtle),
              ),
              child: Text(
                '$error',
                style: text.bodySmall?.copyWith(color: t.text.secondary),
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.x5),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: AppSizes.iconSm),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
