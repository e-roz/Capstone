import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/utils/responsive.dart';
import '../models/payment.dart';
import '../providers/payments_provider.dart';
import '../theme/theme.dart';
import '../widgets/ui/ui.dart';

const _statuses = [
  AppFilterOption('Pending', 'Pending'),
  // A payer who is at the provider's page right now. Filterable because it is
  // the one state that can get stuck: a checkout nobody finished sits here, and
  // an admin looking for money that never arrived starts by looking at these.
  AppFilterOption('Processing', 'Processing'),
  AppFilterOption('Paid', 'Paid'),
  AppFilterOption('Waived', 'Waived'),
];

final _money = NumberFormat.currency(symbol: '₱', decimalDigits: 2);
final _dateTime = DateFormat('MMM d, yyyy HH:mm');

/// Entry and exit only. Duration is billed from the real elapsed time, so a
/// receipt reading 9:34 to 9:36 and then "2 min" looks wrong to anyone who
/// assumes those are whole minutes. The seconds are what make the sum add up.
final _dateTimeExact = DateFormat('MMM d, yyyy HH:mm:ss');

class PaymentsScreen extends ConsumerWidget {
  const PaymentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(paymentsQueryNotifierProvider);
    final ratesAsync = ref.watch(parkingRatesProvider);

    return AppPage(
      title: 'Payments',
      subtitle: 'Parking charges raised at exit, and how they were settled.',
      // Manage Rates and Refresh sit on the toolbar rather than beside the
      // title, so they line up with the Status filter instead of floating a row
      // above it — the two rows of controls read as one strip.
      toolbar: AppToolbar(
        filters: [
          AppFilterDropdown<String>(
            label: 'Status',
            value: query.status,
            options: _statuses,
            allLabel: 'All statuses',
            onChanged:
                ref.read(paymentsQueryNotifierProvider.notifier).setStatus,
          ),
        ],
        trailing: [
          OutlinedButton.icon(
            icon: const Icon(Icons.tune, size: AppSizes.iconSm),
            label: const Text('Manage Rates'),
            onPressed: () =>
                _showRates(context, ref, ratesAsync.valueOrNull ?? []),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              ref.invalidate(paymentListProvider);
              ref.invalidate(parkingRatesProvider);
            },
          ),
        ],
      ),
      body: AsyncView(
        value: ref.watch(paymentListProvider),
        onRetry: () => ref.invalidate(paymentListProvider),
        isEmpty: (page) => page.payments.isEmpty,
        empty: AppEmptyState(
          icon: Icons.receipt_long_outlined,
          title: query.status == null
              ? 'No payments yet'
              : 'No ${query.status!.toLowerCase()} payments',
          message: query.status == null
              ? 'Charges appear here once a vehicle exits the lot.'
              : 'Clear the filter to see every payment.',
        ),
        data: (page) => AppDataTable(
          minWidth: 1000,
          columns: const [
            DataColumn(label: Text('Source')),
            DataColumn(label: Text('Slot')),
            DataColumn(label: Text('Duration'), numeric: true),
            DataColumn(label: Text('Rate/hr'), numeric: true),
            DataColumn(label: Text('Amount Due'), numeric: true),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Settled by')),
            DataColumn(label: Text('Created')),
            DataColumn(label: Text('')),
          ],
          rows: [for (final p in page.payments) _row(context, ref, p)],
          footer: AppPagination(
            page: page.page,
            pageSize: page.pageSize,
            total: page.totalCount,
            itemLabel: 'payments',
            onPage: ref.read(paymentsQueryNotifierProvider.notifier).setPage,
          ),
        ),
      ),
    );
  }

  DataRow _row(BuildContext context, WidgetRef ref, PaymentTransaction p) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    return DataRow(cells: [
      DataCell(Text(p.source, style: text.titleSmall)),
      DataCell(Text(p.slotCode ?? '—')),
      DataCell(AppNumericCell('${p.durationMinutes} min')),
      DataCell(AppNumericCell(_money.format(p.ratePerHourApplied))),
      DataCell(AppNumericCell(_money.format(p.amountDue), emphasis: true)),
      DataCell(_StatusCell(payment: p)),
      // Cash and GCash both read as "Paid" in the status column, and they are
      // not the same fact: one is in the school's merchant account with a
      // provider's record behind it, the other is in somebody's drawer.
      DataCell(Text(
        // "Cash — J. Santos" answers the only question this column is here
        // to answer: not whether it was settled, but by whom.
        p.confirmedBy == null ? (p.method ?? '—') : '${p.method} · ${p.confirmedBy}',
        style: text.bodySmall?.copyWith(color: t.text.secondary),
      )),
      DataCell(Text(
        _dateTime.format(p.createdAt.toLocal()),
        style: text.bodySmall?.copyWith(color: t.text.secondary),
      )),
      DataCell(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (p.paidAt == null && p.status != 'Waived')
            AppRowAction(
              icon: Icons.payments_outlined,
              label: 'Mark paid',
              onPressed: () => _markPaid(context, ref, p),
            ),
          AppRowAction(
            icon: Icons.receipt_long,
            label: 'Receipt',
            onPressed: () => _showReceipt(context, p),
          ),
        ],
      )),
    ]);
  }

  /// Every field is already present in the list response, so the receipt needs
  /// no extra fetch — it renders what is loaded.
  Future<void> _showReceipt(BuildContext context, PaymentTransaction p) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    String time(DateTime? at) =>
        at == null ? '—' : _dateTime.format(at.toLocal());

    String exact(DateTime? at) =>
        at == null ? '—' : _dateTimeExact.format(at.toLocal());

    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Payment Receipt'),
        content: SizedBox(
          width: context.dialogWidth(420),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _money.format(p.amountDue),
                      style: AppTypography.tabular(text.displaySmall!),
                    ),
                    StatusPill.of(p.status,
                        intent: StatusIntents.payment(p.status)),
                  ],
                ),
                const Divider(height: AppSpacing.x6),
                _ReceiptRow(label: 'Source', value: p.source),
                _ReceiptRow(label: 'Slot', value: p.slotCode ?? '—'),
                _ReceiptRow(label: 'Entry', value: exact(p.entryTime)),
                _ReceiptRow(label: 'Exit', value: exact(p.exitTime)),
                _ReceiptRow(
                    label: 'Duration', value: '${p.durationMinutes} min'),
                _ReceiptRow(
                  label: 'Rate applied',
                  value: '${_money.format(p.ratePerHourApplied)}/hr',
                ),
                const Divider(height: AppSpacing.x6),
                _ReceiptRow(label: 'Created', value: time(p.createdAt)),
                _ReceiptRow(label: 'Paid', value: time(p.paidAt)),
                if (p.method != null)
                  _ReceiptRow(label: 'Method', value: p.method!),
                if (p.provider != null)
                  _ReceiptRow(label: 'Provider', value: p.provider!),
                if (p.referenceNumber != null)
                  _ReceiptRow(label: 'Reference', value: p.referenceNumber!),
                if (p.confirmedBy != null)
                  _ReceiptRow(label: 'Received by', value: p.confirmedBy!),
                const SizedBox(height: AppSpacing.x3),
                SelectableText(
                  'Ref ${p.paymentId}',
                  style: text.labelSmall?.copyWith(color: t.text.tertiary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Records money handed over in person.
  ///
  /// The counterpart of a provider callback, and the reason the transaction
  /// carries who confirmed it: online money arrives with a record attached, and
  /// cash arrives in somebody's hand. Whoever presses this is the answer to
  /// "who took it", so the confirmation says as much before it is pressed.
  Future<void> _markPaid(
      BuildContext context, WidgetRef ref, PaymentTransaction p) async {
    final referenceCtrl = TextEditingController();
    var method = 'Cash';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Mark as paid'),
          content: SizedBox(
            width: context.dialogWidth(420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Record ${_money.format(p.amountDue)} as received. Your name '
                  'is saved against this payment as the one who took it.',
                ),
                const SizedBox(height: AppSpacing.x4),
                DropdownButtonFormField<String>(
                  initialValue: method,
                  decoration: const InputDecoration(labelText: 'Method'),
                  items: const [
                    DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                    DropdownMenuItem(value: 'GCash', child: Text('GCash')),
                    DropdownMenuItem(value: 'Maya', child: Text('Maya')),
                    DropdownMenuItem(value: 'Card', child: Text('Card')),
                  ],
                  onChanged: (v) => setLocal(() => method = v ?? 'Cash'),
                ),
                const SizedBox(height: AppSpacing.x3),
                TextField(
                  controller: referenceCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Reference or OR number (optional)',
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
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Mark paid'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final reference = referenceCtrl.text.trim();
    final msg = await ref.read(paymentActionsProvider.notifier).markPaid(
          p.paymentId,
          method: method,
          referenceNumber: reference.isEmpty ? null : reference,
        );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg ?? 'Payment recorded.')));
    ref.invalidate(paymentListProvider);
  }

  Future<void> _showRates(
      BuildContext context, WidgetRef ref, List<ParkingRate> rates) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        // The close affordance sits with the title rather than in the action
        // row, where it competed with "Add / Update Rate" for the eye.
        title: Row(
          children: [
            const Expanded(child: Text('Parking Rates')),
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Close',
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
        content: SizedBox(
          width: context.dialogWidth(420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (rates.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.x3),
                  child: Text('No rates configured yet.'),
                )
              else
                ...rates.map((r) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(r.vehicleType ?? 'Default rate'),
                      subtitle: Text(
                          'Updated ${DateFormat('MMM d, yyyy').format(r.updatedAt.toLocal())}'),
                      trailing: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${_money.format(r.ratePerHour)}/hr',
                            style: AppTypography.tabular(
                                Theme.of(ctx).textTheme.titleSmall!),
                          ),
                          Text(
                            '${_money.format(r.minimumFee)} minimum',
                            style: Theme.of(ctx)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: ctx.tokens.text.secondary),
                          ),
                        ],
                      ),
                    )),
              const Divider(height: AppSpacing.x6),
              FilledButton.icon(
                icon: const Icon(Icons.add, size: AppSizes.iconSm),
                label: const Text('Add / Update Rate'),
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _showUpsertRate(context, ref);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showUpsertRate(BuildContext context, WidgetRef ref) async {
    final vehicleTypeCtrl = TextEditingController();
    final rateCtrl = TextEditingController();
    final minimumCtrl = TextEditingController(text: '20');
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add / Update Rate'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: vehicleTypeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Vehicle type',
                  helperText: 'Leave blank to set the default rate',
                ),
              ),
              const SizedBox(height: AppSpacing.x4),
              TextFormField(
                controller: rateCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    label: AppFieldLabel('Rate per hour', isRequired: true)),
                validator: (v) => double.tryParse(v ?? '') == null
                    ? 'Enter a valid number'
                    : null,
              ),
              const SizedBox(height: AppSpacing.x4),
              TextFormField(
                controller: minimumCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  label: AppFieldLabel('Minimum fee', isRequired: true),
                  helperText:
                      'Charged for any session shorter than this is worth. '
                      'Card and e-wallet payments under ₱20 are refused by the '
                      'provider, so keep it at ₱20 or above.',
                ),
                validator: (v) => double.tryParse(v ?? '') == null
                    ? 'Enter a valid number'
                    : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    final vehicleType =
        vehicleTypeCtrl.text.trim().isEmpty ? null : vehicleTypeCtrl.text.trim();
    final rate = double.parse(rateCtrl.text.trim());
    final minimum = double.parse(minimumCtrl.text.trim());
    final msg = await ref
        .read(paymentActionsProvider.notifier)
        .upsertRate(vehicleType, rate, minimumFee: minimum);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg ?? 'Rate saved.')));
    ref.invalidate(parkingRatesProvider);
  }
}

/// "47m", or "2h 15m" past the first hour — matches how duration reads
/// elsewhere on this screen (`'${p.durationMinutes} min'`), just scaled up
/// since a stuck checkout can sit for days.
String _formatAge(Duration age) {
  final hours = age.inHours;
  final minutes = age.inMinutes % 60;
  if (hours == 0) return '${age.inMinutes}m';
  if (hours < 24) return '${hours}h ${minutes}m';
  final days = age.inDays;
  return '${days}d ${hours % 24}h';
}

/// The status pill, plus how long a Processing checkout has been open.
///
/// A checkout opened two minutes ago and one abandoned three days ago both
/// read as "Processing" — this is the difference the pill alone can't show.
class _StatusCell extends StatelessWidget {
  const _StatusCell({required this.payment});

  final PaymentTransaction payment;

  /// Past this, a checkout with no callback almost certainly means the payer
  /// left the tab rather than that they're still filling in a form.
  static const _stuckAfter = Duration(minutes: 15);

  @override
  Widget build(BuildContext context) {
    final started = payment.checkoutStartedAt;
    final age = payment.status == 'Processing' && started != null
        ? DateTime.now().difference(started.toLocal())
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        StatusPill.of(payment.status,
            intent: StatusIntents.payment(payment.status), dense: true),
        if (age != null) ...[
          const SizedBox(height: 2),
          Text(
            'Open for ${_formatAge(age)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: age >= _stuckAfter
                      ? context.tokens.status.of(StatusIntent.danger).fg
                      : context.tokens.text.secondary,
                  fontWeight: age >= _stuckAfter ? FontWeight.w700 : null,
                ),
          ),
        ],
      ],
    );
  }
}

/// Label left, value right — the shape a receipt wants, where [AppField]'s
/// stacked label-over-value would double the dialog's height.
class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: text.bodyMedium?.copyWith(color: t.text.secondary)),
          Text(value, style: text.titleSmall),
        ],
      ),
    );
  }
}
