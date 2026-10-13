import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../core/constants/api_endpoints.dart';
import '../core/network/dio_client.dart';
import '../core/utils/jwt_utils.dart';
import '../core/utils/responsive.dart';
import '../models/admin_user.dart';
import '../providers/auth_provider.dart';
import '../providers/users_provider.dart';
import '../theme/theme.dart';
import '../widgets/rfid_revoke_dialog.dart';
import '../widgets/ui/ui.dart';
import '../widgets/user_actions.dart';

/// The statuses that get a chip. Applicants (pending review, rejected) are not
/// users yet, so they live on the Registrations screen and have no chip here.
const _chipStatuses = [
  UserStatuses.active,
  UserStatuses.revoked,
  UserStatuses.archived,
];

const _roles = [
  AppFilterOption(UserRoles.user, 'User'),
  AppFilterOption(UserRoles.security, 'Security'),
  AppFilterOption(UserRoles.admin, 'Admin'),
];

const _cardOptions = [
  AppFilterOption('has', 'Has card'),
  AppFilterOption('none', 'No card'),
];

final _joined = DateFormat('MMM d, yyyy');

class UserManagementScreen extends ConsumerStatefulWidget {
  const UserManagementScreen({super.key});

  @override
  ConsumerState<UserManagementScreen> createState() =>
      _UserManagementScreenState();
}

class _UserManagementScreenState extends ConsumerState<UserManagementScreen> {
  /// Bumped by "Clear filters". The search box keeps its own text, so it has
  /// to be rebuilt to empty it; keying it on the search value itself would
  /// rebuild it (and drop focus) on every debounced keystroke.
  int _searchGeneration = 0;

  void _clearFilters() {
    ref.read(usersQueryNotifierProvider.notifier).clearFilters();
    setState(() => _searchGeneration++);
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(usersQueryNotifierProvider);
    final notifier = ref.read(usersQueryNotifierProvider.notifier);
    final token = ref.watch(authNotifierProvider).valueOrNull;
    final myId = token == null ? null : JwtUtils.getUserId(token);

    return AppPage(
      title: 'Users',
      subtitle: 'Every account, its status and its card.',
      actions: [
        _MoreMenu(onBulkRevoke: () => _bulkRevokeRfid(context, ref)),
        const SizedBox(width: AppSpacing.x2),
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
          key: ValueKey(_searchGeneration),
          hint: 'Search name, email, or plate',
          initialValue: query.search,
          onChanged: notifier.setSearch,
        ),
        filters: [
          _StatusChips(value: query.status, onChanged: notifier.setStatus),
          AppFilterDropdown<String>(
            label: 'Role',
            value: query.role,
            options: _roles,
            allLabel: 'All roles',
            onChanged: notifier.setRole,
          ),
          AppFilterDropdown<String>(
            label: 'Card',
            value: query.card,
            options: _cardOptions,
            allLabel: 'All',
            onChanged: notifier.setCard,
          ),
        ],
      ),
      body: AsyncView(
        value: ref.watch(userListProvider),
        onRetry: () => ref.invalidate(userListProvider),
        loading: const SkeletonTable(
          columns: 5,
          columnWidths: [260, 110, 130, 110, 40],
        ),
        isEmpty: (page) => page.users.isEmpty,
        empty: AppEmptyState(
          icon: Icons.person_search_outlined,
          title: 'No users match.',
          message: query.hasFilters
              ? 'Try another search or filter.'
              : 'Accounts show up here once registration is complete.',
          action: query.hasFilters
              ? TextButton(
                  onPressed: _clearFilters,
                  child: const Text('Clear filters'),
                )
              : null,
        ),
        data: (page) => AppDataTable(
          minWidth: 760,
          columns: const [
            DataColumn(label: Text('Name')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Card')),
            DataColumn(label: Text('Joined')),
            // The row menu. No header text: the "⋯" button names itself.
            DataColumn(label: SizedBox.shrink()),
          ],
          rows: [
            for (final user in page.users)
              _row(
                context,
                user,
                isSelf:
                    myId != null &&
                    myId.toLowerCase() == user.userId.toLowerCase(),
              ),
          ],
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

  DataRow _row(BuildContext context, AdminUser user, {required bool isSelf}) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final status = user.displayStatus;

    return DataRow(
      onSelectChanged: (_) => context.go('/users/${user.userId}'),
      cells: [
        DataCell(_NameCell(user: user, isSelf: isSelf)),
        DataCell(
          StatusPill(
            label: UserStatuses.label(status),
            intent: user.isDeleted
                ? StatusIntent.neutral
                : StatusIntents.user(status),
            dense: true,
          ),
        ),
        DataCell(_CardCell(user: user)),
        DataCell(
          Text(
            _joined.format(user.createdAt.toLocal()),
            style: text.bodySmall?.copyWith(color: t.text.secondary),
          ),
        ),
        // The API refuses to archive your own account, so the row
        // offers nothing rather than buttons that only produce an error.
        DataCell(isSelf ? const SizedBox.shrink() : _RowMenu(user: user)),
      ],
    );
  }
}

// ── Toolbar ──────────────────────────────────────────────────────────────────

class _StatusChips extends StatelessWidget {
  const _StatusChips({required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.controlGap,
      runSpacing: AppSpacing.controlGap,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _chip(context, 'All', null),
        for (final s in _chipStatuses) _chip(context, UserStatuses.label(s), s),
      ],
    );
  }

  Widget _chip(BuildContext context, String label, String? status) =>
      _FilterChoiceChip(
        label: label,
        selected: value == status,
        onSelected: () => onChanged(status),
      );
}

/// A [ChoiceChip] with the same active treatment the RFID Cards chips use:
/// the theme's tint alone is too faint to tell which chip is on.
class _FilterChoiceChip extends StatelessWidget {
  const _FilterChoiceChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final fg = selected ? t.brand.subtleText : t.text.primary;

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      side: BorderSide(color: selected ? t.brand.primary : t.border.normal),
      labelStyle: text.labelMedium?.copyWith(color: fg),
    );
  }
}

/// Secondary page actions. Bulk revoke is a once-a-term job, so it no longer
/// sits in the header at the weight of an everyday action.
class _MoreMenu extends StatelessWidget {
  const _MoreMenu({required this.onBulkRevoke});

  final VoidCallback onBulkRevoke;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      style: _menuStyle(context),
      menuChildren: [
        MenuItemButton(
          leadingIcon: const Icon(Icons.nfc, size: AppSizes.iconSm),
          onPressed: onBulkRevoke,
          child: const Text('Bulk revoke RFID…'),
        ),
      ],
      builder: (context, controller, _) => OutlinedButton.icon(
        icon: const Icon(Icons.expand_more, size: AppSizes.iconSm),
        iconAlignment: IconAlignment.end,
        label: const Text('More'),
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }
}

/// [MenuAnchor] is not covered by the theme's `popupMenuTheme`, so it borrows
/// the same surface, border and radius here to look like the row menus.
MenuStyle _menuStyle(BuildContext context) {
  final t = context.tokens;
  return MenuStyle(
    backgroundColor: WidgetStatePropertyAll(t.surface.overlay),
    surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
    elevation: const WidgetStatePropertyAll(8),
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(
        borderRadius: AppRadii.mdAll,
        side: BorderSide(color: t.border.normal),
      ),
    ),
  );
}

// ── Table cells ──────────────────────────────────────────────────────────────

class _NameCell extends StatelessWidget {
  const _NameCell({required this.user, required this.isSelf});

  final AdminUser user;
  final bool isSelf;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    // Archived accounts used to carry a separate "Archived" column that was
    // an empty cell on every other row. Struck-through text plus the pill
    // says the same thing in the space the name already occupies.
    final nameStyle = user.isDeleted
        ? text.titleSmall?.copyWith(
            color: t.text.tertiary,
            decoration: TextDecoration.lineThrough,
          )
        : text.titleSmall;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (user.isDeleted) ...[
              Icon(
                Icons.archive_outlined,
                size: AppSizes.iconSm,
                color: t.text.tertiary,
              ),
              const SizedBox(width: AppSpacing.x1),
            ],
            Flexible(
              child: Text(
                user.fullName,
                style: nameStyle,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Only staff get a tag. Tagging every row "User" would be noise;
            // the point is that a Security account no longer looks like a
            // student's.
            if (user.isStaff) ...[
              const SizedBox(width: AppSpacing.x2),
              StatusPill(
                label: user.role,
                intent: user.role == UserRoles.admin
                    ? StatusIntent.accent
                    : StatusIntent.info,
                dense: true,
                showDot: false,
              ),
            ],
            if (isSelf) ...[
              const SizedBox(width: AppSpacing.x2),
              Text(
                'You',
                style: text.labelSmall?.copyWith(color: t.text.secondary),
              ),
            ],
          ],
        ),
        Text(
          user.email,
          style: text.bodySmall?.copyWith(color: t.text.secondary),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _CardCell extends StatelessWidget {
  const _CardCell({required this.user});

  final AdminUser user;

  /// First four and last four, which is how a tag is read off the card and
  /// still enough to tell two apart in a list. The full ID is in the tooltip.
  static String _short(String tag) => tag.length <= 10
      ? tag
      : '${tag.substring(0, 4)}…${tag.substring(tag.length - 4)}';

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final tag = user.rfidTagId;

    if (tag == null || tag.isEmpty) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'No card',
            style: text.bodyMedium?.copyWith(color: t.text.tertiary),
          ),
          // A revoked user has no card on purpose; say so, or the row reads
          // the same as someone who was never given one.
          if (user.rfidStatus == 'Revoked')
            Text(
              'Revoked',
              style: text.bodySmall?.copyWith(
                color: t.status.of(StatusIntent.danger).fg,
              ),
            ),
        ],
      );
    }

    final intent = StatusIntents.rfid(user.rfidStatus);
    return Tooltip(
      message: tag,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _short(tag),
            style: text.labelMedium?.copyWith(color: t.text.primary),
          ),
          Text(
            user.rfidStatus,
            style: text.bodySmall?.copyWith(
              color: intent == StatusIntent.success
                  ? t.text.secondary
                  : t.status.of(intent).fg,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Row menu ─────────────────────────────────────────────────────────────────

enum _RowAction {
  assignCard,
  revokeCard,
  archive,
  restore,
  review,
}

/// One "⋯" per row instead of an Archive button on every line, which made a
/// destructive click far too easy. What it offers depends on the
/// state the account is in; Archive is always last, after a divider.
class _RowMenu extends ConsumerWidget {
  const _RowMenu({required this.user});

  final AdminUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final status = user.accountStatus;
    final hasCard = user.rfidTagId?.isNotEmpty ?? false;

    PopupMenuItem<_RowAction> item(
      _RowAction value,
      String label,
      IconData icon, {
      bool danger = false,
      bool enabled = true,
      String? hint,
    }) => PopupMenuItem(
      value: value,
      enabled: enabled,
      child: _MenuRow(
        label: label,
        icon: icon,
        color: danger ? t.status.danger.fg : null,
        hint: hint,
      ),
    );

    // The card item. Only an Active account can hold a card; a Revoked one is
    // final, so it is not offered at all.
    PopupMenuItem<_RowAction> cardItem() => hasCard
        ? item(_RowAction.revokeCard, 'Revoke card…', Icons.block_outlined)
        : item(_RowAction.assignCard, 'Assign card…', Icons.nfc);

    final List<PopupMenuEntry<_RowAction>> entries;
    if (user.isDeleted) {
      entries = [item(_RowAction.restore, 'Restore', Icons.restore)];
    } else if (UserStatuses.isApplicant(status)) {
      // Applicants are decided on the Registrations screen, not managed here.
      entries = [
        item(_RowAction.review, 'Review in Registrations', Icons.open_in_new),
      ];
    } else {
      entries = [
        if (status == UserStatuses.active) ...[
          cardItem(),
          const PopupMenuDivider(),
        ],
        item(
          _RowAction.archive,
          'Archive…',
          Icons.archive_outlined,
          danger: true,
        ),
      ];
    }

    final actions = UserAccountActions(
      ref: ref,
      userId: user.userId,
      fullName: user.fullName,
      rfidTagId: user.rfidTagId,
    );

    return PopupMenuButton<_RowAction>(
      icon: const Icon(Icons.more_horiz),
      tooltip: 'Actions for ${user.fullName}',
      itemBuilder: (_) => entries,
      onSelected: (action) {
        switch (action) {
          case _RowAction.assignCard:
            actions.assignRfid(context);
          case _RowAction.revokeCard:
            actions.revokeRfid(context);
          case _RowAction.archive:
            actions.archive(context);
          case _RowAction.restore:
            actions.restore(context);
          case _RowAction.review:
            context.go('/pending/${user.userId}');
        }
      },
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.label,
    required this.icon,
    this.color,
    this.hint,
  });

  final String label;
  final IconData icon;

  /// Null keeps the menu's own text colour, which also greys out when the
  /// item is disabled.
  final Color? color;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Row(
      children: [
        Icon(icon, size: AppSizes.iconSm, color: color),
        const SizedBox(width: AppSpacing.x3),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: color == null ? null : TextStyle(color: color),
              ),
              if (hint != null)
                Text(
                  hint!,
                  style: text.bodySmall?.copyWith(
                    color: context.tokens.text.tertiary,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Bulk revoke ──────────────────────────────────────────────────────────────
//
// Built for the graduation sweep: dozens of cards coming back at once, all for
// the same reason. The single-user Revoke button on the detail screen does not
// scale to that, and doing it one row at a time is exactly the tedium this
// exists to remove.

Future<void> _bulkRevokeRfid(BuildContext context, WidgetRef ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get(
    ApiEndpoints.users,
    queryParameters: {'page': 1, 'pageSize': 500},
  );
  final page = UserListPage.fromJson(res.data as Map<String, dynamic>);
  final candidates = page.users
      .where(
        (u) =>
            !u.isDeleted &&
            u.rfidStatus != 'Unassigned' &&
            u.rfidStatus != 'Revoked',
      )
      .toList();

  if (!context.mounted) return;

  if (candidates.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No user currently has an RFID tag assigned.'),
      ),
    );
    return;
  }

  final selected = await showDialog<Set<String>>(
    context: context,
    builder: (ctx) => _UserPickerDialog(candidates: candidates),
  );
  if (selected == null || selected.isEmpty || !context.mounted) return;

  final holderName = selected.length == 1
      ? candidates.firstWhere((u) => u.userId == selected.first).fullName
      : '${selected.length} selected users';

  final reasonResult = await showRevokeRfidDialog(
    context,
    holderName: holderName,
  );
  if (reasonResult == null || !context.mounted) return;

  final result = await ref
      .read(userActionsProvider.notifier)
      .bulkRevokeRfid(
        selected.toList(),
        reasonResult.reason,
        reasonResult.note,
      );
  if (!context.mounted) return;

  final message =
      result.error ??
      (result.skippedCount == 0
          ? 'Revoked ${result.revoked} RFID tag${result.revoked == 1 ? '' : 's'}.'
          : 'Revoked ${result.revoked}, skipped ${result.skippedCount}.');

  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  ref.invalidate(userListProvider);
  // Every revoked card lands back in the Free pool the RFID Cards page shows.
  ref.invalidate(rfidCardsProvider);
}

class _UserPickerDialog extends StatefulWidget {
  const _UserPickerDialog({required this.candidates});

  final List<AdminUser> candidates;

  @override
  State<_UserPickerDialog> createState() => _UserPickerDialogState();
}

class _UserPickerDialogState extends State<_UserPickerDialog> {
  final _selected = <String>{};

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return AlertDialog(
      title: const Text('Select users to revoke RFID from'),
      content: SizedBox(
        width: context.dialogWidth(440),
        height: 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Only users with a card currently assigned are listed.',
              style: text.bodySmall?.copyWith(
                color: context.tokens.text.secondary,
              ),
            ),
            const SizedBox(height: AppSpacing.x2),
            Expanded(
              child: ListView(
                children: [
                  for (final user in widget.candidates)
                    CheckboxListTile(
                      dense: true,
                      value: _selected.contains(user.userId),
                      title: Text(user.fullName),
                      subtitle: Text('${user.email} · ${user.rfidStatus}'),
                      onChanged: (checked) => setState(() {
                        if (checked == true) {
                          _selected.add(user.userId);
                        } else {
                          _selected.remove(user.userId);
                        }
                      }),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _selected.isEmpty
              ? null
              : () => Navigator.pop(context, _selected),
          child: Text('Continue (${_selected.length})'),
        ),
      ],
    );
  }
}
