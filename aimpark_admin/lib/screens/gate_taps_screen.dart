import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/utils/csv_export.dart';
import '../models/gate_tap_event.dart';
import '../providers/auth_provider.dart';
import '../providers/gate_taps_provider.dart';
import '../router/destinations.dart';
import '../theme/theme.dart';
import '../widgets/live_gate_log.dart';
import '../widgets/live_refresh.dart';
import '../widgets/ui/ui.dart';

final _day = DateFormat('MMM d, yyyy');
final _clock = DateFormat('HH:mm:ss');
final _isoStamp = DateFormat('yyyy-MM-dd HH:mm:ss');

const _results = [
  AppFilterOption('entered', 'Entered'),
  AppFilterOption('exited', 'Exited'),
  AppFilterOption('denied', 'Denied'),
  AppFilterOption('manual', 'Opened by guard'),
];

const _gates = [AppFilterOption(1, 'Gate 1'), AppFilterOption(2, 'Gate 2')];

const _plateChecks = [
  AppFilterOption('match', 'Match'),
  AppFilterOption('mismatch', 'Mismatch'),
];

/// Every card tap at a gate reader, newest first: let in, let out, turned away,
/// and opened by a guard.
///
/// Parking Logs lists only real entries and exits, so a card that was turned
/// away never appears there. This is where the refusals are.
///
/// Colour carries the result: green in, blue out, red for a refusal that needs a
/// look (a card nobody holds, a plate that is not the holder's), amber for a
/// routine one (no camera reading, a full lot, a double tap), grey for a guard.
/// Only the red ones get the bar down the left edge, so they stand out in a long
/// list.
///
/// For Security it is live, the same way Parking Logs is: today refreshes
/// itself and a new tap is lit for a moment; an earlier day does not.
class GateTapsScreen extends ConsumerStatefulWidget {
  const GateTapsScreen({super.key});

  @override
  ConsumerState<GateTapsScreen> createState() => _GateTapsScreenState();
}

class _GateTapsScreenState extends ConsumerState<GateTapsScreen>
    with FreshRows {
  @override
  Widget build(BuildContext context) {
    final query = ref.watch(gateTapsQueryNotifierProvider);
    final notifier = ref.read(gateTapsQueryNotifierProvider.notifier);
    final async = ref.watch(gateTapsProvider);
    final isSecurity = ref.watch(staffRoleProvider) == StaffRole.security;

    final live =
        isSecurity &&
        query.from != null &&
        DateUtils.isSameDay(query.from, DateTime.now());

    ref.listen(gateTapsQueryNotifierProvider, (_, _) => forgetRows());
    ref.listen(gateTapsProvider, (_, next) {
      final page = next.valueOrNull;
      if (page != null && live) trackRows({for (final t in page.taps) t.id});
    });

    final liveState = !live
        ? LiveState.paused
        : async.hasError
        ? LiveState.reconnecting
        : LiveState.live;

    return LiveRefresh(
      enabled: live,
      onTick: () => ref.invalidate(gateTapsProvider),
      child: AppPage(
        badge: isSecurity ? LiveBadge(state: liveState) : null,
        title: 'Gate Taps',
        subtitle:
            'Every card tapped at a gate, including the ones turned away.',
        actions: [
          OutlinedButton.icon(
            icon: const Icon(Icons.download_outlined, size: AppSizes.iconSm),
            label: const Text('Export CSV'),
            onPressed: async.hasValue
                ? () => _export(context, async.requireValue.taps)
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(gateTapsProvider),
          ),
        ],
        toolbar: AppToolbar(
          search: AppSearchField(
            hint: 'Search name, card or plate',
            initialValue: query.search,
            onChanged: notifier.setSearch,
          ),
          filters: [
            AppFilterDropdown<String>(
              label: 'Result',
              value: query.result,
              options: _results,
              allLabel: 'All results',
              onChanged: notifier.setResult,
            ),
            AppFilterDropdown<int>(
              label: 'Gate',
              value: query.gate,
              options: _gates,
              allLabel: 'All gates',
              onChanged: notifier.setGate,
            ),
            AppFilterDropdown<String>(
              label: 'Plate',
              value: query.plate,
              options: _plateChecks,
              allLabel: 'All',
              onChanged: notifier.setPlate,
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
          onRetry: () => ref.invalidate(gateTapsProvider),
          loading: const SkeletonTable(
            columns: 6,
            columnWidths: [120, 70, 140, 180, 200, 240],
          ),
          isEmpty: (page) => page.taps.isEmpty,
          empty: const AppEmptyState(
            icon: Icons.contactless_outlined,
            title: 'No taps found',
            message:
                'Nothing matches the current filters. Every card tap at a gate '
                '— let in, turned away, or opened by a guard — is listed here.',
          ),
          data: (page) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Summary(summary: page.summary),
              const SizedBox(height: AppSpacing.headingGap),
              Expanded(
                child: AppDataTable(
                  minWidth: 1100,
                  columns: const [
                    DataColumn(label: Text('Time')),
                    DataColumn(label: Text('Gate')),
                    DataColumn(label: Text('Result')),
                    DataColumn(label: Text('Who')),
                    DataColumn(label: Text('Plate check')),
                    DataColumn(label: Text('Why')),
                  ],
                  rows: [
                    for (final t in page.taps)
                      _row(context, t, fresh: freshIds.contains(t.id)),
                  ],
                  footer: AppPagination(
                    page: page.page,
                    pageSize: page.pageSize,
                    total: page.totalCount,
                    itemLabel: 'gate taps',
                    onPage: notifier.setPage,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  DataRow _row(BuildContext context, GateTapEvent tap, {bool fresh = false}) {
    final text = Theme.of(context).textTheme;
    final t = context.tokens;
    void open() => showDialog<void>(
      context: context,
      builder: (_) => TapDetailDialog(tap: tap),
    );

    final local = tap.at.toLocal();

    return DataRow(
      color: fresh
          ? WidgetStatePropertyAll(t.status.of(StatusIntent.accent).bg)
          : null,
      cells: [
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // The bar is only for refusals that need a look, so it is the
              // first thing the eye finds in a long list.
              Container(
                width: 3,
                height: 34,
                margin: const EdgeInsets.only(right: AppSpacing.x2),
                color: tap.serious
                    ? t.status.of(StatusIntent.danger).fg
                    : Colors.transparent,
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _clock.format(local),
                    style: AppTypography.tabular(text.bodyMedium!),
                  ),
                  Text(
                    _day.format(local),
                    style: text.bodySmall?.copyWith(color: t.text.tertiary),
                  ),
                ],
              ),
            ],
          ),
          onTap: open,
        ),
        DataCell(Text('Gate ${tap.gate}'), onTap: open),
        DataCell(_resultPill(tap), onTap: open),
        DataCell(
          AppPrimaryCell(
            title: tap.who,
            subtitle: tap.isManual
                ? null
                : tap.rfidTagId == null
                ? null
                : 'Card ${tap.rfidTagId}',
          ),
          onTap: open,
        ),
        DataCell(_plateCheck(context, tap), onTap: open),
        DataCell(
          SizedBox(
            width: 280,
            child: Text(
              tap.message,
              style: text.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          onTap: open,
        ),
      ],
    );
  }

  Widget _resultPill(GateTapEvent tap) {
    if (tap.isManual) {
      return StatusPill(
        label: tap.outcomeLabel,
        intent: StatusIntent.neutral,
        icon: Icons.key_outlined,
        showDot: false,
        dense: true,
      );
    }
    if (!tap.opened) {
      return StatusPill(
        label: tap.outcomeLabel,
        intent: tap.serious ? StatusIntent.danger : StatusIntent.warning,
        icon: Icons.block,
        showDot: false,
        dense: true,
      );
    }
    final out = tap.direction == 'OUT';
    return StatusPill(
      label: tap.outcomeLabel,
      intent: out ? StatusIntent.accent : StatusIntent.success,
      icon: out ? Icons.logout : Icons.login,
      showDot: false,
      dense: true,
    );
  }

  /// A plain Match or Mismatch, so nobody has to compare two plates by eye.
  /// Both plates show only when they differ; otherwise just the one that matters.
  Widget _plateCheck(BuildContext context, GateTapEvent tap) {
    final text = Theme.of(context).textTheme;
    final t = context.tokens;

    if (tap.isManual) {
      return Text(
        '—',
        style: text.bodyMedium?.copyWith(color: t.text.tertiary),
      );
    }

    final Widget pill;
    String? sub;

    if (tap.plateMatches == true) {
      pill = const StatusPill(
        label: 'Match',
        intent: StatusIntent.success,
        icon: Icons.check_circle_outline,
        showDot: false,
        dense: true,
      );
      sub = tap.cameraPlate;
    } else if (tap.plateMatches == false) {
      pill = const StatusPill(
        label: 'Mismatch',
        intent: StatusIntent.danger,
        icon: Icons.warning_amber_rounded,
        showDot: false,
        dense: true,
      );
      sub = 'Saw ${tap.cameraPlate} · on file ${tap.registeredPlates}';
    } else if (tap.isUnknownCard) {
      pill = const StatusPill.of(
        'Card not registered',
        intent: StatusIntent.neutral,
        showDot: false,
        dense: true,
      );
      sub = tap.cameraPlate == null ? null : 'Saw ${tap.cameraPlate}';
    } else if (tap.cameraPlate == null) {
      pill = const StatusPill.of(
        'No camera reading',
        intent: StatusIntent.neutral,
        showDot: false,
        dense: true,
      );
      sub = tap.registeredPlates == null
          ? null
          : 'On file ${tap.registeredPlates}';
    } else {
      pill = const StatusPill.of(
        'No plate on file',
        intent: StatusIntent.neutral,
        showDot: false,
        dense: true,
      );
      sub = 'Saw ${tap.cameraPlate}';
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        pill,
        if (sub != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              sub,
              style: text.bodySmall?.copyWith(color: t.text.secondary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }

  /// Covers the page on screen, which is the only set of rows the person
  /// exporting has actually reviewed.
  void _export(BuildContext context, List<GateTapEvent> taps) {
    CsvExport.save(
      fileName:
          'aimpark-gate-taps-${DateFormat('yyyyMMdd-HHmm').format(DateTime.now())}.csv',
      headers: const [
        'Time',
        'Gate',
        'What happened',
        'Who',
        'Card UID',
        'Camera saw',
        'Plate on file',
        'Plates match',
        'Why',
      ],
      rows: [
        for (final t in taps)
          [
            _isoStamp.format(t.at.toLocal()),
            '${t.gate}',
            t.outcomeLabel,
            t.who,
            t.rfidTagId ?? '',
            t.cameraPlate ?? '',
            t.registeredPlates ?? '',
            switch (t.plateMatches) {
              true => 'Yes',
              false => 'No',
              null => '',
            },
            t.message,
          ],
      ],
    );
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Log exported.')));
  }
}

/// The breakdown above the table. It follows the date, gate and search filters
/// but not the Result and Plate ones, so it stays a menu to pick a result from.
class _Summary extends StatelessWidget {
  const _Summary({required this.summary});

  final GateTapSummary summary;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.controlGap,
      runSpacing: AppSpacing.controlGap,
      children: [
        MetricCard(
          label: 'Entered',
          value: '${summary.entered}',
          icon: Icons.login,
          intent: StatusIntent.success,
        ),
        MetricCard(
          label: 'Exited',
          value: '${summary.exited}',
          icon: Icons.logout,
          intent: StatusIntent.accent,
        ),
        MetricCard(
          label: 'Denied, needs a look',
          value: '${summary.deniedSerious}',
          icon: Icons.warning_amber_rounded,
          intent: StatusIntent.danger,
        ),
        MetricCard(
          label: 'Denied, routine',
          value: '${summary.deniedRoutine}',
          icon: Icons.block,
          intent: StatusIntent.warning,
        ),
        MetricCard(
          label: 'Opened by guard',
          value: '${summary.manual}',
          icon: Icons.key_outlined,
          intent: StatusIntent.neutral,
        ),
      ],
    );
  }
}
