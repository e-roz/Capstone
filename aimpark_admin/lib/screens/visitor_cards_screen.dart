import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/utils/responsive.dart';
import '../models/visitor_card.dart';
import '../providers/visitor_cards_provider.dart';
import '../theme/theme.dart';
import '../widgets/rfid_scan_field.dart';
import '../widgets/ui/ui.dart';

final _stamp = DateFormat('MMM d, HH:mm');

/// The cards kept at the guard post for lending to visitors.
///
/// Admin only. A card registered here is known to the gate as a visitor card
/// before anyone holds it: tapping it while idle asks the guard who is in the
/// car instead of refusing it as unknown. Security sees the same cards, and
/// where each one is, on Visitor Passes.
class VisitorCardsScreen extends ConsumerWidget {
  const VisitorCardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardsAsync = ref.watch(visitorCardsProvider(admin: true));

    return AppPage(
      title: 'Visitor Cards',
      subtitle: 'Cards kept at the guard post for lending to visitors. Each '
          "visitor's name stays on the log for the time they held it.",
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
          onPressed: () => ref.invalidate(visitorCardsProvider),
        ),
        const SizedBox(width: AppSpacing.x2),
        FilledButton.icon(
          onPressed: () => _showAddDialog(context, ref),
          icon: const Icon(Icons.add),
          label: const Text('Add visitor card'),
        ),
      ],
      body: AsyncView(
        value: cardsAsync,
        onRetry: () => ref.invalidate(visitorCardsProvider),
        loading: const SkeletonTable(
          columns: 5,
          columnWidths: [80, 160, 140, 220, 160],
        ),
        isEmpty: (cards) => cards.isEmpty,
        empty: AppEmptyState(
          icon: Icons.style_outlined,
          title: 'No visitor cards yet',
          message: 'Add the cards the guards lend to visitors. Until a card is '
              'here, the gate refuses it as unknown.',
          action: FilledButton.icon(
            onPressed: () => _showAddDialog(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('Add visitor card'),
          ),
        ),
        data: (cards) => AppDataTable(
          minWidth: 900,
          columns: const [
            DataColumn(label: Text('Label')),
            DataColumn(label: Text('Tag ID')),
            DataColumn(label: Text('Where')),
            DataColumn(label: Text('Last visitor')),
            DataColumn(label: Text('Actions')),
          ],
          rows: [for (final card in cards) _row(context, ref, card)],
        ),
      ),
    );
  }

  DataRow _row(BuildContext context, WidgetRef ref, VisitorCard card) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    final intent = switch (card.whereabouts) {
      'InDrawer' => StatusIntent.success,
      'OutWithVisitor' => StatusIntent.info,
      'NotYetReturned' => StatusIntent.warning,
      _ => StatusIntent.danger,
    };

    return DataRow(cells: [
      DataCell(Text(card.label, style: text.titleSmall)),
      DataCell(Text(card.rfidTagId,
          style: text.bodySmall?.copyWith(color: t.text.secondary))),
      DataCell(Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StatusPill.of(visitorCardWhereaboutsLabel(card.whereabouts),
              intent: intent, dense: true),
          if (card.isBlocked && (card.note?.isNotEmpty ?? false))
            Text(card.note!,
                style: text.bodySmall?.copyWith(color: t.text.secondary)),
        ],
      )),
      DataCell(card.lastVisitorName == null
          ? Text('Never lent',
              style: text.bodySmall?.copyWith(color: t.text.tertiary))
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${card.lastVisitorName} · ${card.lastPlateNumber ?? ''}'),
                Text(
                  [
                    if (card.lastIssuedAt case final at?)
                      'In ${_stamp.format(at.toLocal())}',
                    if (card.lastReturnedAt case final at?)
                      'out ${_stamp.format(at.toLocal())}',
                    '${card.timesLent} visitor${card.timesLent == 1 ? '' : 's'} so far',
                  ].join(' · '),
                  style: text.bodySmall?.copyWith(color: t.text.secondary),
                ),
              ],
            )),
      DataCell(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (card.isBlocked)
            AppRowAction(
              label: 'Unblock',
              icon: Icons.lock_open_outlined,
              onPressed: () => _run(context, ref,
                  ref.read(visitorCardActionsProvider.notifier).unblock(card.rfidTagId)),
            )
          else
            AppRowAction(
              label: 'Block',
              icon: Icons.block,
              intent: StatusIntent.danger,
              onPressed: () => _showBlockDialog(context, ref, card),
            ),
          // A card with history stays, so its past logs still say which card.
          if (card.timesLent == 0) ...[
            const SizedBox(width: AppSpacing.x2),
            AppRowAction(
              label: 'Remove',
              icon: Icons.delete_outline,
              onPressed: () => _run(context, ref,
                  ref.read(visitorCardActionsProvider.notifier).remove(card.rfidTagId)),
            ),
          ],
        ],
      )),
    ]);
  }

  Future<void> _run(
      BuildContext context, WidgetRef ref, Future<String?> action) async {
    final msg = await action;
    if (!context.mounted || msg == null) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _showAddDialog(BuildContext context, WidgetRef ref) async {
    final cardCtrl = TextEditingController();
    final labelCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add a Visitor Card'),
        content: SizedBox(
          width: context.dialogWidth(440),
          child: Form(
            key: formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppRequiredNote(),
                RfidScanField(controller: cardCtrl),
                const SizedBox(height: AppSpacing.x3),
                TextFormField(
                  controller: labelCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    label: AppFieldLabel('Label', isRequired: true),
                    helperText:
                        'What is written on the card, so guards can tell them '
                        'apart (e.g. V1).',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'A label is required'
                      : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
            },
            child: const Text('Add card'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    await _run(
      context,
      ref,
      ref.read(visitorCardActionsProvider.notifier).add(
            rfidTagId: cardCtrl.text.trim(),
            label: labelCtrl.text.trim(),
          ),
    );
  }

  Future<void> _showBlockDialog(
      BuildContext context, WidgetRef ref, VisitorCard card) async {
    final noteCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Block visitor card ${card.label}'),
        content: SizedBox(
          width: context.dialogWidth(400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('The gate will refuse this card, and guards can no '
                  'longer lend it. Unblock it if it turns up.'),
              const SizedBox(height: AppSpacing.x3),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(
                  label: AppFieldLabel('Why'),
                  hintText: 'Lost, broken, not returned…',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: context.tokens.status.danger.solid),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Block card'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    await _run(
      context,
      ref,
      ref.read(visitorCardActionsProvider.notifier).block(card.rfidTagId,
          note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim()),
    );
  }
}
