import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/theme.dart';
import 'app_state_views.dart';

/// Renders an [AsyncValue] with the app's standard loading, error and empty
/// treatments, wrapped in pull-to-refresh.
///
/// Ten screens each wrote their own `async.when(...)` block: ten bare
/// `CircularProgressIndicator`s, ten hand-written `RefreshIndicator`s, and ten
/// slightly different ideas of what an empty list should say. This collapses
/// them, and means the next feature gets correct states for free rather than
/// inventing an eleventh variant.
///
/// ```dart
/// AsyncView(
///   value: ref.watch(paymentsNotifierProvider),
///   onRefresh: () => ref.read(paymentsNotifierProvider.notifier).refresh(),
///   errorTitle: "Couldn't load your payments",
///   isEmpty: (r) => r.payments.isEmpty,
///   empty: const AppEmptyState(
///     icon: Icons.payments_rounded,
///     title: 'No payments yet',
///     message: 'Parking fees and penalties will show up here.',
///   ),
///   data: (r) => PaymentList(payments: r.payments),
/// );
/// ```
class AsyncView<T> extends StatelessWidget {
  const AsyncView({
    super.key,
    required this.value,
    required this.data,
    required this.errorTitle,
    this.onRefresh,
    this.isEmpty,
    this.empty,
    this.loading,
    this.padding,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;

  /// Names what failed, so the retry button has a subject: "Couldn't load your
  /// payments" rather than a lone blue `Retry` floating on a blank page, which
  /// is what ten of these screens used to show.
  final String errorTitle;

  /// Reloads the provider. Wired to both the pull gesture and the error state's
  /// retry button, so there is one refresh path per screen rather than two that
  /// can drift.
  final Future<void> Function()? onRefresh;

  /// Lets the caller decide what "empty" means for its own data shape.
  final bool Function(T data)? isEmpty;

  final Widget? empty;

  /// A skeleton matching this screen's layout. Falls back to a centred spinner.
  /// Prefer a skeleton on any screen whose shape is predictable — it tells the
  /// user the screen works and is filling in, where a spinner only says "wait".
  final Widget? loading;

  /// Applied to [data] only. The empty and error states centre themselves in
  /// the whole viewport regardless, which is where they belong.
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return value.when(
      loading: () => loading ?? const AppLoadingState(),
      error: (error, _) => _refreshable(
        RefreshableCenter(
          child: AppErrorState(
            title: errorTitle,
            onRetry: onRefresh == null ? null : () => onRefresh!(),
          ),
        ),
      ),
      data: (d) {
        if (isEmpty != null && isEmpty!(d)) {
          // Still refreshable: "nothing here yet" is the state a user is most
          // likely to want to pull on, and a list that cannot be pulled because
          // it happens to be empty feels broken.
          return _refreshable(
            RefreshableCenter(
              child: empty ??
                  const AppEmptyState(
                    icon: Icons.inbox_rounded,
                    title: 'Nothing here yet',
                    message: 'New items will appear here.',
                  ),
            ),
          );
        }
        final child = data(d);
        return _refreshable(
          padding == null ? child : Padding(padding: padding!, child: child),
        );
      },
    );
  }

  Widget _refreshable(Widget child) {
    if (onRefresh == null) return child;
    return RefreshIndicator(onRefresh: onRefresh!, child: child);
  }
}

/// Centres a widget that does not fill the viewport inside a scrollable, so a
/// [RefreshIndicator] above it still has something to pull on.
///
/// Without this an empty state is a `Column` of intrinsic height, the scroll
/// view never overscrolls, and the pull gesture silently does nothing.
class RefreshableCenter extends StatelessWidget {
  const RefreshableCenter({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(child: child),
        ),
      ),
    );
  }
}

/// Centred spinner, for the handful of places where a skeleton would be
/// dishonest — a screen whose shape genuinely is not known until the data
/// lands.
class AppLoadingState extends StatelessWidget {
  const AppLoadingState({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(message!, style: context.text.bodySmall),
          ],
        ],
      ),
    );
  }
}
