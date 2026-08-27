import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/utils/csv_export.dart';
import '../models/report.dart';
import '../providers/reports_provider.dart';
import '../theme/theme.dart';
import '../widgets/ui/ui.dart';

final _money = NumberFormat.currency(symbol: '₱', decimalDigits: 0);
final _moneyExact = NumberFormat.currency(symbol: '₱', decimalDigits: 2);
final _dayLabel = DateFormat('M/d');

/// The place to *study* the numbers, where the dashboard is the place to notice
/// them. Same providers, a selectable window, full breakdowns, and the export
/// the capstone document calls "Generated Reports".
class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = ref.watch(reportWindowProvider);
    final caption = 'Last $days days';

    final summary = ref.watch(reportsSummaryProvider);
    final occupancy = ref.watch(occupancyTrendProvider(days: days));
    final peaks = ref.watch(peakHoursProvider(days: days));
    final revenue = ref.watch(revenueTrendProvider(days: days));
    final breakdown = ref.watch(violationsBreakdownProvider);
    final entryExit = ref.watch(entryExitReportProvider(days: days));

    final ready = summary.hasValue &&
        occupancy.hasValue &&
        peaks.hasValue &&
        revenue.hasValue &&
        breakdown.hasValue;

    return AppPage(
      title: 'Reports & Monitoring',
      subtitle: 'Usage, revenue and enforcement across the whole system.',
      scrollable: true,
      actions: [
        // Disabled until every series has landed. A CSV built from four loaded
        // charts and one still spinning would be quietly incomplete, which is
        // worse than a button that is not offered yet.
        OutlinedButton.icon(
          icon: const Icon(Icons.download_outlined, size: AppSizes.iconSm),
          label: const Text('Export CSV'),
          onPressed: !ready
              ? null
              : () => _export(
                    context,
                    days: days,
                    summary: summary.requireValue,
                    occupancy: occupancy.requireValue,
                    peaks: peaks.requireValue,
                    revenue: revenue.requireValue,
                    breakdown: breakdown.requireValue,
                  ),
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
          onPressed: () {
            ref.invalidate(reportsSummaryProvider);
            ref.invalidate(occupancyTrendProvider);
            ref.invalidate(peakHoursProvider);
            ref.invalidate(entryExitReportProvider);
            ref.invalidate(revenueTrendProvider);
            ref.invalidate(violationsBreakdownProvider);
          },
        ),
      ],
      toolbar: AppToolbar(
        filters: [
          AppFilterDropdown<int>(
            label: 'Period',
            value: days,
            options: [
              for (final d in reportWindowOptions)
                AppFilterOption(d, 'Last $d days'),
            ],
            allLabel: 'Last 14 days',
            onChanged: (value) =>
                ref.read(reportWindowProvider.notifier).setDays(value ?? 14),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AsyncView(
            value: summary,
            onRetry: () => ref.invalidate(reportsSummaryProvider),
            loading: const SizedBox(height: 120, child: AppLoadingState()),
            data: (summary) => _SummaryTiles(summary: summary),
          ),
          const SizedBox(height: AppSpacing.gutter),
          _ChartPanel(
            title: 'Parking sessions',
            caption: caption,
            child: AsyncView(
              value: occupancy,
              onRetry: () => ref.invalidate(occupancyTrendProvider),
              data: (points) => AppBarChart(
                height: 260,
                data: [
                  for (final p in points)
                    AppChartDatum(
                      label: _dayLabel.format(p.date.toLocal()),
                      value: p.count.toDouble(),
                      tooltip:
                          '${_dayLabel.format(p.date.toLocal())} · ${p.count} sessions',
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.gutter),
          _ChartPanel(
            title: 'Entries and exits',
            caption: caption,
            child: AsyncView(
              value: entryExit,
              onRetry: () => ref.invalidate(entryExitReportProvider),
              data: (report) => _EntryExitPanel(report: report),
            ),
          ),
          const SizedBox(height: AppSpacing.gutter),
          _ChartPanel(
            title: 'Peak hours',
            caption: caption,
            child: AsyncView(
              value: peaks,
              onRetry: () => ref.invalidate(peakHoursProvider),
              data: (points) => AppBarChart(
                height: 260,
                seriesIndex: 2,
                data: [
                  for (final p in points)
                    AppChartDatum(
                      label: '${p.hour}',
                      value: p.count.toDouble(),
                      tooltip: '${p.count} entries around ${_hour(p.hour)}',
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.gutter),
          _ChartPanel(
            title: 'Revenue collected',
            caption: caption,
            child: AsyncView(
              value: revenue,
              onRetry: () => ref.invalidate(revenueTrendProvider),
              data: (points) => AppAreaChart(
                height: 260,
                seriesIndex: 5,
                valueLabel: _money.format,
                data: [
                  for (final p in points)
                    AppChartDatum(
                      label: _dayLabel.format(p.date.toLocal()),
                      value: p.amount,
                      tooltip:
                          '${_dayLabel.format(p.date.toLocal())} · ${_moneyExact.format(p.amount)}',
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.gutter),
          AsyncView(
            value: breakdown,
            onRetry: () => ref.invalidate(violationsBreakdownProvider),
            data: (breakdown) => _BreakdownSection(breakdown: breakdown),
          ),
        ],
      ),
    );
  }

  /// Exports every series on the page as one CSV.
  ///
  /// Written as labelled blocks rather than one wide table: these series have
  /// genuinely different shapes — a day, an hour of the day, a rule — and
  /// forcing them into shared columns produces a sheet nobody can read. Each
  /// block can be selected and charted on its own in Excel.
  void _export(
    BuildContext context, {
    required int days,
    required ReportsSummary summary,
    required List<DailyCountPoint> occupancy,
    required List<PeakHourPoint> peaks,
    required List<RevenuePoint> revenue,
    required ViolationBreakdown breakdown,
  }) {
    final now = DateTime.now();
    final isoDay = DateFormat('yyyy-MM-dd');

    final rows = <List<Object?>>[
      ['Generated', DateFormat('yyyy-MM-dd HH:mm').format(now)],
      ['Period', 'Last $days days'],
      [],
      ['Summary'],
      ['Total users', summary.totalUsers],
      ['Active users', summary.activeUsers],
      ['Total slots', summary.totalSlots],
      ['Occupied slots', summary.occupiedSlots],
      ['Available slots', summary.availableSlots],
      ['Out of service slots', summary.outOfServiceSlots],
      ['Sessions today', summary.sessionsToday],
      ['Revenue collected', summary.revenueCollected.toStringAsFixed(2)],
      ['Revenue pending', summary.revenuePending.toStringAsFixed(2)],
      ['Violations issued', summary.violationsIssued],
      ['Open incidents', summary.openIncidents],
      [],
      ['Parking sessions'],
      ['Date', 'Sessions'],
      for (final p in occupancy) [isoDay.format(p.date.toLocal()), p.count],
      [],
      ['Peak hours'],
      ['Hour', 'Entries'],
      for (final p in peaks) [_hour(p.hour), p.count],
      [],
      ['Revenue collected'],
      ['Date', 'Amount'],
      for (final p in revenue)
        [isoDay.format(p.date.toLocal()), p.amount.toStringAsFixed(2)],
      [],
      ['Violations by status'],
      ['Status', 'Count'],
      for (final s in breakdown.byStatus) [s.status, s.count],
      [],
      ['Most violated rules'],
      ['Rule', 'Count'],
      for (final r in breakdown.byRule) [r.ruleTitle, r.count],
    ];

    CsvExport.save(
      fileName: 'aimpark-report-${DateFormat('yyyyMMdd-HHmm').format(now)}.csv',
      headers: const ['AimPark — Reports & Monitoring'],
      rows: rows,
    );

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Report exported.')));
  }

  static String _hour(int hour) {
    final suffix = hour < 12 ? 'am' : 'pm';
    final display = hour % 12 == 0 ? 12 : hour % 12;
    return '$display$suffix';
  }
}

// ── Summary tiles ────────────────────────────────────────────────────────────

class _SummaryTiles extends StatelessWidget {
  const _SummaryTiles({required this.summary});

  final ReportsSummary summary;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = (constraints.maxWidth / 220).floor().clamp(1, 4);
        final width =
            (constraints.maxWidth - AppSpacing.gutter * (columns - 1)) / columns;

        return Wrap(
          spacing: AppSpacing.gutter,
          runSpacing: AppSpacing.gutter,
          children: [
            MetricCard(
              width: width,
              label: 'Total users',
              value: '${summary.totalUsers}',
              icon: Icons.people_outline,
              intent: StatusIntent.info,
              caption: '${summary.activeUsers} active',
            ),
            MetricCard(
              width: width,
              label: 'Slots occupied',
              // Against usable bays, not every bay that exists — an out-of-
              // service bay is not capacity you can sell.
              value: '${summary.occupiedSlots}/${summary.usableSlots}',
              icon: Icons.local_parking_outlined,
              intent: StatusIntent.accent,
              caption: summary.outOfServiceSlots > 0
                  ? '${summary.availableSlots} free · ${summary.outOfServiceSlots} out of service'
                  : '${summary.availableSlots} free',
            ),
            MetricCard(
              width: width,
              label: 'Sessions today',
              value: '${summary.sessionsToday}',
              icon: Icons.directions_car_outlined,
              intent: StatusIntent.info,
            ),
            MetricCard(
              width: width,
              label: 'Revenue collected',
              value: _money.format(summary.revenueCollected),
              icon: Icons.payments_outlined,
              intent: StatusIntent.success,
              caption: '${_money.format(summary.revenuePending)} pending',
            ),
            MetricCard(
              width: width,
              label: 'Violations issued',
              value: '${summary.violationsIssued}',
              icon: Icons.gavel_outlined,
              intent: StatusIntent.warning,
            ),
            MetricCard(
              width: width,
              label: 'Open incidents',
              value: '${summary.openIncidents}',
              icon: Icons.report_outlined,
              intent: summary.openIncidents > 0
                  ? StatusIntent.danger
                  : StatusIntent.success,
            ),
          ],
        );
      },
    );
  }
}

// ── Violation breakdown ──────────────────────────────────────────────────────

class _BreakdownSection extends StatelessWidget {
  const _BreakdownSection({required this.breakdown});

  final ViolationBreakdown breakdown;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final byStatus = AppSectionCard(
          title: 'Violations by status',
          icon: Icons.pie_chart_outline,
          child: _BarList(
            rows: [
              for (final s in breakdown.byStatus)
                (
                  label: s.status,
                  count: s.count,
                  intent: StatusIntents.violation(s.status)
                ),
            ],
          ),
        );

        final byRule = AppSectionCard(
          title: 'Most violated rules',
          icon: Icons.rule,
          child: _BarList(
            rows: [
              for (final r in breakdown.byRule)
                (
                  label: r.ruleTitle,
                  count: r.count,
                  intent: StatusIntent.warning
                ),
            ],
          ),
        );

        if (constraints.maxWidth < 900) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              byStatus,
              const SizedBox(height: AppSpacing.gutter),
              byRule,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: byStatus),
            const SizedBox(width: AppSpacing.gutter),
            Expanded(child: byRule),
          ],
        );
      },
    );
  }
}

/// A ranked list where each row carries its own proportion bar.
///
/// The old version was a label and a number in a row, which made the reader do
/// the comparison arithmetic. The bar does it for them, and costs one Container.
class _BarList extends StatelessWidget {
  const _BarList({required this.rows});

  final List<({String label, int count, StatusIntent intent})> rows;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    if (rows.isEmpty) {
      return Text(
        'No violations recorded yet.',
        style: text.bodySmall?.copyWith(color: t.text.secondary),
      );
    }

    final max = rows.map((r) => r.count).reduce((a, b) => a > b ? a : b);

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
                      child: Text(
                        row.label,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodyMedium,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.x2),
                    Text('${row.count}',
                        style: AppTypography.tabular(text.titleSmall!)),
                  ],
                ),
                const SizedBox(height: AppSpacing.x1),
                ClipRRect(
                  borderRadius: AppRadii.fullAll,
                  child: LinearProgressIndicator(
                    value: max == 0 ? 0 : row.count / max,
                    minHeight: 6,
                    backgroundColor: t.surface.muted,
                    valueColor:
                        AlwaysStoppedAnimation(t.status.of(row.intent).solid),
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

class _ChartPanel extends StatelessWidget {
  const _ChartPanel({
    required this.title,
    required this.caption,
    required this.child,
  });

  final String title;
  final String caption;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title, style: text.titleMedium),
              const Spacer(),
              Text(caption,
                  style: text.labelSmall?.copyWith(color: t.text.secondary)),
            ],
          ),
          const SizedBox(height: AppSpacing.x4),
          child,
        ],
      ),
    );
  }
}

/// Vehicles in against vehicles out, with the counts that put the chart in
/// context.
///
/// Two bars a day rather than one net figure, because the gap between them is
/// the point: entries far ahead of exits means cars are going in and never
/// being logged out, which is the failure mode a manual gate actually has.
class _EntryExitPanel extends StatelessWidget {
  const _EntryExitPanel({required this.report});

  final EntryExitReport report;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: AppSpacing.x6,
          runSpacing: AppSpacing.x3,
          children: [
            _Figure(label: 'Entries', value: '${report.totalEntries}'),
            _Figure(label: 'Exits', value: '${report.totalExits}'),
            _Figure(
              label: 'Visitor entries',
              value: '${report.totalVisitorEntries}',
            ),
            _Figure(
              label: 'Still inside',
              value: '${report.stillOpen}',
              // Cars in the lot right now are expected. A big number here means
              // exits are not being logged, so it is worth a colour.
              intent: report.stillOpen > report.totalEntries * 0.2
                  ? StatusIntent.warning
                  : null,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.x5),
        Row(
          children: [
            _Key(color: t.chart.series(0), label: 'In'),
            const SizedBox(width: AppSpacing.x4),
            _Key(color: t.chart.series(1), label: 'Out'),
          ],
        ),
        const SizedBox(height: AppSpacing.x3),
        AppBarChart(
          height: 130,
          data: [
            for (final p in report.points)
              AppChartDatum(
                label: _dayLabel.format(p.date.toLocal()),
                value: p.entries.toDouble(),
                tooltip:
                    '${_dayLabel.format(p.date.toLocal())} · ${p.entries} in',
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.x2),
        AppBarChart(
          height: 130,
          seriesIndex: 1,
          data: [
            for (final p in report.points)
              AppChartDatum(
                label: _dayLabel.format(p.date.toLocal()),
                value: p.exits.toDouble(),
                tooltip:
                    '${_dayLabel.format(p.date.toLocal())} · ${p.exits} out',
              ),
          ],
        ),
      ],
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value, this.intent});

  final String label;
  final String value;
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
          style: text.labelSmall
              ?.copyWith(color: t.text.tertiary, letterSpacing: .6),
        ),
        Text(
          value,
          style: text.headlineSmall?.copyWith(
            color: intent == null ? t.text.primary : t.status.of(intent!).solid,
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
