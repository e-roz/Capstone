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
  AppFilterOption('Paid', 'Paid'),
  AppFilterOption('Waived', 'Waived'),
];

final _money = NumberFormat.currency(symbol: '₱', decimalDigits: 2);
final _dateTime = DateFormat('MMM d, yyyy HH:mm');

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
            DataColumn(label: Text('Created')),
            DataColumn(label: Text('')),
          ],
          rows: [for (final p in page.payments) _row(context, p)],
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

  DataRow _row(BuildContext context, PaymentTransaction p) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    return DataRow(cells: [
      DataCell(Text(p.source, style: text.titleSmall)),
      DataCell(Text(p.slotCode ?? '—')),
      DataCell(AppNumericCell('${p.durationMinutes} min')),
      DataCell(AppNumericCell(_money.format(p.ratePerHourApplied))),
      DataCell(AppNumericCell(_money.format(p.amountDue), emphasis: true)),
      DataCell(StatusPill.of(p.status,
          intent: StatusIntents.payment(p.status), dense: true)),
      DataCell(Text(
        _dateTime.format(p.createdAt.toLocal()),
        style: text.bodySmall?.copyWith(color: t.text.secondary),
      )),
      DataCell(AppRowAction(
        icon: Icons.receipt_long,
        label: 'Receipt',
        onPressed: () => _showReceipt(context, p),
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
                _ReceiptRow(label: 'Entry', value: time(p.entryTime)),
                _ReceiptRow(label: 'Exit', value: time(p.exitTime)),
                _ReceiptRow(
                    label: 'Duration', value: '${p.durationMinutes} min'),
                _ReceiptRow(
                  label: 'Rate applied',
                  value: '${_money.format(p.ratePerHourApplied)}/hr',
                ),
                const Divider(height: AppSpacing.x6),
                _ReceiptRow(label: 'Created', value: time(p.createdAt)),
                _ReceiptRow(label: 'Paid', value: time(p.paidAt)),
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
                      trailing: Text(
                        '${_money.format(r.ratePerHour)}/hr',
                        style: AppTypography.tabular(
                            Theme.of(ctx).textTheme.titleSmall!),
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
    final msg = await ref
        .read(paymentActionsProvider.notifier)
        .upsertRate(vehicleType, rate);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg ?? 'Rate saved.')));
    ref.invalidate(parkingRatesProvider);
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
