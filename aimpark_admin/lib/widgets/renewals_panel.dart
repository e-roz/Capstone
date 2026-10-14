import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../core/utils/responsive.dart';
import '../models/admin_renewal.dart';
import '../providers/renewals_provider.dart';
import '../theme/theme.dart';
import 'document_viewer.dart';
import 'expiry_card.dart';
import 'ui/ui.dart';

String _day(DateTime? d) =>
    d == null ? '—' : DateFormat('MMM d, yyyy').format(d.toLocal());

/// The queue of renewed licences and registrations.
///
/// A renewal is a smaller decision than a registration: one document, one date.
/// So each is a card the reviewer can settle without leaving the list — open the
/// document, compare the date, approve or say why not.
class RenewalsPanel extends ConsumerWidget {
  const RenewalsPanel({super.key, required this.search});

  /// Lower-case. Matches the name, email or plate.
  final String search;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncView(
      value: ref.watch(pendingRenewalsProvider),
      onRetry: () => ref.invalidate(pendingRenewalsProvider),
      loading: const SkeletonTable(
        columns: 4,
        columnWidths: [200, 200, 200, 160],
      ),
      isEmpty: (list) => list.isEmpty,
      empty: const AppEmptyState(
        icon: Icons.event_available_outlined,
        title: 'No renewals waiting',
        message: 'When a user uploads a renewed licence or registration, '
            'it appears here for review.',
      ),
      data: (all) {
        final rows = search.isEmpty
            ? all
            : all
                .where((r) =>
                    r.fullName.toLowerCase().contains(search) ||
                    r.email.toLowerCase().contains(search) ||
                    (r.plateNumber ?? '').toLowerCase().contains(search))
                .toList();

        if (rows.isEmpty) {
          return const AppEmptyState(
            icon: Icons.search_off,
            title: 'No matches',
            message: 'No waiting renewal matches that search.',
          );
        }

        return SingleChildScrollView(
          child: Column(
            children: [
              for (final renewal in rows) ...[
                _RenewalCard(renewal: renewal),
                const SizedBox(height: AppSpacing.gutter),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _RenewalCard extends ConsumerStatefulWidget {
  const _RenewalCard({required this.renewal});

  final AdminRenewal renewal;

  @override
  ConsumerState<_RenewalCard> createState() => _RenewalCardState();
}

class _RenewalCardState extends ConsumerState<_RenewalCard> {
  var _busy = false;

  Future<void> _approve() async {
    setState(() => _busy = true);
    final message =
        await ref.read(renewalActionsProvider).approve(widget.renewal.id);
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _reject() async {
    final reasonCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject renewal'),
        content: SizedBox(
          width: ctx.dialogWidth(420),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Tell ${widget.renewal.fullName} what to fix. They see this "
                  'in the app, and their current expiry stays as it is.',
                ),
                const SizedBox(height: AppSpacing.x3),
                TextFormField(
                  controller: reasonCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Reason',
                    hintText: 'The photo is blurry, retake it flat and in good light.',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'A reason is required'
                      : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: ctx.tokens.status.danger.solid),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, reasonCtrl.text.trim());
              }
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (reason == null || !mounted) return;

    setState(() => _busy = true);
    final message =
        await ref.read(renewalActionsProvider).reject(widget.renewal.id, reason);
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.renewal;
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    final oldStatus = ExpiryStatus.of(r.currentExpiry);
    final newStatus = ExpiryStatus.of(r.newExpiry);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                r.isLicense ? Icons.badge_outlined : Icons.description_outlined,
                color: t.text.secondary,
              ),
              const SizedBox(width: AppSpacing.x2),
              Expanded(
                child: Wrap(
                  spacing: AppSpacing.x3,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    InkWell(
                      onTap: () => context.go('/users/${r.userId}'),
                      child: Text(r.fullName, style: text.titleMedium),
                    ),
                    Text(r.email,
                        style: text.bodySmall?.copyWith(color: t.text.secondary)),
                  ],
                ),
              ),
              StatusPill(
                label: r.label,
                intent: StatusIntent.accent,
                showDot: false,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x4),
          Wrap(
            spacing: AppSpacing.x8,
            runSpacing: AppSpacing.x3,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _Date(
                caption: 'On file now',
                date: r.currentExpiry,
                pill: StatusPill(
                  label: oldStatus.label,
                  intent: oldStatus.intent,
                  icon: oldStatus.icon,
                  dense: true,
                ),
              ),
              Icon(Icons.arrow_forward, color: t.text.secondary),
              _Date(
                caption: 'Renewed to',
                date: r.newExpiry,
                emphasis: true,
                pill: StatusPill(
                  label: newStatus.label,
                  intent: newStatus.intent,
                  icon: newStatus.icon,
                  dense: true,
                ),
              ),
            ],
          ),
          if (r.dateWasEdited) ...[
            const SizedBox(height: AppSpacing.x3),
            Row(
              children: [
                Icon(Icons.edit_outlined,
                    size: AppSizes.iconSm, color: t.status.warning.fg),
                const SizedBox(width: AppSpacing.x2),
                Expanded(
                  child: Text(
                    'The phone read ${_day(r.extractedExpiry)}; the user '
                    'changed it. Check the date on the document.',
                    style: text.bodySmall?.copyWith(color: t.status.warning.fg),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.x4),
          Row(
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.visibility_outlined, size: AppSizes.iconSm),
                label: const Text('View document'),
                onPressed: r.fileUrl.isEmpty
                    ? null
                    : () => viewDocument(
                          context,
                          title: r.label,
                          fileName: r.fileName,
                          url: r.fileUrl,
                        ),
              ),
              const Spacer(),
              OutlinedButton.icon(
                icon: const Icon(Icons.close, size: AppSizes.iconSm),
                label: const Text('Reject'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: t.status.danger.fg,
                  side: BorderSide(color: t.status.danger.border),
                ),
                onPressed: _busy ? null : _reject,
              ),
              const SizedBox(width: AppSpacing.x2),
              FilledButton.icon(
                icon: const Icon(Icons.check, size: AppSizes.iconSm),
                label: Text(_busy ? 'Working…' : 'Approve'),
                onPressed: _busy ? null : _approve,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Date extends StatelessWidget {
  const _Date({
    required this.caption,
    required this.date,
    required this.pill,
    this.emphasis = false,
  });

  final String caption;
  final DateTime? date;
  final Widget pill;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(caption, style: text.labelSmall?.copyWith(color: t.text.tertiary)),
        const SizedBox(height: 2),
        Text(_day(date), style: emphasis ? text.titleLarge : text.titleMedium),
        const SizedBox(height: AppSpacing.x1),
        pill,
      ],
    );
  }
}
