import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/network/dio_client.dart';
import '../core/utils/csv_export.dart';
import '../models/payment.dart';
import '../providers/payment_log_provider.dart';
import '../theme/theme.dart';
import '../widgets/ui/ui.dart';

const _statuses = [
  AppFilterOption('Pending', 'Pending'),
  AppFilterOption('Paid', 'Paid'),
];

final _money = NumberFormat.currency(symbol: '₱', decimalDigits: 2);
final _dateTime = DateFormat('MMM d, yyyy HH:mm');
String _fileStamp() => DateFormat('yyyyMMdd-HHmm').format(DateTime.now());

/// Itemized payment history, filterable by date and status, with export.
///
/// Distinct from the live Payments screen — that one is for acting on a bill
/// (mark it paid), this one is for pulling a record of what already happened.
/// Distinct from Reports, too — Reports shows aggregated totals and trends;
/// every row here is one transaction, which is what an export needs to be
/// worth anything as a record.
class PaymentLogScreen extends ConsumerWidget {
  const PaymentLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(paymentLogQueryNotifierProvider);
    final notifier = ref.read(paymentLogQueryNotifierProvider.notifier);

    return AppPage(
      title: 'Payment Log',
      subtitle: 'Itemized payment history for a date range, with export.',
      actions: [
        OutlinedButton.icon(
          icon: const Icon(Icons.download_outlined, size: AppSizes.iconSm),
          label: const Text('Export CSV'),
          onPressed: () => _export(context, ref, query),
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
          onPressed: () => ref.invalidate(paymentLogListProvider),
        ),
      ],
      toolbar: AppToolbar(
        filters: [
          AppFilterDropdown<String>(
            label: 'Status',
            value: query.status,
            options: _statuses,
            allLabel: 'All statuses',
            onChanged: notifier.setStatus,
          ),
          AppDateRangeFilter(
            from: query.from,
            to: query.to,
            onChanged: notifier.setDateRange,
          ),
        ],
      ),
      body: AsyncView(
        value: ref.watch(paymentLogListProvider),
        onRetry: () => ref.invalidate(paymentLogListProvider),
        loading: const SkeletonTable(
          columns: 8,
          columnWidths: [100, 90, 110, 100, 100, 120, 140, 140],
        ),
        isEmpty: (page) => page.payments.isEmpty,
        empty: AppEmptyState(
          icon: Icons.receipt_long_outlined,
          title: 'No matching payments',
          message: 'Nothing was found for the current filters.',
        ),
        data: (page) => AppDataTable(
          minWidth: 1000,
          columns: const [
            DataColumn(label: Text('Source')),
            DataColumn(label: Text('Paid by')),
            DataColumn(label: Text('Amount Due'), numeric: true),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Method')),
            DataColumn(label: Text('Reference')),
            DataColumn(label: Text('Created')),
            DataColumn(label: Text('Paid')),
          ],
          rows: [for (final p in page.payments) _row(p)],
          footer: AppPagination(
            page: page.page,
            pageSize: page.pageSize,
            total: page.totalCount,
            itemLabel: 'payments',
            onPage: notifier.setPage,
          ),
        ),
      ),
    );
  }

  DataRow _row(PaymentTransaction p) {
    return DataRow(cells: [
      DataCell(Text(p.source)),
      DataCell(Text(p.payerName ?? '—')),
      DataCell(AppNumericCell(_money.format(p.amountDue), emphasis: true)),
      DataCell(StatusPill.of(p.status,
          intent: StatusIntents.payment(p.status), dense: true)),
      DataCell(Text(p.method ?? '—')),
      DataCell(Text(p.referenceNumber ?? '—')),
      DataCell(Text(_dateTime.format(p.createdAt.toLocal()))),
      DataCell(Text(p.paidAt == null ? '—' : _dateTime.format(p.paidAt!.toLocal()))),
    ]);
  }

  Future<void> _export(
      BuildContext context, WidgetRef ref, PaymentLogQuery query) async {
    final PaymentExportResult result;
    try {
      result = await fetchPaymentExport(
        ref.read(dioProvider),
        status: query.status,
        from: query.from,
        to: query.to,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
      return;
    }

    CsvExport.save(
      fileName: 'aimpark-payment-log-${_fileStamp()}.csv',
      headers: const [
        'Source',
        'Paid by',
        'Duration (min)',
        'Rate/hr',
        'Amount Due',
        'Status',
        'Method',
        'Reference',
        'Provider',
        'Created',
        'Paid',
      ],
      rows: [
        for (final p in result.payments)
          [
            p.source,
            p.payerName ?? '',
            p.durationMinutes,
            p.ratePerHourApplied,
            p.amountDue,
            p.status,
            p.method ?? '',
            p.referenceNumber ?? '',
            p.provider ?? '',
            _dateTime.format(p.createdAt.toLocal()),
            p.paidAt == null ? '' : _dateTime.format(p.paidAt!.toLocal()),
          ],
      ],
    );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(result.truncated
          ? 'Exported the most recent ${result.payments.length} of '
              '${result.matchingCount} matching payments. Narrow the date '
              'range to export the rest.'
          : 'Exported ${result.payments.length} payments.'),
    ));
  }
}
