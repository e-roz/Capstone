import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/payment.dart';
import '../providers/payments_provider.dart';
import '../core/utils/responsive.dart';
import '../widgets/page_header.dart';

const _statuses = ['Pending', 'Paid', 'Waived'];

class PaymentsScreen extends ConsumerWidget {
  const PaymentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(paymentsQueryNotifierProvider);
    final async = ref.watch(paymentListProvider);
    final ratesAsync = ref.watch(parkingRatesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              title: 'Payments',
              actions: [
                DropdownButton<String?>(
                  value: query.status,
                  hint: const Text('All Status'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All Status')),
                    ..._statuses.map(
                        (s) => DropdownMenuItem(value: s, child: Text(s))),
                  ],
                  onChanged: (v) =>
                      ref.read(paymentsQueryNotifierProvider.notifier).setStatus(v),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.tune, size: 16),
                  label: const Text('Manage Rates'),
                  onPressed: () => _showRates(context, ref, ratesAsync.valueOrNull ?? []),
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
            const SizedBox(height: 16),
            Expanded(
              child: async.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Failed to load payments: $e')),
                data: (page) => Column(
                  children: [
                    Expanded(child: _PaymentTable(page: page)),
                    const SizedBox(height: 12),
                    _Pagination(page: page),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showRates(
      BuildContext context, WidgetRef ref, List<ParkingRate> rates) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Parking Rates'),
        content: SizedBox(
          width: context.dialogWidth(420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (rates.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('No rates configured yet.'),
                )
              else
                ...rates.map((r) => ListTile(
                      dense: true,
                      title: Text(r.vehicleType ?? 'Default rate'),
                      subtitle: Text(
                          'Updated ${DateFormat('MMM d, yyyy').format(r.updatedAt.toLocal())}'),
                      trailing: Text('₱${r.ratePerHour.toStringAsFixed(2)}/hr'),
                    )),
              const Divider(),
              FilledButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add / Update Rate'),
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _showUpsertRate(context, ref);
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
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
                    labelText: 'Vehicle Type (blank = default)',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: rateCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Rate per Hour', border: OutlineInputBorder()),
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

class _PaymentTable extends StatelessWidget {
  const _PaymentTable({required this.page});

  final PaymentListPage page;

  @override
  Widget build(BuildContext context) {
    if (page.payments.isEmpty) {
      return const Center(child: Text('No payments found.'));
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.hardEdge,
      child: SingleChildScrollView(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
            columns: const [
              DataColumn(label: Text('Source')),
              DataColumn(label: Text('Slot')),
              DataColumn(label: Text('Duration')),
              DataColumn(label: Text('Rate/hr')),
              DataColumn(label: Text('Amount Due')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Created')),
              DataColumn(label: Text('')),
            ],
            rows: page.payments.map((p) => _row(context, p)).toList(),
          ),
        ),
      ),
    );
  }

  DataRow _row(BuildContext context, PaymentTransaction p) => DataRow(cells: [
        DataCell(Text(p.source)),
        DataCell(Text(p.slotCode ?? '—')),
        DataCell(Text('${p.durationMinutes} min')),
        DataCell(Text('₱${p.ratePerHourApplied.toStringAsFixed(2)}')),
        DataCell(Text('₱${p.amountDue.toStringAsFixed(2)}')),
        DataCell(_StatusChip(status: p.status)),
        DataCell(Text(DateFormat('MMM d, yyyy HH:mm').format(p.createdAt.toLocal()))),
        DataCell(OutlinedButton.icon(
          icon: const Icon(Icons.receipt_long, size: 14),
          label: const Text('Receipt', style: TextStyle(fontSize: 12)),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onPressed: () => _showReceipt(context, p),
        )),
      ]);

  /// Every field is already present in the list response, so the receipt needs
  /// no extra fetch — it renders what is loaded.
  Future<void> _showReceipt(BuildContext context, PaymentTransaction p) {
    String time(DateTime? t) =>
        t == null ? '—' : DateFormat('MMM d, yyyy HH:mm').format(t.toLocal());

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
                      '₱${p.amountDue.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                    _StatusChip(status: p.status),
                  ],
                ),
                const Divider(height: 24),
                _ReceiptRow(label: 'Source', value: p.source),
                _ReceiptRow(label: 'Slot', value: p.slotCode ?? '—'),
                _ReceiptRow(label: 'Entry', value: time(p.entryTime)),
                _ReceiptRow(label: 'Exit', value: time(p.exitTime)),
                _ReceiptRow(label: 'Duration', value: '${p.durationMinutes} min'),
                _ReceiptRow(
                    label: 'Rate applied',
                    value: '₱${p.ratePerHourApplied.toStringAsFixed(2)}/hr'),
                const Divider(height: 24),
                _ReceiptRow(label: 'Created', value: time(p.createdAt)),
                _ReceiptRow(label: 'Paid', value: time(p.paidAt)),
                const SizedBox(height: 12),
                SelectableText(
                  'Ref ${p.paymentId}',
                  style: const TextStyle(fontSize: 11, color: Colors.black45),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.black54)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case 'Paid':
        color = Colors.green;
        break;
      case 'Waived':
        color = Colors.blueGrey;
        break;
      default:
        color = Colors.orange;
    }
    return Chip(
      label: Text(status, style: const TextStyle(fontSize: 12, color: Colors.white)),
      backgroundColor: color,
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

class _Pagination extends ConsumerWidget {
  const _Pagination({required this.page});

  final PaymentListPage page;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalPages = (page.totalCount / page.pageSize).ceil().clamp(1, 999999);
    final currentPage = page.page;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
            'Showing ${page.payments.length} of ${page.totalCount} payments • Page $currentPage of $totalPages'),
        const SizedBox(width: 16),
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: currentPage > 1
              ? () => ref
                  .read(paymentsQueryNotifierProvider.notifier)
                  .setPage(currentPage - 1)
              : null,
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: currentPage < totalPages
              ? () => ref
                  .read(paymentsQueryNotifierProvider.notifier)
                  .setPage(currentPage + 1)
              : null,
        ),
      ],
    );
  }
}
