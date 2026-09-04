import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/utils/responsive.dart';
import '../models/security.dart';
import '../providers/security_provider.dart';
import '../theme/theme.dart';
import '../widgets/ui/ui.dart';

const _passStatuses = ['Active', 'Returned', 'Expired'];

/// The drawer of spare RFID cards, and who is holding them.
///
/// Defaults to the Active filter rather than to everything, because the
/// question a guard actually has is "which of my cards are out?" — the history
/// matters at the end of the day, and the missing card matters now.
class VisitorPassesScreen extends ConsumerWidget {
  const VisitorPassesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(visitorPassQueryNotifierProvider);
    final notifier = ref.read(visitorPassQueryNotifierProvider.notifier);

    return AppPage(
      title: 'Visitor Passes',
      subtitle: 'Lend a spare RFID card to a guest, and take it back when they '
          'leave.',
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
                onPressed: () => ref.invalidate(visitorPassListProvider),
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
                    ? 'Every spare card is in the drawer. Issue one when a guest arrives.'
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
    final contactCtrl = TextEditingController();
    var vehicleType = 'Car';
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Issue a Visitor Card'),
          content: SizedBox(
            width: context.dialogWidth(440),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AppRequiredNote(),
                    TextFormField(
                      controller: cardCtrl,
                      autofocus: true,
                      decoration: const InputDecoration(
                        label: AppFieldLabel('Card number', isRequired: true),
                        helperText: 'Scan the spare card, or type its number.',
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'The card number is required'
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.x3),
                    TextFormField(
                      controller: nameCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        label: AppFieldLabel('Visitor name', isRequired: true),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'The name is required'
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.x3),
                    TextFormField(
                      controller: plateCtrl,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        label: AppFieldLabel('Plate number', isRequired: true),
                        helperText:
                            'What is on the car. This is what the gate check '
                            'will compare against.',
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'The plate is required'
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.x3),
                    DropdownButtonFormField<String>(
                      initialValue: vehicleType,
                      decoration: const InputDecoration(
                        label: AppFieldLabel('Vehicle type', isRequired: true),
                        helperText: 'Decides which bays they can be given.',
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Car', child: Text('Car')),
                        DropdownMenuItem(
                            value: 'Motorcycle', child: Text('Motorcycle')),
                      ],
                      onChanged: (v) => setState(() => vehicleType = v!),
                    ),
                    const SizedBox(height: AppSpacing.x3),
                    TextFormField(
                      controller: purposeCtrl,
                      decoration: const InputDecoration(
                        label: AppFieldLabel('Purpose of visit'),
                        helperText: 'Who or what they are here for.',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.x3),
                    TextFormField(
                      controller: contactCtrl,
                      decoration: const InputDecoration(
                        label: AppFieldLabel('Contact number'),
                      ),
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
          contactNumber: contactCtrl.text.trim(),
        );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg ?? 'Card issued.')));
    ref.invalidate(visitorPassListProvider);
    ref.invalidate(visitorsOnSiteCountProvider);
  }
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
                      'Card ${pass.rfidTagId} · ${pass.plateNumber} · ${pass.vehicleType}',
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
                  label: 'Returned',
                  value: DateFormat('MMM d, HH:mm').format(returned.toLocal()),
                ),
              if (pass.issuedByName case final by?)
                _Meta(label: 'Issued by', value: by),
              if (pass.contactNumber case final contact?)
                _Meta(label: 'Contact', value: contact),
            ],
          ),
          if (pass.returnedAt == null) ...[
            const SizedBox(height: AppSpacing.x4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (pass.isInside)
                  Expanded(
                    child: Text(
                      'Their vehicle is still inside. Log the exit at the gate '
                      'first, then take the card back.',
                      style:
                          text.bodySmall?.copyWith(color: t.text.secondary),
                    ),
                  ),
                AppRowAction(
                  label: 'Take card back',
                  icon: Icons.assignment_return_outlined,
                  intent: StatusIntent.neutral,
                  // The server refuses this too. Disabled here as well so the
                  // guard is not invited to press something that cannot work.
                  onPressed: pass.isInside ? null : () => _returnPass(context, ref),
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
