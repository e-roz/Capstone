import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../core/utils/responsive.dart';
import '../models/admin_user.dart';
import '../providers/users_provider.dart';
import '../theme/theme.dart';
import '../widgets/ui/ui.dart';

const _statuses = [
  AppFilterOption('Active', 'Active'),
  AppFilterOption('Suspended', 'Suspended'),
  AppFilterOption('PendingReview', 'Pending review'),
  AppFilterOption('Rejected', 'Rejected'),
  AppFilterOption('Archived', 'Archived'),
];

final _joined = DateFormat('MMM d, yyyy');

class UserManagementScreen extends ConsumerWidget {
  const UserManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(usersQueryNotifierProvider);
    final notifier = ref.read(usersQueryNotifierProvider.notifier);

    return AppPage(
      title: 'User Management',
      subtitle: 'Everyone with an AimPark account, and the state of it.',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
          onPressed: () => ref.invalidate(userListProvider),
        ),
      ],
      toolbar: AppToolbar(
        // Search is server-side here, so it spans the whole result set rather
        // than the visible page.
        search: AppSearchField(
          hint: 'Search name, email, or plate',
          initialValue: query.search,
          onChanged: notifier.setSearch,
        ),
        filters: [
          AppFilterDropdown<String>(
            label: 'Status',
            value: query.status,
            options: _statuses,
            allLabel: 'All statuses',
            onChanged: notifier.setStatus,
          ),
        ],
      ),
      body: AsyncView(
        value: ref.watch(userListProvider),
        onRetry: () => ref.invalidate(userListProvider),
        isEmpty: (page) => page.users.isEmpty,
        empty: const AppEmptyState(
          icon: Icons.person_search_outlined,
          title: 'No users match',
          message: 'Try a different search, or clear the status filter.',
        ),
        data: (page) => AppDataTable(
          minWidth: 1000,
          columns: const [
            DataColumn(label: Text('Full Name')),
            DataColumn(label: Text('Email')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Joined')),
            DataColumn(label: Text('Actions')),
          ],
          rows: [for (final user in page.users) _row(context, ref, user)],
          footer: AppPagination(
            page: page.page,
            pageSize: page.pageSize,
            total: page.totalCount,
            itemLabel: 'users',
            onPage: notifier.setPage,
          ),
        ),
      ),
    );
  }

  DataRow _row(BuildContext context, WidgetRef ref, AdminUser user) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    return DataRow(
      onSelectChanged: (_) => context.go('/users/${user.userId}'),
      cells: [
        // Archived accounts used to carry a separate "Archived" column that was
        // an empty cell on every other row. Struck-through text plus the pill
        // says the same thing in the space the name already occupies.
        DataCell(Row(
          children: [
            if (user.isDeleted) ...[
              Icon(Icons.archive_outlined,
                  size: AppSizes.iconSm, color: t.text.tertiary),
              const SizedBox(width: AppSpacing.x2),
            ],
            Text(
              user.fullName,
              style: user.isDeleted
                  ? text.titleSmall?.copyWith(
                      color: t.text.tertiary,
                      decoration: TextDecoration.lineThrough,
                    )
                  : text.titleSmall,
            ),
          ],
        )),
        DataCell(Text(user.email)),
        DataCell(StatusPill.of(
          user.isDeleted ? 'Archived' : user.accountStatus,
          intent: user.isDeleted
              ? StatusIntent.neutral
              : StatusIntents.user(user.accountStatus),
          dense: true,
        )),
        DataCell(Text(
          _joined.format(user.createdAt.toLocal()),
          style: text.bodySmall?.copyWith(color: t.text.secondary),
        )),
        DataCell(_RowActions(user: user)),
      ],
    );
  }
}

// ── Row actions ──────────────────────────────────────────────────────────────

class _RowActions extends ConsumerWidget {
  const _RowActions({required this.user});

  final AdminUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDeleted = user.isDeleted;
    final status = user.accountStatus;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isDeleted)
          AppRowAction(
            icon: Icons.restore,
            label: 'Restore',
            intent: StatusIntent.info,
            onPressed: () => _restore(context, ref),
          ),
        if (!isDeleted && status == 'Active')
          AppRowAction(
            icon: Icons.pause_circle_outline,
            label: 'Suspend',
            intent: StatusIntent.warning,
            onPressed: () => _suspend(context, ref),
          ),
        if (!isDeleted && status == 'Suspended')
          AppRowAction(
            icon: Icons.play_circle_outline,
            label: 'Unsuspend',
            intent: StatusIntent.success,
            onPressed: () => _unsuspend(context, ref),
          ),
        if (!isDeleted) ...[
          const SizedBox(width: AppSpacing.x2),
          AppRowAction(
            icon: Icons.archive_outlined,
            label: 'Archive',
            intent: StatusIntent.danger,
            onPressed: () => _archive(context, ref),
          ),
        ],
      ],
    );
  }

  Future<void> _suspend(BuildContext context, WidgetRef ref) async {
    final reasonCtrl = TextEditingController();

    // The dialog returns a bool, not the reason string. It used to return the
    // reason, which made "cancelled" and "confirmed with no reason" both come
    // back as null — and the tie-break that followed resolved to *suspend*, so
    // pressing Cancel suspended the account.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Suspend ${user.fullName}'),
        content: SizedBox(
          width: ctx.dialogWidth(420),
          child: TextField(
            controller: reasonCtrl,
            decoration: const InputDecoration(
              labelText: 'Reason',
              helperText: 'Optional — shown in the audit log',
            ),
            maxLines: 2,
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Suspend'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    final reason =
        reasonCtrl.text.trim().isEmpty ? null : reasonCtrl.text.trim();
    final msg = await ref
        .read(userActionsProvider.notifier)
        .suspend(user.userId, reason: reason);
    if (!context.mounted) return;
    _report(context, ref, msg ?? 'User suspended.');
  }

  Future<void> _unsuspend(BuildContext context, WidgetRef ref) async {
    final msg =
        await ref.read(userActionsProvider.notifier).unsuspend(user.userId);
    if (!context.mounted) return;
    _report(context, ref, msg ?? 'User unsuspended.');
  }

  Future<void> _archive(BuildContext context, WidgetRef ref) async {
    final passwordCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archive User'),
        content: SizedBox(
          width: ctx.dialogWidth(420),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Archive ${user.fullName}? The account data is retained and '
                  'can be restored later, but they will not be able to log in.',
                ),
                const SizedBox(height: AppSpacing.x4),
                TextFormField(
                  controller: passwordCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                      labelText: 'Confirm your admin password'),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Password is required' : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: ctx.tokens.status.danger.solid),
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
            },
            child: const Text('Archive'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    final msg = await ref
        .read(userActionsProvider.notifier)
        .archive(user.userId, passwordCtrl.text);
    if (!context.mounted) return;
    _report(context, ref, msg ?? 'User archived.');
  }

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    final msg =
        await ref.read(userActionsProvider.notifier).restore(user.userId);
    if (!context.mounted) return;
    _report(context, ref, msg ?? 'User restored.');
  }

  /// The snackbar used to be tinted per action — green for unsuspend, red for
  /// archive — which read as "this failed" on the destructive ones. The colour
  /// carried no information the message did not, so it is gone.
  void _report(BuildContext context, WidgetRef ref, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
    ref.invalidate(userListProvider);
  }
}
