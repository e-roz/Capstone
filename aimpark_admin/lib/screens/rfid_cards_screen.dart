import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/rfid_card.dart';
import '../providers/users_provider.dart';
import '../theme/theme.dart';
import '../widgets/ui/ui.dart';

const _states = [
  AppFilterOption('Free', 'Free'),
  AppFilterOption('Blocked', 'Blocked'),
];

final _stamp = DateFormat('MMM d, yyyy HH:mm');

/// The physical cards an admin is holding that are not on anyone's account
/// right now — either free to hand to a new user, or blocked because they
/// left circulation the wrong way. See `RfidCard` on the API for the rule.
class RfidCardsScreen extends ConsumerStatefulWidget {
  const RfidCardsScreen({super.key});

  @override
  ConsumerState<RfidCardsScreen> createState() => _RfidCardsScreenState();
}

class _RfidCardsScreenState extends ConsumerState<RfidCardsScreen> {
  String? _state;

  @override
  Widget build(BuildContext context) {
    final cardsAsync = ref.watch(rfidCardsProvider(cardState: _state));

    return AppPage(
      title: 'RFID Cards',
      subtitle: 'Physical cards revoked from an account and not yet reissued.',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
          onPressed: () => ref.invalidate(rfidCardsProvider),
        ),
      ],
      toolbar: AppToolbar(
        filters: [
          AppFilterDropdown<String>(
            label: 'State',
            value: _state,
            options: _states,
            allLabel: 'Free and blocked',
            onChanged: (v) => setState(() => _state = v),
          ),
        ],
      ),
      body: AsyncView(
        value: cardsAsync,
        onRetry: () => ref.invalidate(rfidCardsProvider),
        isEmpty: (cards) => cards.isEmpty,
        empty: const AppEmptyState(
          icon: Icons.nfc,
          title: 'No cards here',
          message: 'Revoked cards show up here once an admin takes one off '
              'an account.',
        ),
        data: (cards) => AppDataTable(
          minWidth: 900,
          columns: const [
            DataColumn(label: Text('Tag ID')),
            DataColumn(label: Text('State')),
            DataColumn(label: Text('Reason')),
            DataColumn(label: Text('Last held by')),
            DataColumn(label: Text('Revoked')),
          ],
          rows: [for (final card in cards) _row(context, card)],
        ),
      ),
    );
  }

  DataRow _row(BuildContext context, RfidCard card) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    return DataRow(cells: [
      DataCell(Text(card.rfidTagId, style: text.titleSmall)),
      DataCell(StatusPill.of(
        card.state,
        intent: card.state == 'Blocked'
            ? StatusIntent.danger
            : StatusIntent.success,
        dense: true,
      )),
      DataCell(Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(RfidRevokeReasons.label(card.reason)),
          if (card.note case final note? when note.isNotEmpty)
            Text(note,
                style: text.bodySmall?.copyWith(color: t.text.secondary)),
        ],
      )),
      DataCell(Text(card.lastUserName)),
      DataCell(Text(
        _stamp.format(card.updatedAt.toLocal()),
        style: text.bodySmall?.copyWith(color: t.text.secondary),
      )),
    ]);
  }
}
