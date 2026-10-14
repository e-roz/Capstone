import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../core/utils/csv_export.dart';
import '../core/utils/ph_time.dart';
import '../models/report.dart';
import '../models/violation.dart';
import '../providers/overview_provider.dart';
import '../providers/report_page_provider.dart';
import '../theme/theme.dart';
import '../widgets/period_picker.dart';
import '../widgets/ui/ui.dart';

final _money = NumberFormat.currency(symbol: '₱', decimalDigits: 0);
final _moneyExact = NumberFormat.currency(symbol: '₱', decimalDigits: 2);
final _peakAt = DateFormat('EEE, MMM d · h:mm a');

/// The place to study the numbers, where the Overview is the place to notice
/// them.
///
/// Everything on the page follows one period, read as Philippine days, and the
/// headline figures say how they moved against the stretch just before. Money
/// is fees and fines kept apart, never added to what is merely owed. What is
/// true right now (cars inside, what is unpaid) is labelled as live and does
/// not follow the period.
class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(reportPeriodProvider);

    final summary = ref.watch(reportSummaryProvider);
    final entryExit = ref.watch(reportEntryExitProvider);
    final hours = ref.watch(reportHoursProvider);
    final revenue = ref.watch(reportRevenueProvider);
    final gate = ref.watch(reportGateOutcomesProvider);
    final peak = ref.watch(reportPeakOccupancyProvider);
    final violations = ref.watch(reportViolationsProvider);

    final ready = summary.hasValue &&
        entryExit.hasValue &&
        hours.hasValue &&
        revenue.hasValue &&
        gate.hasValue &&
        peak.hasValue &&
        violations.hasValue;

    void refresh() {
      ref.invalidate(reportSummaryProvider);
      ref.invalidate(reportEntryExitProvider);
      ref.invalidate(reportHoursProvider);
      ref.invalidate(reportRevenueProvider);
      ref.invalidate(reportGateOutcomesProvider);
      ref.invalidate(reportPeakOccupancyProvider);
      ref.invalidate(reportViolationsProvider);
    }

    return AppPage(
      title: 'Reports',
      eyebrow: 'INSIGHTS',
      subtitle: 'Usage, revenue and enforcement for the period you pick.',
      scrollable: true,
      actions: [
        // Offered only once every series has landed: a CSV built from four
        // loaded sections and one still spinning would be quietly incomplete.
        OutlinedButton.icon(
          icon: const Icon(Icons.download_outlined, size: AppSizes.iconSm),
          label: const Text('Export CSV'),
          onPressed: !ready
              ? null
              : () => _export(
                    context,
                    period: period,
                    summary: summary.requireValue,
                    entryExit: entryExit.requireValue,
                    hours: hours.requireValue,
                    revenue: revenue.requireValue,
                    gate: gate.requireValue,
                    peak: peak.requireValue,
                    violations: violations.requireValue,
                  ),
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
          onPressed: refresh,
        ),
        const SizedBox(width: AppSpacing.x2),
        PeriodPicker(provider: reportPeriodProvider),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Tiles(
            summary: summary,
            gate: gate,
            peak: peak,
            onRetry: refresh,
          ),
          const SizedBox(height: AppSpacing.gutter),
          _EntriesAndExits(period: period, entryExit: entryExit, summary: summary),
          const SizedBox(height: AppSpacing.gutter),
          _Pair(
            left: _PeakHours(period: period, hours: hours),
            right: _Revenue(period: period, revenue: revenue, summary: summary),
          ),
          const SizedBox(height: AppSpacing.gutter),
          _GateOutcomesCard(period: period, gate: gate),
          const SizedBox(height: AppSpacing.gutter),
          _Pair(
            left: _ViolationsByStatus(period: period, violations: violations),
            right: _MostViolatedRules(period: period, violations: violations),
          ),
        ],
      ),
    );
  }

  /// Exports what the page shows for the chosen period, as labelled blocks
  /// rather than one wide table: the series have different shapes (a day, an
  /// hour, a rule) and forcing them into shared columns gives a sheet nobody
  /// can read.
  void _export(
    BuildContext context, {
    required OverviewPeriod period,
    required ReportsSummary summary,
    required EntryExitReport entryExit,
    required List<PeakHourPoint> hours,
    required ReportSeries<RevenuePoint> revenue,
    required GateOutcomes gate,
    required PeakOccupancy peak,
    required ViolationBreakdown violations,
  }) {
    final now = DateTime.now();
    final isoDay = DateFormat('yyyy-MM-dd');
    final days = period.days;
    final prev = summary.previous;

    final rows = <List<Object?>>[
      ['Generated', DateFormat('yyyy-MM-dd HH:mm').format(now)],
      ['Period', period.label],
      [
        'From',
        days == null ? 'First record' : isoDay.format(days.from),
        'To',
        days == null ? 'Today' : isoDay.format(days.to),
      ],
      [],
      ['Summary'],
      ['Parking sessions', summary.sessionsInPeriod],
      if (prev != null) ['Parking sessions, previous period', prev.sessionsInPeriod],
      ['Fees collected', summary.feesCollected.toStringAsFixed(2)],
      ['Fines collected', summary.finesCollected.toStringAsFixed(2)],
      ['Total collected', summary.revenueCollected.toStringAsFixed(2)],
      if (prev != null)
        ['Total collected, previous period', prev.revenueCollected.toStringAsFixed(2)],
      ['Peak occupancy', '${peak.peak} of ${peak.capacity} bays'],
      ['Peak occupancy reached', peak.at == null ? '' : _peakAt.format(manila(peak.at!))],
      ['Violations issued', summary.violationsIssued],
      [],
      ['Right now (not affected by the period)'],
      ['Cars inside', '${summary.occupiedSlots} of ${summary.usableSlots} bays'],
      ['Unpaid fees', summary.feesPending.toStringAsFixed(2)],
      ['Unpaid fines', summary.finesPending.toStringAsFixed(2)],
      [],
      ['Gate outcomes'],
      ['Entered', gate.entered],
      ['Exited', gate.exited],
      ['Plate mismatch', gate.plateMismatch],
      ['Unknown card', gate.unknownCard],
      ['Routine refusals', gate.routineRefusals],
      [],
      ['Entries and exits (${entryExit.granularity})'],
      ['Date', 'In', 'Out'],
      for (final p in entryExit.points)
        [isoDay.format(p.date), p.entries, p.exits],
      [],
      ['Peak hours (Philippine time)'],
      ['Hour', 'Entries'],
      for (final p in hours) [_hour(p.hour), p.count],
      [],
      ['Revenue (${revenue.granularity})'],
      ['Date', 'Fees', 'Fines'],
      for (final p in revenue.points)
        [
          isoDay.format(p.date),
          p.fees.toStringAsFixed(2),
          p.fines.toStringAsFixed(2),
        ],
      [],
      ['Violations issued in the period, by current status'],
      ['Status', 'Count'],
      for (final s in violations.byStatus)
        [ViolationStatuses.label(s.status), s.count],
      [],
      ['Most violated rules'],
      ['Rule', 'Count'],
      for (final r in violations.byRule) [r.ruleTitle, r.count],
    ];

    CsvExport.save(
      fileName: 'aimpark-report-${DateFormat('yyyyMMdd-HHmm').format(now)}.csv',
      headers: const ['AimPark — Reports'],
      rows: rows,
    );

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Report exported.')));
  }
}

String _hour(int h) {
  final suffix = h < 12 ? 'am' : 'pm';
  final display = h % 12 == 0 ? 12 : h % 12;
  return '$display$suffix';
}

String _hourShort(int h) => h == 0
    ? '12a'
    : h < 12
        ? '${h}a'
        : h == 12
            ? '12p'
            : '${h - 12}p';

/// How a point's date reads on an axis, given how the period was cut.
String _axisLabel(DateTime d, String granularity) =>
    granularity == 'month' ? DateFormat('MMM yy').format(d) : DateFormat('M/d').format(d);

String _caption(OverviewPeriod period, String? granularity) => switch (granularity) {
      'week' => '${period.label} · weekly',
      'month' => '${period.label} · monthly',
      _ => period.label,
    };

// ── Summary tiles ────────────────────────────────────────────────────────────

/// "+12%" / "-8%" against the period before, or null when there is nothing to
/// compare with (all time, or the earlier stretch was empty).
({String text, bool up})? _delta(num now, num before) {
  if (before <= 0) return null;
  final pct = ((now - before) / before * 100).round();
  if (pct == 0) return (text: '0%', up: true);
  return (text: '${pct > 0 ? '+' : ''}$pct%', up: pct > 0);
}

class _Tiles extends StatelessWidget {
  const _Tiles({
    required this.summary,
    required this.gate,
    required this.peak,
    required this.onRetry,
  });

  final AsyncValue<ReportsSummary> summary;
  final AsyncValue<GateOutcomes> gate;
  final AsyncValue<PeakOccupancy> peak;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final s = summary.valueOrNull;
    final g = gate.valueOrNull;
    final p = peak.valueOrNull;

    if (summary.hasError || gate.hasError || peak.hasError) {
      return AsyncView<void>(
        value: AsyncError<void>(
          summary.error ?? gate.error ?? peak.error!,
          StackTrace.empty,
        ),
        onRetry: onRetry,
        data: (_) => const SizedBox.shrink(),
      );
    }
    if (s == null || g == null || p == null) {
      return const SkeletonMetricRow(count: 4, width: 200);
    }

    final t = context.tokens;
    final sessionsDelta = s.previous == null
        ? null
        : _delta(s.sessionsInPeriod, s.previous!.sessionsInPeriod);
    final moneyDelta = s.previous == null
        ? null
        : _delta(s.revenueCollected, s.previous!.revenueCollected);
    final fill = p.capacity <= 0 ? 0 : (p.peak / p.capacity * 100).round();

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = (constraints.maxWidth / 230).floor().clamp(1, 4);
        final width =
            (constraints.maxWidth - AppSpacing.gutter * (columns - 1)) / columns;

        return Wrap(
          spacing: AppSpacing.gutter,
          runSpacing: AppSpacing.gutter,
          children: [
            MetricCard(
              width: width,
              label: 'Parking sessions',
              value: '${s.sessionsInPeriod}',
              icon: Icons.directions_car_outlined,
              intent: StatusIntent.info,
              dotColor: t.chart.series(0),
              delta: sessionsDelta?.text,
              deltaPositive: sessionsDelta?.up ?? true,
              caption: s.previous == null
                  ? null
                  : 'vs ${s.previous!.sessionsInPeriod} in the period before',
            ),
            MetricCard(
              width: width,
              label: 'Collected',
              value: _money.format(s.revenueCollected),
              icon: Icons.payments_outlined,
              intent: StatusIntent.success,
              delta: moneyDelta?.text,
              deltaPositive: moneyDelta?.up ?? true,
              caption:
                  'Fees ${_money.format(s.feesCollected)} · Fines ${_money.format(s.finesCollected)}',
            ),
            MetricCard(
              width: width,
              label: 'Peak occupancy',
              value: '${p.peak} / ${p.capacity}',
              icon: Icons.local_parking_outlined,
              intent: fill >= 90
                  ? StatusIntent.danger
                  : fill >= 70
                      ? StatusIntent.warning
                      : StatusIntent.accent,
              caption: p.at == null
                  ? 'No cars parked in this period'
                  : '${_peakAt.format(manila(p.at!))} · $fill%',
            ),
            MetricCard(
              width: width,
              label: 'Serious denials',
              value: '${g.serious}',
              icon: Icons.block,
              intent: g.serious > 0 ? StatusIntent.danger : StatusIntent.success,
              caption: '${g.plateMismatch} plate mismatch · ${g.unknownCard} unknown card',
              onTap: () => context.go('/gate-taps'),
            ),
          ],
        );
      },
    );
  }
}

// ── Entries and exits ────────────────────────────────────────────────────────

class _EntriesAndExits extends StatelessWidget {
  const _EntriesAndExits({
    required this.period,
    required this.entryExit,
    required this.summary,
  });

  final OverviewPeriod period;
  final AsyncValue<EntryExitReport> entryExit;
  final AsyncValue<ReportsSummary> summary;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return _Panel(
      title: 'Entries and exits',
      caption: _caption(period, entryExit.valueOrNull?.granularity),
      child: AsyncView(
        value: entryExit,
        onRetry: null,
        loading: const SkeletonBlock(height: 280),
        data: (report) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _Key(color: t.chart.series(0), label: 'In ${report.totalEntries}'),
                const SizedBox(width: AppSpacing.x4),
                _Key(color: t.chart.series(1), label: 'Out ${report.totalExits}'),
                if (report.totalVisitorEntries > 0) ...[
                  const SizedBox(width: AppSpacing.x4),
                  _Key(
                    color: t.chart.series(4),
                    label: '${report.totalVisitorEntries} visitor entries',
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.x3),
            AppSeriesBarChart(
              height: 220,
              labels: [for (final p in report.points) _axisLabel(p.date, report.granularity)],
              series: [
                AppSeries(
                  label: 'In',
                  color: t.chart.series(0),
                  values: [for (final p in report.points) p.entries.toDouble()],
                ),
                AppSeries(
                  label: 'Out',
                  color: t.chart.series(1),
                  values: [for (final p in report.points) p.exits.toDouble()],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.x3),
            Divider(height: 1, color: t.border.subtle),
            const SizedBox(height: AppSpacing.x3),
            _InsideNow(summary: summary),
          ],
        ),
      ),
    );
  }
}

/// Cars inside right now against capacity, from the open sessions. Live: it
/// ignores the period, and a missed exit can inflate it.
class _InsideNow extends StatelessWidget {
  const _InsideNow({required this.summary});

  final AsyncValue<ReportsSummary> summary;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final s = summary.valueOrNull;
    if (s == null) return const SizedBox.shrink();

    final ratio = s.occupancyRatio;
    final color = ratio >= 0.9
        ? t.status.danger.solid
        : ratio >= 0.7
            ? t.status.warning.solid
            : t.brand.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('Inside now', style: text.bodySmall?.copyWith(color: t.text.secondary)),
            const SizedBox(width: AppSpacing.x3),
            Expanded(
              child: ClipRRect(
                borderRadius: AppRadii.smAll,
                child: LinearProgressIndicator(
                  value: ratio.clamp(0, 1).toDouble(),
                  minHeight: 8,
                  backgroundColor: t.surface.muted,
                  color: color,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.x3),
            Text(
              '${s.occupiedSlots} / ${s.usableSlots} bays',
              style: AppTypography.tabular(text.titleSmall!),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.x1),
        Text(
          'Counted from open sessions, so a missed exit can inflate it. Live: it ignores the period.',
          style: text.labelSmall?.copyWith(color: t.text.tertiary),
        ),
      ],
    );
  }
}

// ── Peak hours and revenue ───────────────────────────────────────────────────

class _PeakHours extends StatelessWidget {
  const _PeakHours({required this.period, required this.hours});

  final OverviewPeriod period;
  final AsyncValue<List<PeakHourPoint>> hours;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return _Panel(
      title: 'Peak hours',
      caption: '${period.label} · Philippine time',
      child: AsyncView(
        value: hours,
        loading: const SkeletonBlock(height: 240),
        data: (points) {
          final byHour = {for (final p in points) p.hour: p.count};
          return AppSeriesBarChart(
            height: 240,
            labels: [for (var h = 0; h < 24; h++) _hourShort(h)],
            series: [
              AppSeries(
                label: 'Entries',
                color: t.chart.series(2),
                values: [for (var h = 0; h < 24; h++) (byHour[h] ?? 0).toDouble()],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Revenue extends StatelessWidget {
  const _Revenue({
    required this.period,
    required this.revenue,
    required this.summary,
  });

  final OverviewPeriod period;
  final AsyncValue<ReportSeries<RevenuePoint>> revenue;
  final AsyncValue<ReportsSummary> summary;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final s = summary.valueOrNull;

    return _Panel(
      title: 'Revenue collected',
      caption: _caption(period, revenue.valueOrNull?.granularity),
      child: AsyncView(
        value: revenue,
        loading: const SkeletonBlock(height: 240),
        data: (series) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _Key(color: t.chart.series(1), label: 'Fees'),
                const SizedBox(width: AppSpacing.x4),
                _Key(color: t.status.warning.solid, label: 'Fines'),
              ],
            ),
            const SizedBox(height: AppSpacing.x3),
            AppSeriesBarChart(
              height: 200,
              stacked: true,
              valueLabel: _money.format,
              labels: [for (final p in series.points) _axisLabel(p.date, series.granularity)],
              series: [
                AppSeries(
                  label: 'Fees',
                  color: t.chart.series(1),
                  values: [for (final p in series.points) p.fees],
                ),
                AppSeries(
                  label: 'Fines',
                  color: t.status.warning.solid,
                  values: [for (final p in series.points) p.fines],
                ),
              ],
            ),
            if (s != null) ...[
              const SizedBox(height: AppSpacing.x3),
              Divider(height: 1, color: t.border.subtle),
              const SizedBox(height: AppSpacing.x3),
              Row(
                children: [
                  Text('Unpaid now, live',
                      style: text.bodySmall?.copyWith(color: t.text.secondary)),
                  const Spacer(),
                  Text('Fees ${_moneyExact.format(s.feesPending)}',
                      style: AppTypography.tabular(text.titleSmall!)
                          .copyWith(color: t.status.accent.fg)),
                  const SizedBox(width: AppSpacing.x3),
                  Text('Fines ${_moneyExact.format(s.finesPending)}',
                      style: AppTypography.tabular(text.titleSmall!)
                          .copyWith(color: t.status.warning.fg)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Gate outcomes ────────────────────────────────────────────────────────────

class _GateOutcomesCard extends StatelessWidget {
  const _GateOutcomesCard({required this.period, required this.gate});

  final OverviewPeriod period;
  final AsyncValue<GateOutcomes> gate;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    return _Panel(
      title: 'Gate outcomes',
      caption: period.label,
      action: TextButton(
        onPressed: () => context.go('/gate-taps'),
        child: const Text('Open Gate Taps'),
      ),
      child: AsyncView(
        value: gate,
        loading: const SkeletonMetricRow(count: 5, width: 130),
        data: (g) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: AppSpacing.x8,
              runSpacing: AppSpacing.x4,
              children: [
                _Figure(label: 'Entered', value: '${g.entered}', intent: StatusIntent.success),
                _Figure(label: 'Exited', value: '${g.exited}', intent: StatusIntent.info),
                _Figure(
                  label: 'Plate mismatch',
                  value: '${g.plateMismatch}',
                  intent: g.plateMismatch > 0 ? StatusIntent.danger : null,
                ),
                _Figure(
                  label: 'Unknown card',
                  value: '${g.unknownCard}',
                  intent: g.unknownCard > 0 ? StatusIntent.danger : null,
                ),
                _Figure(
                  label: 'Routine refusals',
                  value: '${g.routineRefusals}',
                  intent: g.routineRefusals > 0 ? StatusIntent.warning : null,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.x3),
            Text(
              'Manual opens are left out. Routine refusals are a full lot, a double tap, or no camera reading.',
              style: text.labelSmall?.copyWith(color: t.text.tertiary),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Violations ───────────────────────────────────────────────────────────────

class _ViolationsByStatus extends StatelessWidget {
  const _ViolationsByStatus({required this.period, required this.violations});

  final OverviewPeriod period;
  final AsyncValue<ViolationBreakdown> violations;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      title: 'Violations by status',
      subtitle: 'Issued ${period.label.toLowerCase()}, by where each stands now',
      icon: Icons.pie_chart_outline,
      child: AsyncView(
        value: violations,
        loading: const SkeletonBlock(height: 200),
        data: (v) {
          final counts = {for (final s in v.byStatus) s.status: s.count};
          // All five statuses, even at zero, so the list is the same shape
          // every time and matches the Violations page.
          return _BarList(
            rows: [
              for (final status in ViolationStatuses.all)
                (
                  label: ViolationStatuses.label(status),
                  count: counts[status] ?? 0,
                  intent: StatusIntents.violation(status),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _MostViolatedRules extends StatelessWidget {
  const _MostViolatedRules({required this.period, required this.violations});

  final OverviewPeriod period;
  final AsyncValue<ViolationBreakdown> violations;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      title: 'Most violated rules',
      subtitle: period.label,
      icon: Icons.rule,
      child: AsyncView(
        value: violations,
        loading: const SkeletonBlock(height: 200),
        isEmpty: (v) => v.byRule.isEmpty,
        empty: const _NoViolations(),
        data: (v) => _BarList(
          rows: [
            for (var i = 0; i < v.byRule.length; i++)
              (
                label: v.byRule[i].ruleTitle,
                count: v.byRule[i].count,
                // The worst offender in red, the rest in amber.
                intent: i == 0 ? StatusIntent.danger : StatusIntent.warning,
              ),
          ],
        ),
      ),
    );
  }
}

class _NoViolations extends StatelessWidget {
  const _NoViolations();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.x4),
      child: Text(
        'No violations in this period.',
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: t.text.secondary),
      ),
    );
  }
}

/// A ranked list where each row carries its own proportion bar, so the reader
/// does not do the comparison arithmetic.
class _BarList extends StatelessWidget {
  const _BarList({required this.rows});

  final List<({String label, int count, StatusIntent intent})> rows;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final max = rows.map((r) => r.count).fold(0, (a, b) => a > b ? a : b);

    return Column(
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.x3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(row.label,
                          overflow: TextOverflow.ellipsis, style: text.bodyMedium),
                    ),
                    const SizedBox(width: AppSpacing.x2),
                    Text(
                      '${row.count}',
                      style: AppTypography.tabular(text.titleSmall!)
                          .copyWith(color: t.status.of(row.intent).fg),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.x1),
                ClipRRect(
                  borderRadius: AppRadii.fullAll,
                  child: LinearProgressIndicator(
                    value: max == 0 ? 0 : row.count / max,
                    minHeight: 6,
                    backgroundColor: t.surface.muted,
                    valueColor: AlwaysStoppedAnimation(t.status.of(row.intent).solid),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ── Layout ───────────────────────────────────────────────────────────────────

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.caption,
    required this.child,
    this.action,
  });

  final String title;
  final String caption;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(title, style: text.titleMedium),
              const SizedBox(width: AppSpacing.x2),
              Flexible(
                child: Text(
                  caption,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelSmall?.copyWith(color: t.text.tertiary),
                ),
              ),
              const Spacer(),
              ?action,
            ],
          ),
          const SizedBox(height: AppSpacing.x3),
          child,
        ],
      ),
    );
  }
}

/// Two panels side by side on a wide screen, stacked on a narrow one.
class _Pair extends StatelessWidget {
  const _Pair({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 900) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [left, const SizedBox(height: AppSpacing.gutter), right],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: left),
            const SizedBox(width: AppSpacing.gutter),
            Expanded(child: right),
          ],
        );
      },
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value, this.intent});

  final String label;
  final String value;

  /// Null when the number is zero and nothing is wrong: it stays quiet.
  final StatusIntent? intent;

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
          style: text.labelSmall?.copyWith(color: t.text.tertiary, letterSpacing: .6),
        ),
        Text(
          value,
          style: AppTypography.tabular(text.headlineSmall!).copyWith(
            color: intent == null ? t.text.primary : t.status.of(intent!).fg,
          ),
        ),
      ],
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.x2),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
