import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/utils/responsive.dart';
import '../models/security.dart';
import '../models/visitor_card.dart';
import '../providers/security_provider.dart';
import '../providers/visitor_cards_provider.dart';
import '../theme/theme.dart';
import '../widgets/rfid_scan_field.dart';
import '../widgets/ui/ui.dart';
import '../widgets/visitor_details_fields.dart';

const _passStatuses = ['Active', 'Returned', 'Expired'];

/// The drawer of visitor cards, and who is holding them.
///
/// Cards are normally lent at the gate: tapping an idle visitor card pops the
/// visitor form wherever the guard is (see `VisitorRegistrationWatcher`), and
/// the visitor's exit tap ends the pass. "Issue a card" here is the desk
/// fallback for when a gate reader is down.
///
/// Defaults to the Active filter rather than to everything, because the
/// question a guard actually has is "which of my cards are out?" — the history
/// matters at the end of the day, and the missing card matters now. Cards
/// released at the exit but not handed back show in the strip on top.
class VisitorPassesScreen extends ConsumerWidget {
  const VisitorPassesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(visitorPassQueryNotifierProvider);
    final notifier = ref.read(visitorPassQueryNotifierProvider.notifier);

    return AppPage(
      title: 'Visitor Passes',
      subtitle: 'Tap an idle visitor card at the entry gate to lend it. The '
          "visitor's exit tap releases it; mark it returned once it is back.",
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppToolbar(
            filters: [
              AppFilterDropdown<String>(
                label: 'Status',
                value: query.status,
                options: [for (final s in _passStatuses) AppFilterOption(s, s)],
                allLabel: 'All passes',
                onChanged: notifier.setStatus,
              ),
            ],
            trailing: [
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
                onPressed: () {
                  ref.invalidate(visitorPassListProvider);
                  ref.invalidate(visitorCardsProvider);
                },
              ),
              const SizedBox(width: AppSpacing.x2),
              FilledButton.icon(
                onPressed: () => _showIssueDialog(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Issue a card'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.headingGap),
          const _CardStrip(),
          Expanded(
            child: AsyncView(
              value: ref.watch(visitorPassListProvider),
              onRetry: () => ref.invalidate(visitorPassListProvider),
              loading: const SkeletonList(),
              isEmpty: (page) => page.passes.isEmpty,
              empty: AppEmptyState(
                icon: Icons.badge_outlined,
                title: query.status == 'Active'
                    ? 'No cards are out'
                    : 'No visitor passes',
                message: query.status == 'Active'
                    ? 'Every visitor card is in the drawer. Tap one at the entry gate when a guest arrives.'
                    : 'Clear the filter to see every pass ever issued.',
                action: FilledButton.icon(
                  onPressed: () => _showIssueDialog(context, ref),
                  icon: const Icon(Icons.add),
                  label: const Text('Issue a card'),
                ),
              ),
              data: (page) => Column(
                children: [
                  Expanded(
                    child: ListView.separated(
                      itemCount: page.passes.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.gutter),
                      itemBuilder: (context, i) =>
                          _PassCard(pass: page.passes[i]),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.gutter),
                  AppPagination(
                    page: page.page,
                    pageSize: page.pageSize,
                    total: page.totalCount,
                    itemLabel: 'passes',
                    onPage: notifier.setPage,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showIssueDialog(BuildContext context, WidgetRef ref) async {
    final cardCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final plateCtrl = TextEditingController();
    final purposeCtrl = TextEditingController();
    var vehicleType = 'Car';
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Issue a Visitor Card at the Desk'),
          content: SizedBox(
            width: context.dialogWidth(440),
            child: Form(
              key: formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AppRequiredNote(),
                    RfidScanField(controller: cardCtrl),
                    const SizedBox(height: AppSpacing.x2),
                    Text(
                      'Only a registered visitor card works. Usually you '
                      'don\'t need this: tap the card at the entry gate and '
                      'the form pops up there.',
                      style: Theme.of(ctx).textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.x3),
                    VisitorDetailsFields(
                      name: nameCtrl,
                      plate: plateCtrl,
                      purpose: purposeCtrl,
                      vehicleType: vehicleType,
                      onVehicleTypeChanged: (v) =>
                          setState(() => vehicleType = v),
                    ),
                  ],
                ),
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
              child: const Text('Issue card'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final msg = await ref.read(visitorPassActionsProvider.notifier).issue(
          rfidTagId: cardCtrl.text.trim(),
          visitorName: nameCtrl.text.trim(),
          plateNumber: plateCtrl.text.trim(),
          vehicleType: vehicleType,
          purpose: purposeCtrl.text.trim(),
        );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg ?? 'Card issued.')));
    ref.invalidate(visitorPassListProvider);
    ref.invalidate(visitorsOnSiteCountProvider);
    ref.invalidate(visitorCardsProvider);
  }
}

/// Every visitor card at a glance: in the drawer, out, or released at the
/// exit but not handed back — the last being the one a guard has to chase.
class _CardStrip extends ConsumerWidget {
  const _CardStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = ref.watch(visitorCardsProvider()).valueOrNull;
    if (cards == null) return const SizedBox.shrink();

    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    if (cards.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.headingGap),
        child: Text(
          'No visitor cards are registered yet. An admin adds them under '
          'System > Visitor Cards.',
          style: text.bodySmall?.copyWith(color: t.text.secondary),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.headingGap),
      child: Wrap(
        spacing: AppSpacing.x2,
        runSpacing: AppSpacing.x2,
        children: [for (final card in cards) _CardChip(card: card)],
      ),
    );
  }
}

class _CardChip extends ConsumerWidget {
  const _CardChip({required this.card});

  final VisitorCard card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final t = context.tokens;

    final intent = switch (card.whereabouts) {
      'InDrawer' => StatusIntent.success,
      'OutWithVisitor' => StatusIntent.info,
      'NotYetReturned' => StatusIntent.warning,
      _ => StatusIntent.danger,
    };

    final who = switch (card.whereabouts) {
      'OutWithVisitor' || 'NotYetReturned' => card.lastVisitorName,
      _ => null,
    };

    return AppCard(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x3, vertical: AppSpacing.x2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(card.label, style: text.titleSmall),
          const SizedBox(width: AppSpacing.x2),
          StatusPill.of(visitorCardWhereaboutsLabel(card.whereabouts),
              intent: intent, dense: true),
          if (who != null) ...[
            const SizedBox(width: AppSpacing.x2),
            Text(who,
                style: text.bodySmall?.copyWith(color: t.text.secondary)),
          ],
          if (card.whereabouts == 'NotYetReturned' &&
              card.lastPassId != null) ...[
            const SizedBox(width: AppSpacing.x2),
            AppRowAction(
              label: 'Card returned',
              icon: Icons.inventory_2_outlined,
              intent: StatusIntent.neutral,
              onPressed: () => _confirmReturned(context, ref, card.lastPassId!),
            ),
          ],
        ],
      ),
    );
  }
}

Future<void> _confirmReturned(
    BuildContext context, WidgetRef ref, String passId) async {
  final msg = await ref
      .read(visitorPassActionsProvider.notifier)
      .confirmCardReturned(passId);

  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg ?? 'Card marked as returned.')));
  ref.invalidate(visitorPassListProvider);
  ref.invalidate(visitorCardsProvider);
}

class _PassCard extends ConsumerWidget {
  const _PassCard({required this.pass});

  final VisitorPass pass;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    final intent = switch (pass.status) {
      'Active' => StatusIntent.success,
      'Returned' => StatusIntent.neutral,
      // Expired means a card is out past its day and nobody has it back. That
      // is a missing card, not a tidy end state.
      _ => StatusIntent.warning,
    };

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StatusPill.of(pass.status, intent: intent, dense: true),
              const SizedBox(width: AppSpacing.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(pass.visitorName, style: text.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      '${pass.cardLabel == null ? 'Card ${pass.rfidTagId}' : 'Card ${pass.cardLabel}'} · ${pass.plateNumber} · ${pass.vehicleType}',
                      style: text.bodySmall?.copyWith(color: t.text.secondary),
                    ),
                  ],
                ),
              ),
              if (pass.isInside)
                StatusPill.of(
                  pass.slotCode == null ? 'Inside' : 'At ${pass.slotCode}',
                  intent: StatusIntent.info,
                  dense: true,
                  showDot: false,
                  icon: Icons.directions_car_outlined,
                ),
              if (pass.cardNotYetReturned)
                StatusPill.of(
                  'Card not yet returned',
                  intent: StatusIntent.warning,
                  dense: true,
                  showDot: false,
                  icon: Icons.credit_card_off_outlined,
                ),
            ],
          ),
          if (pass.purpose case final purpose?) ...[
            const SizedBox(height: AppSpacing.x3),
            Text(purpose, style: text.bodyMedium),
          ],
          const SizedBox(height: AppSpacing.x3),
          Wrap(
            spacing: AppSpacing.x4,
            runSpacing: AppSpacing.x1,
            children: [
              _Meta(
                label: 'Issued',
                value: DateFormat('MMM d, HH:mm').format(pass.issuedAt.toLocal()),
              ),
              _Meta(
                label: 'Valid until',
                value:
                    DateFormat('MMM d, HH:mm').format(pass.expiresAt.toLocal()),
              ),
              if (pass.returnedAt case final returned?)
                _Meta(
                  label: 'Left',
                  value: DateFormat('MMM d, HH:mm').format(returned.toLocal()),
                ),
              if (pass.issuedByName case final by?)
                _Meta(label: 'Issued by', value: by),
            ],
          ),
          // Inside: the exit tap ends the pass, nothing to press. Not inside
          // and never entered: the guard can cancel it with the card in hand.
          if (pass.returnedAt == null && !pass.isInside) ...[
            const SizedBox(height: AppSpacing.x4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AppRowAction(
                  label: 'Take card back',
                  icon: Icons.assignment_return_outlined,
                  intent: StatusIntent.neutral,
                  onPressed: () => _returnPass(context, ref),
                ),
              ],
            ),
          ],
          if (pass.cardNotYetReturned) ...[
            const SizedBox(height: AppSpacing.x4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    'The visitor tapped out. Mark the card returned once it is '
                    'back in the drawer.',
                    style: text.bodySmall?.copyWith(color: t.text.secondary),
                  ),
                ),
                AppRowAction(
                  label: 'Card returned',
                  icon: Icons.inventory_2_outlined,
                  intent: StatusIntent.neutral,
                  onPressed: () => _confirmReturned(context, ref, pass.passId),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _returnPass(BuildContext context, WidgetRef ref) async {
    final msg = await ref
        .read(visitorPassActionsProvider.notifier)
        .returnPass(pass.passId);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg ?? 'Card returned.')));
    ref.invalidate(visitorPassListProvider);
    ref.invalidate(visitorsOnSiteCountProvider);
    ref.invalidate(visitorCardsProvider);
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: text.labelSmall?.copyWith(
            color: t.text.tertiary,
            letterSpacing: 0.6,
          ),
        ),
        Text(value, style: text.bodySmall),
      ],
    );
  }
}
