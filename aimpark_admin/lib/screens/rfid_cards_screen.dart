import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../core/constants/api_endpoints.dart';
import '../core/network/dio_client.dart';
import '../core/utils/responsive.dart';
import '../models/admin_user.dart';
import '../models/rfid_card.dart';
import '../providers/users_provider.dart';
import '../theme/theme.dart';
import '../widgets/rfid_revoke_dialog.dart';
import '../widgets/ui/ui.dart';

final _stamp = DateFormat('MMM d, yyyy HH:mm');
final _day = DateFormat('MMM d, yyyy');

/// The chips above the table, in order. A null value means "no filter".
const _filters = <(String, String?)>[
  ('All', null),
  ('Assigned', RfidCardStates.assigned),
  ('Free', RfidCardStates.free),
  ('Blocked', RfidCardStates.blocked),
];

/// Every physical card the system knows about: held by a user right now,
/// revoked and free to give out again, or revoked and blocked for good.
///
/// Cards on an account live on `User.RfidTagId`; revoked ones live in the
/// `RfidCard` pool. The API merges the two so this screen can show one list.
class RfidCardsScreen extends ConsumerStatefulWidget {
  const RfidCardsScreen({super.key});

  @override
  ConsumerState<RfidCardsScreen> createState() => _RfidCardsScreenState();
}

class _RfidCardsScreenState extends ConsumerState<RfidCardsScreen> {
  String? _filter;
  String _search = '';
  String? _selectedTag;

  /// Filtering and search run on the client: the whole list is already here
  /// for the chip counts, and a card list is hundreds of rows, not thousands.
  List<RfidCard> _visible(List<RfidCard> cards) {
    final q = _search.toLowerCase();
    // Tags are stored without separators, so "04:A2" should still find 04A2.
    final qTag = q.replaceAll(RegExp(r'[\s:\-_]'), '');

    return cards.where((c) {
      if (_filter != null && c.state != _filter) return false;
      if (q.isEmpty) return true;
      return (qTag.isNotEmpty && c.rfidTagId.toLowerCase().contains(qTag)) ||
          (c.holderName ?? '').toLowerCase().contains(q) ||
          (!c.isAssigned && c.lastUserName.toLowerCase().contains(q));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final cardsAsync = ref.watch(rfidCardsProvider);

    return AppPage(
      title: 'RFID cards',
      subtitle: 'Every card: held by a user, free to give out, or blocked.',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
          onPressed: () => ref.invalidate(rfidCardsProvider),
        ),
      ],
      toolbar: AppToolbar(
        filters: [
          _FilterChips(
            cards: cardsAsync.valueOrNull,
            value: _filter,
            onChanged: (v) => setState(() => _filter = v),
          ),
        ],
        search: AppSearchField(
          hint: 'Search tag ID or name',
          onChanged: (v) => setState(() => _search = v),
        ),
      ),
      body: AsyncView<List<RfidCard>>(
        value: cardsAsync,
        onRetry: () => ref.invalidate(rfidCardsProvider),
        loading: const SkeletonTable(
          columns: 5,
          columnWidths: [150, 90, 200, 200, 130],
        ),
        isEmpty: (cards) => cards.isEmpty,
        empty: const AppEmptyState(
          icon: Icons.nfc,
          title: 'No cards yet',
          message: 'Cards show up here once one is assigned to a user.',
        ),
        data: _body,
      ),
    );
  }

  Widget _body(List<RfidCard> cards) {
    final visible = _visible(cards);
    // Looked up in the visible rows, so a filter or search that hides the
    // card also hides its panel instead of showing details for a row that is
    // not on screen.
    final selected = visible
        .where((c) => c.rfidTagId == _selectedTag)
        .firstOrNull;

    final table = visible.isEmpty
        ? AppEmptyState(
            icon: Icons.search_off,
            title: 'No cards match',
            message: 'Try another filter or search.',
            action: _filter == null
                ? null
                : TextButton(
                    onPressed: () => setState(() => _filter = null),
                    child: const Text('Show all cards'),
                  ),
          )
        : AppDataTable(
            minWidth: 860,
            columns: const [
              DataColumn(label: Text('Tag ID')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Holder')),
              DataColumn(label: Text('Reason')),
              DataColumn(label: Text('Updated')),
            ],
            rows: [for (final card in visible) _row(card)],
          );

    if (selected == null) return table;

    // Under the table, not beside it: the table needs its full width for five
    // columns, and the panel's history reads better as a wide strip.
    return LayoutBuilder(
      builder: (context, box) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: table),
          const SizedBox(height: AppSpacing.gutter),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: box.maxHeight * 0.55),
            child: SingleChildScrollView(
              child: _CardPanel(
                key: ValueKey(selected.rfidTagId),
                card: selected,
                onClose: () => setState(() => _selectedTag = null),
              ),
            ),
          ),
        ],
      ),
    );
  }

  DataRow _row(RfidCard card) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final isSelected = card.rfidTagId == _selectedTag;

    return DataRow(
      selected: isSelected,
      onSelectChanged: (_) =>
          setState(() => _selectedTag = isSelected ? null : card.rfidTagId),
      cells: [
        DataCell(
          Text(
            card.rfidTagId,
            style: text.labelMedium?.copyWith(color: t.text.primary),
          ),
        ),
        DataCell(
          StatusPill.of(
            card.state,
            intent: StatusIntents.rfidCard(card.state),
            dense: true,
          ),
        ),
        DataCell(_HolderCell(card: card)),
        DataCell(
          AppPrimaryCell(
            title: _reasonTitle(card),
            subtitle: _reasonLine(card),
          ),
        ),
        DataCell(
          Text(
            card.updatedAt == null
                ? '—'
                : _stamp.format(card.updatedAt!.toLocal()),
            style: text.bodySmall?.copyWith(color: t.text.secondary),
          ),
        ),
      ],
    );
  }
}

// ── Labels ───────────────────────────────────────────────────────────────────

/// The small line under a holder's name: student number when there is one,
/// otherwise what kind of account it is.
String _holderLine(RfidCard card) {
  final kind = switch (card.holderRole) {
    'Admin' => 'Admin',
    'Security' => 'Security guard',
    _ =>
      card.holderStudentNumber?.isNotEmpty == true
          ? card.holderStudentNumber!
          : (card.holderAffiliation ?? 'User'),
  };
  return card.holderArchived ? '$kind · archived' : kind;
}

String _reasonTitle(RfidCard card) {
  if (card.isAssigned) {
    if (card.holderArchived) return 'Account archived';
    return card.holderRfidStatus == 'Suspended' ? 'Suspended' : '—';
  }
  return RfidRevokeReasons.label(card.reason);
}

String? _reasonLine(RfidCard card) {
  if (card.isAssigned) {
    if (card.holderArchived) return 'Card was not taken back';
    if (card.holderRfidStatus != 'Suspended') return 'In use';
    final until = card.holderSuspendedUntil;
    return until == null
        ? 'Gate access paused'
        : 'Gate access paused until ${_day.format(until.toLocal())}';
  }
  if (card.note case final note? when note.isNotEmpty) return note;
  if (card.isBlocked) return 'Cannot be reissued';
  return switch (card.reason) {
    RfidRevokeReasons.violationLimit => 'Taken after 3 violations',
    RfidRevokeReasons.graduated => 'Holder graduated',
    _ => 'Free to give out',
  };
}

// ── Toolbar ──────────────────────────────────────────────────────────────────

class _FilterChips extends StatelessWidget {
  const _FilterChips({
    required this.cards,
    required this.value,
    required this.onChanged,
  });

  /// Null while loading — the chips still work, they just have no counts.
  final List<RfidCard>? cards;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    String label(String name, String? state) {
      final list = cards;
      if (list == null) return name;
      final n = state == null
          ? list.length
          : list.where((c) => c.state == state).length;
      return '$name $n';
    }

    return Wrap(
      spacing: AppSpacing.controlGap,
      runSpacing: AppSpacing.controlGap,
      children: [
        for (final (name, state) in _filters)
          ChoiceChip(
            label: Text(label(name, state)),
            selected: value == state,
            onSelected: (_) => onChanged(state),
            // The theme's tint alone is too faint to tell which chip is on;
            // this matches how AppFilterDropdown marks an active filter.
            side: BorderSide(
              color: value == state ? t.brand.primary : t.border.normal,
            ),
            labelStyle: text.labelMedium?.copyWith(
              color: value == state ? t.brand.subtleText : t.text.primary,
            ),
          ),
      ],
    );
  }
}

// ── Table cells ──────────────────────────────────────────────────────────────

class _HolderCell extends StatelessWidget {
  const _HolderCell({required this.card});

  final RfidCard card;

  @override
  Widget build(BuildContext context) {
    if (card.isAssigned) {
      return AppPrimaryCell(
        title: card.holderName ?? 'Unknown user',
        subtitle: _holderLine(card),
      );
    }

    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Not held',
          style: text.titleSmall?.copyWith(color: t.text.secondary),
        ),
        if (card.lastUserName.isNotEmpty)
          Text(
            'Last held by ${card.lastUserName}',
            style: text.bodySmall?.copyWith(color: t.text.secondary),
          ),
      ],
    );
  }
}

// ── Detail panel ─────────────────────────────────────────────────────────────

class _CardPanel extends ConsumerWidget {
  const _CardPanel({super.key, required this.card, required this.onClose});

  final RfidCard card;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    final summary = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.x3,
          runSpacing: AppSpacing.x2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              card.rfidTagId,
              style: text.labelMedium?.copyWith(color: t.text.primary),
            ),
            StatusPill.of(
              card.state,
              intent: StatusIntents.rfidCard(card.state),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.headingGap),
        AppFieldGrid(
          minColumnWidth: 200,
          fields: [
            AppField(
              label: card.isAssigned ? 'Holder' : 'Last held by',
              child: _PanelHolder(card: card),
            ),
            if (!card.isAssigned)
              AppField(
                label: 'Reason',
                value: RfidRevokeReasons.label(card.reason),
              ),
            if (card.note case final note? when note.isNotEmpty)
              AppField(label: 'Note', value: note),
            if (card.isAssigned && card.holderRfidStatus == 'Suspended')
              AppField(label: 'Gate access', value: _reasonLine(card)),
            AppField(
              label: card.isAssigned ? 'Assigned' : 'Revoked',
              value: card.updatedAt == null
                  ? 'Not in the audit log'
                  : _stamp.format(card.updatedAt!.toLocal()),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.headingGap),
        _PanelAction(card: card),
      ],
    );

    final history = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('History', style: text.titleSmall),
        const SizedBox(height: AppSpacing.x2),
        _History(rfidTagId: card.rfidTagId),
      ],
    );

    return AppSectionCard(
      title: 'Card details',
      icon: Icons.nfc,
      actions: [
        IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Close',
          onPressed: onClose,
        ),
      ],
      child: LayoutBuilder(
        builder: (context, box) => box.maxWidth >= 720
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: summary),
                  const SizedBox(width: AppSpacing.sectionGap),
                  Expanded(child: history),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  summary,
                  const SizedBox(height: AppSpacing.sectionGap),
                  history,
                ],
              ),
      ),
    );
  }
}

class _PanelHolder extends StatelessWidget {
  const _PanelHolder({required this.card});

  final RfidCard card;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    final userId = card.isAssigned ? card.holderUserId : card.lastUserId;
    final name = card.isAssigned ? card.holderName : card.lastUserName;
    if (userId == null || userId.isEmpty || name == null || name.isEmpty) {
      return Text(
        card.isAssigned ? 'Unknown user' : 'Not held',
        style: text.bodyMedium,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name, style: text.titleSmall),
        if (card.isAssigned)
          Text(
            _holderLine(card),
            style: text.bodySmall?.copyWith(color: t.text.secondary),
          ),
        TextButton.icon(
          onPressed: () => context.go('/users/$userId'),
          icon: const Icon(Icons.arrow_forward, size: AppSizes.iconSm),
          label: const Text('Open user'),
        ),
      ],
    );
  }
}

class _PanelAction extends ConsumerWidget {
  const _PanelAction({required this.card});

  final RfidCard card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    if (card.isBlocked) {
      final reason = RfidRevokeReasons.label(card.reason).toLowerCase();
      return Container(
        padding: const EdgeInsets.all(AppSpacing.x3),
        decoration: BoxDecoration(
          color: t.status.danger.bg,
          borderRadius: AppRadii.mdAll,
        ),
        child: Text(
          'This card was reported $reason and cannot be reissued.',
          style: text.bodySmall?.copyWith(color: t.status.danger.fg),
        ),
      );
    }

    if (card.isAssigned) {
      return OutlinedButton.icon(
        onPressed: () => _revoke(context, ref),
        icon: const Icon(Icons.block, size: AppSizes.iconSm),
        label: const Text('Revoke card'),
      );
    }

    return FilledButton.icon(
      onPressed: () => _assign(context, ref),
      icon: const Icon(Icons.person_add_alt, size: AppSizes.iconSm),
      label: const Text('Assign to a user'),
    );
  }

  /// The same dialog and endpoint as the Revoke button on User Detail, so
  /// the two cannot disagree about what a reason does to the card.
  Future<void> _revoke(BuildContext context, WidgetRef ref) async {
    final userId = card.holderUserId;
    if (userId == null) return;

    final result = await showRevokeRfidDialog(
      context,
      holderName: card.holderName ?? 'this user',
    );
    if (result == null || !context.mounted) return;

    final msg = await ref
        .read(userActionsProvider.notifier)
        .revokeRfid(userId, result.reason, result.note);
    if (!context.mounted) return;
    _done(context, ref, msg ?? 'Card revoked.');
  }

  /// Picks a user, then calls the same assign endpoint as User Detail. The
  /// API still enforces every rule (Active, or Revoked to reinstate; not
  /// Blocked; not a visitor card) — the picker only hides users who would
  /// obviously fail.
  Future<void> _assign(BuildContext context, WidgetRef ref) async {
    final user = await showDialog<AdminUser>(
      context: context,
      builder: (_) => _AssignDialog(rfidTagId: card.rfidTagId),
    );
    if (user == null || !context.mounted) return;

    final msg = await ref
        .read(userActionsProvider.notifier)
        .assignRfid(user.userId, card.rfidTagId);
    if (!context.mounted) return;
    _done(context, ref, msg ?? 'Card assigned.');
  }

  void _done(BuildContext context, WidgetRef ref, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    ref.invalidate(rfidCardsProvider);
    ref.invalidate(rfidCardHistoryProvider(card.rfidTagId));
    ref.invalidate(userListProvider);
  }
}

class _History extends ConsumerWidget {
  const _History({required this.rfidTagId});

  final String rfidTagId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(rfidCardHistoryProvider(rfidTagId));
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    return async.when(
      // The panel sits in a scroll view, so AsyncView's fill-the-space
      // states would have no height to fill. Same skeleton, sized to content.
      loading: () => const SkeletonList(count: 3),
      error: (e, _) => Row(
        children: [
          Expanded(
            child: Text(
              'Could not load the history.',
              style: text.bodySmall?.copyWith(color: t.status.danger.fg),
            ),
          ),
          TextButton(
            onPressed: () => ref.invalidate(rfidCardHistoryProvider(rfidTagId)),
            child: const Text('Retry'),
          ),
        ],
      ),
      data: (entries) => entries.isEmpty
          ? Text(
              'Nothing in the audit log for this card. Cards given out '
              'before the audit log existed have no history.',
              style: text.bodySmall?.copyWith(color: t.text.secondary),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < entries.length; i++)
                  _HistoryRow(entry: entries[i], last: i == entries.length - 1),
              ],
            ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.entry, required this.last});

  final RfidCardHistoryEntry entry;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    final (title, intent) = switch (entry.action) {
      'AssignRfid' => ('Assigned to ${entry.userName}', StatusIntent.success),
      'Reinstate' => ('${entry.userName} reinstated', StatusIntent.info),
      'RevokeRfid' => (
        'Revoked from ${entry.userName}'
            '${entry.reason == null ? '' : ' · ${RfidRevokeReasons.label(entry.reason!)}'}',
        RfidRevokeReasons.blocks(entry.reason ?? '')
            ? StatusIntent.danger
            : StatusIntent.warning,
      ),
      _ => (entry.action, StatusIntent.neutral),
    };

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The timeline rail: a dot per event, joined by a line.
          SizedBox(
            width: AppSpacing.x4,
            child: Column(
              children: [
                const SizedBox(height: AppSpacing.x1),
                Container(
                  width: AppSpacing.x2,
                  height: AppSpacing.x2,
                  decoration: BoxDecoration(
                    color: t.status.of(intent).solid,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!last)
                  Expanded(child: Container(width: 1, color: t.border.normal)),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.x2),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : AppSpacing.x3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: text.bodyMedium),
                  Text(
                    'By ${entry.actorName} · '
                    '${_stamp.format(entry.createdAt.toLocal())}',
                    style: text.bodySmall?.copyWith(color: t.text.secondary),
                  ),
                  if (entry.note case final note? when note.isNotEmpty)
                    Text(
                      note,
                      style: text.bodySmall?.copyWith(color: t.text.secondary),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Assign dialog ────────────────────────────────────────────────────────────

/// Picks who gets a Free card. Lists only users who can take one: Active, or
/// Revoked (assigning reinstates them), and with no card already — assigning
/// over an existing card would drop that card without filing it as free.
class _AssignDialog extends ConsumerStatefulWidget {
  const _AssignDialog({required this.rfidTagId});

  final String rfidTagId;

  @override
  ConsumerState<_AssignDialog> createState() => _AssignDialogState();
}

class _AssignDialogState extends ConsumerState<_AssignDialog> {
  List<AdminUser>? _users;
  Object? _error;
  AdminUser? _picked;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _load('');
  }

  Future<void> _load(String query) async {
    final request = ++_request;
    setState(() {
      _users = null;
      _error = null;
    });

    try {
      final res = await ref
          .read(dioProvider)
          .get(
            ApiEndpoints.users,
            queryParameters: {
              'page': 1,
              'pageSize': 50,
              if (query.isNotEmpty) 'search': query,
            },
          );
      final page = UserListPage.fromJson(res.data as Map<String, dynamic>);
      if (!mounted || request != _request) return;
      setState(
        () => _users = page.users
            .where(
              (u) =>
                  !u.isDeleted &&
                  (u.accountStatus == 'Active' ||
                      u.accountStatus == 'Revoked') &&
                  (u.rfidStatus == 'Unassigned' || u.rfidStatus == 'Revoked'),
            )
            .toList(),
      );
    } catch (e) {
      if (!mounted || request != _request) return;
      setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final picked = _picked;
    final users = _users;

    return AlertDialog(
      title: Text('Assign card ${widget.rfidTagId}'),
      content: SizedBox(
        width: context.dialogWidth(460),
        height: context.dialogHeight(440),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppSearchField(
              hint: 'Search name or email',
              width: double.infinity,
              onChanged: _load,
            ),
            const SizedBox(height: AppSpacing.x2),
            Text(
              'Only users without a card are listed. A revoked user is '
              'reinstated when they get a card.',
              style: text.bodySmall?.copyWith(color: t.text.secondary),
            ),
            const SizedBox(height: AppSpacing.x2),
            Expanded(
              child: _error != null
                  ? AppErrorState(
                      error: _error!,
                      title: 'Could not load users',
                      onRetry: () => _load(''),
                    )
                  : users == null
                  ? const SingleChildScrollView(child: SkeletonList(count: 4))
                  : users.isEmpty
                  ? const AppEmptyState(
                      icon: Icons.person_search,
                      title: 'No users found',
                      message: 'Try another name or email.',
                    )
                  : ListView(
                      children: [
                        for (final u in users)
                          ListTile(
                            dense: true,
                            selected: picked?.userId == u.userId,
                            selectedTileColor: t.surface.selected,
                            title: Text(u.fullName),
                            subtitle: Text(
                              u.accountStatus == 'Revoked'
                                  ? '${u.email} · revoked'
                                  : u.email,
                            ),
                            trailing: picked?.userId == u.userId
                                ? Icon(Icons.check, color: t.brand.primary)
                                : null,
                            onTap: () => setState(() => _picked = u),
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
          onPressed: picked == null
              ? null
              : () => Navigator.pop(context, picked),
          child: Text(
            picked?.accountStatus == 'Revoked'
                ? 'Assign and reinstate'
                : 'Assign',
          ),
        ),
      ],
    );
  }
}
