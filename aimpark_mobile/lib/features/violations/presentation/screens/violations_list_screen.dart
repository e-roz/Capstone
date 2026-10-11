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
      title: 'Violations',
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
              if (open.isNotEmpty) ...[
                AppSectionHeader(title: 'Open · ${open.length}'),
                AppRowGroup(
                  children: [for (final v in open) _ViolationRow(violation: v)],
                ),
              ],
              if (settled.isNotEmpty) ...[
                if (open.isNotEmpty) const SizedBox(height: AppSpacing.lg),
                AppSectionHeader(title: 'Settled · ${settled.length}'),
                AppRowGroup(
                  children: [
                    for (final v in settled) _ViolationRow(violation: v),
                  ],
                ),
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
    final t = context.tokens;
    final intent = StatusIntents.violation(violation.displayStatus);
    final c = t.status.of(intent);

    // The deadline is the one thing on an open violation that is time-limited,
    // so it gets its own line, coloured by how close it is.
    final deadline = violation.canAppeal ? violation.appealDeadline : null;
    final urgency = deadline == null ? null : appealUrgency(deadline);

    return AppListRow(
      leading: Container(
        width: AppSizes.rowIcon,
        height: AppSizes.rowIcon,
        decoration: BoxDecoration(color: c.bg, shape: BoxShape.circle),
        child: Icon(Icons.gavel_rounded, size: AppSizes.iconMd, color: c.fg),
      ),
      title: violation.policyRuleTitle,
      subtitle:
          '${Formatters.peso(violation.penaltyAmount)} · '
          '${Formatters.date(violation.createdAt)}',
      // The status sits under the name, beside the deadline, instead of pinned to
      // the far end of the row. A badge there cannot shrink, so a long one such as
      // "Appeal accepted" squeezed the rule's name or ran off the screen at a
      // large text size.
      note: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          AppStatusBadge(label: violation.displayStatus, intent: intent),
          if (deadline != null)
            Text(
              appealCountdown(deadline),
              style: context.text.bodySmall?.copyWith(
                color: t.status.of(urgency!).fg,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
      onTap: () =>
          context.push('/home/user/violations/${violation.violationId}'),
    );
  }
}
