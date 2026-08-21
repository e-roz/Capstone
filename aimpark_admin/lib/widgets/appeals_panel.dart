import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/violation.dart';
import '../providers/violations_provider.dart';
import '../theme/theme.dart';
import 'ui/ui.dart';

const _appealStatuses = ['Pending', 'Approved', 'Denied'];

/// The appeals queue, as a self-contained panel.
///
/// It lives in its own file rather than inside a screen because the official
/// module list treats appeals as part of *Incident Reports and Appeals Review*,
/// while the data hangs off a violation. Keeping the panel portable means the
/// decision about which screen hosts it is a one-line change, not a 200-line
/// move.
class AppealsPanel extends ConsumerWidget {
  const AppealsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(appealsQueryNotifierProvider);
    final notifier = ref.read(appealsQueryNotifierProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppToolbar(
          filters: [
            AppFilterDropdown<String>(
              label: 'Status',
              value: query.status,
              options: [
                for (final s in _appealStatuses) AppFilterOption(s, s),
              ],
              allLabel: 'All statuses',
              onChanged: notifier.setStatus,
            ),
          ],
          trailing: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              onPressed: () => ref.invalidate(appealListProvider),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.headingGap),
        Expanded(
          child: AsyncView(
            value: ref.watch(appealListProvider),
            onRetry: () => ref.invalidate(appealListProvider),
            isEmpty: (page) => page.appeals.isEmpty,
            empty: AppEmptyState(
              icon: Icons.gavel_outlined,
              title: query.status == null
                  ? 'No appeals filed'
                  : 'No ${query.status!.toLowerCase()} appeals',
              message: query.status == null
                  ? 'When a user contests a violation from the mobile app, the '
                      'appeal lands here for a decision.'
                  : 'Clear the filter to see every appeal.',
            ),
            data: (page) => Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    itemCount: page.appeals.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.gutter),
                    itemBuilder: (context, i) =>
                        _AppealCard(appeal: page.appeals[i]),
                  ),
                ),
                const SizedBox(height: AppSpacing.gutter),
                AppPagination(
                  page: page.page,
                  pageSize: page.pageSize,
                  total: page.totalCount,
                  itemLabel: 'appeals',
                  onPage: notifier.setPage,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AppealCard extends ConsumerWidget {
  const _AppealCard({required this.appeal});

  final ViolationAppeal appeal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final pending = appeal.status == 'Pending';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StatusPill.of(
                appeal.status,
                intent: StatusIntents.violation(appeal.status),
                dense: true,
              ),
              const SizedBox(width: AppSpacing.x3),
              Expanded(
                child: Text(
                  'Violation ${appeal.violationId.substring(0, 8)}…',
                  style: text.titleSmall,
                ),
              ),
              Text(
                DateFormat('MMM d, yyyy HH:mm')
                    .format(appeal.createdAt.toLocal()),
                style: text.bodySmall?.copyWith(color: t.text.secondary),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x3),
          // The user's argument is the thing being judged, so it gets the
          // quoted treatment rather than sitting as one more grey line.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.x3),
            decoration: BoxDecoration(
              color: t.surface.muted,
              borderRadius: AppRadii.smAll,
              border: Border(left: BorderSide(color: t.border.strong, width: 3)),
            ),
            child: Text(appeal.reasonText, style: text.bodyMedium),
          ),
          if (appeal.adminNotes case final notes? when notes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.x3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.sticky_note_2_outlined,
                      size: AppSizes.iconSm, color: t.text.tertiary),
                  const SizedBox(width: AppSpacing.x2),
                  Expanded(
                    child: Text(
                      notes,
                      style: text.bodySmall?.copyWith(color: t.text.secondary),
                    ),
                  ),
                ],
              ),
            ),
          if (appeal.decidedAt case final decided? when !pending)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.x2),
              child: Text(
                'Decided ${DateFormat('MMM d, yyyy HH:mm').format(decided.toLocal())}',
                style: text.labelSmall?.copyWith(color: t.text.tertiary),
              ),
            ),
          if (pending) ...[
            const SizedBox(height: AppSpacing.x4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AppRowAction(
                  label: 'Deny',
                  icon: Icons.close,
                  intent: StatusIntent.danger,
                  onPressed: () => _decide(context, ref, false),
                ),
                const SizedBox(width: AppSpacing.controlGap),
                AppRowAction(
                  label: 'Approve',
                  icon: Icons.check,
                  intent: StatusIntent.success,
                  onPressed: () => _decide(context, ref, true),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _decide(
      BuildContext context, WidgetRef ref, bool approve) async {
    final notesCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(approve ? 'Approve Appeal' : 'Deny Appeal'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(approve
                  ? 'Approving overturns the violation and lifts any suspension it carried.'
                  : 'Denying upholds the violation as issued.'),
              const SizedBox(height: AppSpacing.x4),
              TextField(
                controller: notesCtrl,
                maxLines: 2,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Admin notes (optional)',
                  helperText: 'Shown to the user with the decision.',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: approve
                ? null
                : FilledButton.styleFrom(
                    backgroundColor: ctx.tokens.status.danger.solid),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(approve ? 'Approve' : 'Deny'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    final msg = await ref.read(violationActionsProvider.notifier).decideAppeal(
        appeal.appealId,
        approve,
        notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim());
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg ?? 'Appeal decided.')));
    ref.invalidate(appealListProvider);
    ref.invalidate(violationListProvider);
  }
}
