import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/utils/responsive.dart';
import '../models/security.dart';
import '../models/visitor_card.dart';
import '../providers/auth_provider.dart';
import '../providers/security_provider.dart';
import '../providers/visitor_cards_provider.dart';
import '../router/destinations.dart';
import '../theme/theme.dart';
import '../widgets/rfid_scan_field.dart';
import '../widgets/ui/ui.dart';
import '../widgets/visitor_details_fields.dart';

const _passStatuses = ['Active', 'Returned'];

final _stamp = DateFormat('MMM d, HH:mm');

/// The visitor cards and the visitors who have used them, on one page.
///
/// A card is registered once (admin), lent to one visitor for one visit, and
/// free again the moment that visitor taps out. Cards are normally lent at the
/// gate: tapping a free card pops the visitor form wherever the guard is (see
/// `VisitorRegistrationWatcher`). "Lend a card" here is the desk fallback for
/// when a gate reader is down.
///
/// The history defaults to the Active filter, because the question a guard
/// actually has is "who is still out with a card?".
class VisitorPassesScreen extends ConsumerWidget {
  const VisitorPassesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(visitorPassQueryNotifierProvider);
    final notifier = ref.read(visitorPassQueryNotifierProvider.notifier);
    final isAdmin = ref.watch(staffRoleProvider) != StaffRole.security;

    return AppPage(
      title: 'Visitors',
      subtitle: 'Tap a free card at the entry gate to lend it. The '
          "visitor's exit tap frees it again.",
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
          onPressed: () {
            ref.invalidate(visitorPassListProvider);
            ref.invalidate(visitorCardsProvider);
          },
        ),
        if (isAdmin) ...[
          const SizedBox(width: AppSpacing.x2),
          OutlinedButton.icon(
            onPressed: () => _showAddDialog(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('Add card'),
          ),
        ],
        const SizedBox(width: AppSpacing.x2),
        FilledButton.icon(
          onPressed: () => _showLendDialog(context, ref),
          icon: const Icon(Icons.badge_outlined),
          label: const Text('Lend a card'),
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardsSection(isAdmin: isAdmin),
          AppToolbar(
            filters: [
              AppFilterDropdown<String>(
                label: 'History',
                value: query.status,
                options: [for (final s in _passStatuses) AppFilterOption(s, s)],
                allLabel: 'All visitors',
                onChanged: notifier.setStatus,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.headingGap),
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
                    : 'No visitors yet',
                message: query.status == 'Active'
                    ? 'Every card is free. Tap one at the entry gate when a guest arrives.'
                    : 'Clear the filter to see every visitor.',
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
                    itemLabel: 'visitors',
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

  Future<void> _showAddDialog(BuildContext context, WidgetRef ref) async {
    final cardCtrl = TextEditingController();
    final labelCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add a visitor card'),
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
                    label: AppFieldLabel('Name', isRequired: true),
                    helperText: 'What is written on the card, so guards can '
                        'tell them apart (e.g. VISITOR 1).',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'A name is required'
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

    await _say(
      context,
      ref.read(visitorCardActionsProvider.notifier).add(
            rfidTagId: cardCtrl.text.trim(),
            label: labelCtrl.text.trim(),
          ),
    );
  }

  Future<void> _showLendDialog(BuildContext context, WidgetRef ref) async {
    final cardCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final plateCtrl = TextEditingController();
    final purposeCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Lend a visitor card'),
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
                    "don't need this: tap the card at the entry gate and "
                    'the form pops up there.',
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.x3),
                  VisitorDetailsFields(
                    name: nameCtrl,
                    plate: plateCtrl,
                    purpose: purposeCtrl,
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
            child: const Text('Lend card'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final msg = await ref.read(visitorPassActionsProvider.notifier).issue(
          rfidTagId: cardCtrl.text.trim(),
          visitorName: nameCtrl.text.trim(),
          plateNumber: plateCtrl.text.trim(),
          purpose: purposeCtrl.text.trim(),
        );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg ?? 'Card lent.')));
    ref.invalidate(visitorPassListProvider);
    ref.invalidate(visitorsOnSiteCountProvider);
    ref.invalidate(visitorCardsProvider);
  }
}

Future<void> _say(BuildContext context, Future<String?> action) async {
  final msg = await action;
  if (!context.mounted || msg == null) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}

/// Every visitor card at a glance: free, or out with a visitor.
class _CardsSection extends ConsumerWidget {
  const _CardsSection({required this.isAdmin});

  final bool isAdmin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = ref.watch(visitorCardsProvider(admin: isAdmin)).valueOrNull;
    if (cards == null) return const SizedBox.shrink();

    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    if (cards.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.headingGap),
        child: Text(
          isAdmin
              ? 'No visitor cards yet. Use Add card to register the cards '
                  'the guards lend out.'
              : 'No visitor cards yet. An admin adds them here.',
          style: text.bodySmall?.copyWith(color: t.text.secondary),
        ),
      );
    }

    final out = cards.where((c) => c.whereabouts == 'OutWithVisitor').length;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.headingGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cards · ${cards.length - out} available, $out out',
            style: text.labelMedium?.copyWith(color: t.text.tertiary),
          ),
          const SizedBox(height: AppSpacing.x2),
          Wrap(
            spacing: AppSpacing.x2,
            runSpacing: AppSpacing.x2,
            children: [
              for (final card in cards)
                _CardTile(card: card, isAdmin: isAdmin),
            ],
          ),
        ],
      ),
    );
  }
}

class _CardTile extends ConsumerWidget {
  const _CardTile({required this.card, required this.isAdmin});

  final VisitorCard card;
  final bool isAdmin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final t = context.tokens;
    final isOut = card.whereabouts == 'OutWithVisitor';

    return SizedBox(
      width: 230,
      child: AppCard(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.x3, vertical: AppSpacing.x2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(card.label, style: text.titleSmall)),
                StatusPill.of(
                  visitorCardWhereaboutsLabel(card.whereabouts),
                  intent: isOut ? StatusIntent.info : StatusIntent.success,
                  dense: true,
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(card.rfidTagId,
                style: text.bodySmall?.copyWith(color: t.text.tertiary)),
            const SizedBox(height: AppSpacing.x1),
            Row(
              children: [
                Expanded(
                  child: Text(
                    isOut
                        ? '${card.lastVisitorName ?? ''} · ${card.lastPlateNumber ?? ''}'
                        : card.lastVisitorName == null
                            ? 'Never lent'
                            : 'Last: ${card.lastVisitorName}',
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall?.copyWith(color: t.text.secondary),
                  ),
                ),
                if (isAdmin && !isOut)
                  AppRowAction(
                    label: 'Remove',
                    icon: Icons.delete_outline,
                    intent: StatusIntent.danger,
                    onPressed: () => _confirmRemove(context, ref),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmRemove(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${card.label}?'),
        content: const Text(
          'It stops being a visitor card, so you can give it to a new user. '
          "The visitors who used it stay in the history, shown by the card's "
          'ID instead of its name.',
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
            child: const Text('Remove card'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    await _say(
      context,
      ref.read(visitorCardActionsProvider.notifier).remove(card.rfidTagId),
    );
    ref.invalidate(visitorPassListProvider);
  }
}

class _PassCard extends ConsumerWidget {
  const _PassCard({required this.pass});

  final VisitorPass pass;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    final intent =
        pass.status == 'Active' ? StatusIntent.success : StatusIntent.neutral;

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
                      '${pass.cardLabel == null ? 'Card ${pass.rfidTagId}' : 'Card ${pass.cardLabel}'} · ${pass.plateNumber}',
                      style: text.bodySmall?.copyWith(color: t.text.secondary),
                    ),
                  ],
                ),
              ),
              if (pass.isInside)
                StatusPill.of(
                  'Inside',
                  intent: StatusIntent.info,
                  dense: true,
                  showDot: false,
                  icon: Icons.directions_car_outlined,
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
                label: 'In',
                value: _stamp.format(pass.issuedAt.toLocal()),
              ),
              if (pass.returnedAt case final returned?)
                _Meta(label: 'Out', value: _stamp.format(returned.toLocal())),
              if (pass.issuedByName case final by?)
                _Meta(label: 'Lent by', value: by),
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
