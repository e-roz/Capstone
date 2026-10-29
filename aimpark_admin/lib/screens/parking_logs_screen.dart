import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/utils/csv_export.dart';
import '../models/parking_log.dart';
import '../providers/auth_provider.dart';
import '../providers/parking_logs_provider.dart';
import '../router/destinations.dart';
import '../theme/theme.dart';
import '../widgets/live_refresh.dart';
import '../widgets/parking/bay_confirm.dart';
import '../widgets/ui/ui.dart';

final _stamp = DateFormat('MMM d, yyyy HH:mm');
final _isoStamp = DateFormat('yyyy-MM-dd HH:mm');

String _fileStamp() => DateFormat('yyyyMMdd-HHmm').format(DateTime.now());

const _gates = [AppFilterOption(1, 'Gate 1'), AppFilterOption(2, 'Gate 2')];

const _vehicleTypes = [
  AppFilterOption('Car', 'Car'),
  AppFilterOption('Motorcycle', 'Motorcycle'),
];

const _visitorKinds = [
  AppFilterOption(false, 'Members'),
  AppFilterOption(true, 'Visitors'),
];

/// Every vehicle that came in or out, with who, what and when.
///
/// Shows the gate, and the bay only once the driver has confirmed it: the bay
/// given at entry is only the one the system suggested, and the driver may have
/// parked in another. A confirmed bay opens its history, where an admin can
/// correct it. The guard post never hears of confirms, so there the column is
/// left out rather than calling everyone unconfirmed.
///
/// For Security it is live: today's list refreshes itself every few seconds, and
/// a new row is lit for a moment. Picking an earlier day stops that, since a day
/// that is over cannot change.
class ParkingLogsScreen extends ConsumerStatefulWidget {
  const ParkingLogsScreen({super.key});

  @override
  ConsumerState<ParkingLogsScreen> createState() => _ParkingLogsScreenState();
}

class _ParkingLogsScreenState extends ConsumerState<ParkingLogsScreen>
    with FreshRows {
  @override
  Widget build(BuildContext context) {
    final query = ref.watch(parkingLogsQueryNotifierProvider);
    final notifier = ref.read(parkingLogsQueryNotifierProvider.notifier);
    final async = ref.watch(parkingLogsProvider);
    final isSecurity = ref.watch(staffRoleProvider) == StaffRole.security;

    // Live only on today. After midnight the picked day is no longer today, so
    // the page says "Not live" rather than quietly showing a finished day as
    // though it were current.
    final live =
        isSecurity &&
        query.from != null &&
        DateUtils.isSameDay(query.from, DateTime.now());

    // A different list is not new rows; only what arrives on a refresh is.
    ref.listen(parkingLogsQueryNotifierProvider, (_, _) => forgetRows());
    ref.listen(parkingLogsProvider, (_, next) {
      final page = next.valueOrNull;
      if (page != null && live) trackRows({for (final l in page.logs) l.id});
    });

    final liveState = !live
        ? LiveState.paused
        : async.hasError
        ? LiveState.reconnecting
        : LiveState.live;

    return LiveRefresh(
      enabled: live,
      onTick: () => ref.invalidate(parkingLogsProvider),
      child: AppPage(
        badge: isSecurity ? LiveBadge(state: liveState) : null,
        title: 'Parking Logs',
        subtitle: 'Every vehicle that came in or out, with who, what and when.',
        actions: [
          OutlinedButton.icon(
            icon: const Icon(Icons.download_outlined, size: AppSizes.iconSm),
            label: const Text('Export CSV'),
            onPressed: async.hasValue
                ? () => _export(
                    context,
                    async.requireValue.logs,
                    withConfirmed: async.requireValue.confirmationsTracked,
                  )
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(parkingLogsProvider),
          ),
        ],
        toolbar: AppToolbar(
          search: AppSearchField(
            hint: 'Search name or plate number',
            initialValue: query.search,
            onChanged: notifier.setSearch,
          ),
          filters: [
            AppFilterDropdown<int>(
              label: 'Gate',
              value: query.gate,
              options: _gates,
              allLabel: 'All gates',
              onChanged: notifier.setGate,
            ),
            AppFilterDropdown<String>(
              label: 'Vehicle',
              value: query.vehicleType,
              options: _vehicleTypes,
              allLabel: 'All vehicles',
              onChanged: notifier.setVehicleType,
            ),
            AppFilterDropdown<bool>(
              label: 'Type',
              value: query.visitor,
              options: _visitorKinds,
              allLabel: 'All',
              onChanged: notifier.setVisitor,
            ),
            if (isSecurity)
              AppDayFilter(
                day: query.from ?? DateTime.now(),
                onChanged: notifier.setDay,
              )
            else
              AppDateRangeFilter(
                from: query.from,
                to: query.to,
                onChanged: notifier.setDateRange,
              ),
          ],
        ),
        body: AsyncView(
          keepStaleData: true,
          value: async,
          onRetry: () => ref.invalidate(parkingLogsProvider),
          loading: const SkeletonTable(
            columns: 8,
            columnWidths: [160, 100, 110, 80, 120, 150, 150, 90],
          ),
          isEmpty: (page) => page.logs.isEmpty,
          empty: const AppEmptyState(
            icon: Icons.local_parking_outlined,
            title: 'No parking records',
            message:
                'Nothing was found for the current filters. Every entry and exit '
                'is recorded here with its timestamps.',
          ),
          data: (page) => AppDataTable(
            minWidth: page.confirmationsTracked ? 1120 : 1000,
            columns: [
              const DataColumn(label: Text('User')),
              const DataColumn(label: Text('Vehicle')),
              const DataColumn(label: Text('Plate')),
              const DataColumn(label: Text('Gate')),
              if (page.confirmationsTracked)
                const DataColumn(label: Text('Confirmed')),
              const DataColumn(label: Text('Entry')),
              const DataColumn(label: Text('Exit')),
              const DataColumn(label: Text('Duration')),
            ],
            rows: [
              for (final entry in page.logs)
                _row(
                  context,
                  entry,
                  fresh: freshIds.contains(entry.id),
                  showConfirmed: page.confirmationsTracked,
                  canCorrect: !isSecurity,
                ),
            ],
            footer: AppPagination(
              page: page.page,
              pageSize: page.pageSize,
              total: page.totalCount,
              itemLabel: 'entries',
              onPage: notifier.setPage,
            ),
          ),
        ),
      ),
    );
  }

  DataRow _row(
    BuildContext context,
    ParkingLogEntry entry, {
    bool fresh = false,
    bool showConfirmed = true,
    bool canCorrect = false,
  }) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    Widget dim(String value) =>
        Text(value, style: text.bodyMedium?.copyWith(color: t.text.tertiary));

    return DataRow(
      color: fresh
          ? WidgetStatePropertyAll(t.status.of(StatusIntent.accent).bg)
          : null,
      cells: [
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: AppPrimaryCell(
                  title: entry.userName,
                  subtitle: entry.isVisitor
                      ? (entry.visitorPurpose?.isNotEmpty == true
                            ? entry.visitorPurpose!
                            : 'Visitor card')
                      : (entry.rfidTagId == null
                            ? 'No tag on file'
                            : 'Tag ${entry.rfidTagId}'),
                ),
              ),
              if (entry.isVisitor) ...[
                const SizedBox(width: AppSpacing.x2),
                const StatusPill.of(
                  'Visitor',
                  intent: StatusIntent.warning,
                  dense: true,
                  showDot: false,
                ),
              ],
            ],
          ),
        ),
        DataCell(
          entry.vehicleType == null
              ? dim('—')
              : Text(entry.vehicleType!, style: text.bodyMedium),
        ),
        DataCell(
          entry.plateNumber == null
              ? dim('—')
              : Text(
                  entry.plateNumber!,
                  style: AppTypography.tabular(text.bodyMedium!),
                ),
        ),
        DataCell(
          entry.gate == null
              ? dim('—')
              : Text('Gate ${entry.gate}', style: text.bodyMedium),
        ),
        if (showConfirmed)
          DataCell(
            BayConfirmCell(
              entry: entry,
              onOpen: entry.confirmState.isConfirmed
                  ? () => _openBayConfirm(context, entry, canCorrect)
                  : null,
            ),
          ),
        DataCell(
          Text(_stamp.format(entry.entryTime.toLocal()), style: text.bodySmall),
        ),
        DataCell(
          entry.exitTime == null
              ? const StatusPill.of(
                  'Still inside',
                  intent: StatusIntent.accent,
                  dense: true,
                )
              : Text(
                  _stamp.format(entry.exitTime!.toLocal()),
                  style: text.bodySmall,
                ),
        ),
        DataCell(
          Text(
            _durationLabel(entry.duration),
            style: entry.duration == null
                ? text.bodyMedium?.copyWith(color: t.text.tertiary)
                : AppTypography.tabular(text.bodyMedium!),
          ),
        ),
      ],
    );
  }

  Future<void> _openBayConfirm(
    BuildContext context,
    ParkingLogEntry entry,
    bool canCorrect,
  ) async {
    final corrected =
        await showBayConfirmDialog(context, entry, canCorrect: canCorrect);
    if (!corrected || !context.mounted) return;
    ref.invalidate(parkingLogsProvider);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Bay corrected.')));
  }

  static String _confirmedLabel(ParkingLogEntry l) => switch (l.confirmState) {
    BayConfirmState.confirmed =>
      l.bayCorrected ? 'Corrected by admin' : 'Confirmed',
    BayConfirmState.confirmedLate =>
      l.bayCorrected ? 'Corrected by admin' : 'Confirmed late',
    BayConfirmState.unconfirmed => 'Unconfirmed',
    BayConfirmState.notYet => 'Not yet',
    BayConfirmState.notCounted => '',
  };

  static String _durationLabel(Duration? d) {
    if (d == null) return '—';
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    return hours == 0 ? '${minutes}m' : '${hours}h ${minutes}m';
  }

  /// Covers the page on screen, which is the only set of rows the person
  /// exporting has actually reviewed.
  void _export(
    BuildContext context,
    List<ParkingLogEntry> logs, {
    bool withConfirmed = true,
  }) {
    CsvExport.save(
      fileName: 'aimpark-parking-logs-${_fileStamp()}.csv',
      headers: [
        'User',
        'Visitor',
        'RFID tag',
        'Vehicle',
        'Plate',
        'Gate',
        if (withConfirmed) ...['Confirmed bay', 'Confirm status', 'Confirmed at'],
        'Entry',
        'Exit',
        'Duration',
      ],
      rows: [
        for (final l in logs)
          [
            l.userName,
            l.isVisitor ? 'Yes' : 'No',
            l.rfidTagId ?? '',
            l.vehicleType ?? '',
            l.plateNumber ?? '',
            l.gate?.toString() ?? '',
            if (withConfirmed) ...[
              l.confirmedSlotCode ?? '',
              _confirmedLabel(l),
              l.slotConfirmedAt == null
                  ? ''
                  : _isoStamp.format(l.slotConfirmedAt!.toLocal()),
            ],
            _isoStamp.format(l.entryTime.toLocal()),
            l.exitTime == null ? '' : _isoStamp.format(l.exitTime!.toLocal()),
            _durationLabel(l.duration),
          ],
      ],
    );
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Log exported.')));
  }
}
