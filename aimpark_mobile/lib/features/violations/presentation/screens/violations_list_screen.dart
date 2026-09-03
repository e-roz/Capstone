import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/widgets.dart';
import '../../data/models/violation.dart';
import '../providers/violations_provider.dart';

class ViolationsListScreen extends ConsumerWidget {
  const ViolationsListScreen({super.key});

  /// Splits the record into what still needs doing and what does not.
  ///
  /// A paid fine used to sit at the top of this list looking exactly like an
  /// unpaid one, because the row only ever showed the appeal status and payment
  /// was not part of it. Keeping settled rows — rather than hiding them — leaves
  /// the user their own proof they paid; moving them down is what stops the list
  /// reading as a pile of outstanding debt.
  static (List<ViolationSummary> open, List<ViolationSummary> settled) _split(
    List<ViolationSummary> violations,
  ) {
    final open = <ViolationSummary>[];
    final settled = <ViolationSummary>[];
    for (final v in violations) {
      (v.isSettled ? settled : open).add(v);
    }
    return (open, settled);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> refresh() =>
        ref.read(violationsNotifierProvider.notifier).refresh();

    return AppScreen(
      title: 'My Violations',
      body: AsyncView(
        value: ref.watch(violationsNotifierProvider),
        onRefresh: refresh,
        errorTitle: "Couldn't load your violations",
        loading: const Padding(
          padding: kScreenListPadding,
          child: AppRowSkeleton(),
        ),
        isEmpty: (result) => result.violations.isEmpty,
        // The one empty state in the app that is an achievement rather than an
        // absence, so it is coloured as one instead of showing the same grey
        // icon as an empty inbox.
        empty: const AppEmptyState(
          icon: Icons.verified_rounded,
          intent: StatusIntent.success,
          title: 'Squeaky clean!',
          message: 'No violations on your record.',
        ),
        data: (result) {
          final (open, settled) = _split(result.violations);

          return ListView(
            padding: kScreenListPadding,
            children: [
              for (final v in open) ...[
                _ViolationRow(violation: v),
                if (v != open.last) const AppRowGap(),
              ],
              // Only announced when there is both something settled to head and
              // something open above it to separate it from.
              if (settled.isNotEmpty) ...[
                if (open.isNotEmpty) const SizedBox(height: AppSpacing.lg),
                const AppSectionHeader(title: 'Settled'),
                for (final v in settled) ...[
                  _ViolationRow(violation: v),
                  if (v != settled.last) const AppRowGap(),
                ],
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ViolationRow extends StatelessWidget {
  const _ViolationRow({required this.violation});

  final ViolationSummary violation;

  @override
  Widget build(BuildContext context) {
    return AppListRow(
      icon: Icons.gavel_rounded,
      title: violation.policyRuleTitle,
      subtitle: '${Formatters.peso(violation.penaltyAmount)} · '
          '${Formatters.date(violation.createdAt)}',
      trailing: AppStatusBadge(
        label: violation.displayStatus,
        intent: StatusIntents.violation(violation.displayStatus),
      ),
      onTap: () =>
          context.push('/home/user/violations/${violation.violationId}'),
    );
  }
}
