import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../core/utils/csv_export.dart';
import '../models/report.dart';
import '../providers/auth_provider.dart';
import '../providers/gate_device_provider.dart';
import '../providers/parking_provider.dart';
import '../providers/registrations_provider.dart';
import '../providers/reports_provider.dart';
import '../router/destinations.dart';
import '../theme/theme.dart';
import '../widgets/ui/ui.dart';

final _money = NumberFormat.currency(symbol: '₱', decimalDigits: 0);
final _moneyExact = NumberFormat.currency(symbol: '₱', decimalDigits: 2);
final _dayLabel = DateFormat('M/d');
final _timeLabel = DateFormat('h:mm a');

/// The range every trend on this page reads through — one control, so
/// "7 days" means the same thing to the KPI deltas, the dual chart and the
/// peak-hours rose at once, the way the reference dashboard's top-of-page
/// pills govern its whole "Fleet overview".
final _dashboardRangeProvider = StateProvider<int>((ref) => 14);

/// The panel's front door.
///
/// Every other screen answers "show me the list of X". This one answers "is
/// anything wrong right now, and how busy are we" — which is the question an
/// administrator actually opens the tool with, and the reason a work queue was
/// the wrong thing to land on.
///
/// It adds no endpoints. Every number here already had a provider built for
/// Reports; the difference is that Reports is where you go to *study* the data
/// and this is where you go to *notice* it.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(_dashboardRangeProvider);

    return AppPage(
      title: 'Overview',
      eyebrow: 'STI BALIUAG · PARKING OPERATIONS',
      subtitle: 'STI Baliuag parking, as it stands right now.',
      scrollable: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
          onPressed: () {
            ref.invalidate(reportsSummaryProvider);
            ref.invalidate(occupancyTrendProvider);
            ref.invalidate(revenueTrendProvider);
            ref.invalidate(peakHoursProvider);
            ref.invalidate(pendingRegistrationsProvider);
            ref.invalidate(parkingSlotsProvider);
            ref.invalidate(gateDeviceListProvider);
            ref.invalidate(activeParkingSessionsProvider);
          },
        ),
        const SizedBox(width: AppSpacing.x2),
        _RangePills(
          value: range,
          onChanged: (v) => ref.read(_dashboardRangeProvider.notifier).state = v,
        ),
        const SizedBox(width: AppSpacing.x2),
        _ExportButton(range: range),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AsyncView(
            value: ref.watch(reportsSummaryProvider),
            onRetry: () => ref.invalidate(reportsSummaryProvider),
            loading: const Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SkeletonMetricRow(),
                SizedBox(height: AppSpacing.gutter),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: SkeletonBlock(height: 340)),
                    SizedBox(width: AppSpacing.gutter),
                    Expanded(child: SkeletonBlock(height: 340)),
                  ],
                ),
              ],
            ),
            data: (summary) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _MetricRow(summary: summary, range: range),
                const SizedBox(height: AppSpacing.gutter),
                _TwoUp(
                  leftFlex: 5,
                  rightFlex: 4,
                  left: const _GateHeroCard(),
                  right: _ChartPanel(
                    title: 'Sessions vs revenue',
                    caption: 'Last $range days',
                    child: _SessionsRevenueChart(range: range),
                  ),
                ),
                const SizedBox(height: AppSpacing.gutter),
                _BottomRow(summary: summary, range: range),
                const SizedBox(height: AppSpacing.gutter),
                _TwoUp(
                  left: const _ActiveSessionsCard(),
                  right: _AttentionCard(summary: summary),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          const _ModuleShortcuts(),
        ],
      ),
    );
  }
}

// ── Header controls ──────────────────────────────────────────────────────────

class _RangePills extends StatelessWidget {
  const _RangePills({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  static const _options = [7, 14, 30];

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: t.surface.muted, borderRadius: AppRadii.fullAll),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final days in _options)
            GestureDetector(
              onTap: () => onChanged(days),
              child: AnimatedContainer(
                duration: AppMotion.fast,
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.x3, vertical: AppSpacing.x1 + 2),
                decoration: BoxDecoration(
                  color: value == days ? t.surface.card : Colors.transparent,
                  borderRadius: AppRadii.fullAll,
                  boxShadow: value == days ? AppElevation.sm : null,
                ),
                child: Text(
                  '${days}d',
                  style: text.labelMedium?.copyWith(
                    color: value == days ? t.text.primary : t.text.secondary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ExportButton extends ConsumerWidget {
  const _ExportButton({required this.range});

  final int range;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FilledButton.icon(
      icon: const Icon(Icons.ios_share, size: AppSizes.iconSm),
      label: const Text('Export'),
      onPressed: () async {
        final summary = await ref.read(reportsSummaryProvider.future);
        final revenue = await ref.read(revenueTrendProvider(days: range).future);
        final sessions = await ref.read(occupancyTrendProvider(days: range).future);
        CsvExport.save(
          fileName: 'aimpark_overview.csv',
          headers: const ['Date', 'Sessions', 'Revenue'],
          rows: [
            for (var i = 0; i < revenue.length; i++)
              [
                _dayLabel.format(revenue[i].date.toLocal()),
                i < sessions.length ? sessions[i].count : '',
                revenue[i].amount,
              ],
          ],
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Exported ${summary.sessionsToday} sessions today · '
                '${revenue.length} days of history.')),
          );
        }
      },
    );
  }
}

// ── Module shortcuts ─────────────────────────────────────────────────────────

/// A tile per module, which is what the capstone document means by the
/// dashboard's job: "see and navigate tools and see different modules".
class _ModuleShortcuts extends ConsumerWidget {
  const _ModuleShortcuts();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final shortcuts = moduleShortcutsFor(
      ref.watch(staffRoleProvider) ?? StaffRole.admin,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Modules', style: text.titleMedium),
        const SizedBox(height: AppSpacing.labelGap),
        Text(
          'Every tool in the administrator panel.',
          style: text.bodySmall?.copyWith(color: t.text.secondary),
        ),
        const SizedBox(height: AppSpacing.headingGap),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = switch (constraints.maxWidth) {
              > 1380 => 5,
              > 1200 => 4,
              > 860 => 3,
              > 520 => 2,
              _ => 1,
            };
            final width =
                (constraints.maxWidth - AppSpacing.gutter * (columns - 1)) /
                columns;

            return Wrap(
              spacing: AppSpacing.gutter,
              runSpacing: AppSpacing.gutter,
              children: [
                for (final item in shortcuts)
                  _ModuleTile(
                    item: item,
                    width: width,
                    emphasized: _dailyDriverRoutes.contains(item.route),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

const _dailyDriverRoutes = {'/pending', '/parking', '/payments', '/violations'};

class _ModuleTile extends StatelessWidget {
  const _ModuleTile({
    required this.item,
    required this.width,
    required this.emphasized,
  });

  final NavItem item;
  final double width;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final accent = _categoryColor(item, t);
    final chipStart = Color.lerp(accent, Colors.white, emphasized ? 0.1 : 0.75)!;

    return AppCard(
      width: width,
      padding: EdgeInsets.zero,
      onTap: () => context.go(item.route),
      selected: emphasized,
      accentColor: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // A category stripe rather than a uniform blue chip everywhere —
          // Gate, Operations, Enforcement and System each keep their own hue
          // from the top nav all the way down into this grid.
          Container(height: 3, color: accent),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [chipStart, accent],
                        ),
                        borderRadius: AppRadii.mdAll,
                      ),
                      child: Icon(
                        item.icon,
                        size: AppSizes.iconMd,
                        color: emphasized ? t.text.onBrand : Color.lerp(accent, Colors.black, 0.25),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.x3),
                    Expanded(
                      child: Text(
                        item.displayLabel,
                        style: text.titleSmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.x3),
                Text(
                  item.description,
                  style: text.bodySmall?.copyWith(color: t.text.secondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Each destination's colour follows the group it belongs to, so the
/// Modules grid reads as an extension of the top nav's own groups rather than
/// a wall of identically-styled tiles.
Color _categoryColor(NavItem item, AppTokens t) {
  for (final group in navGroups) {
    if (!group.items.contains(item)) continue;
    return switch (group.label) {
      'Gate' => t.chart.series(0),
      'Operations' => t.chart.series(4),
      'Enforcement' => t.chart.series(1),
      'System' => t.chart.series(2),
      _ => t.brand.primary,
    };
  }
  return t.brand.primary;
}

// ── Metric row ───────────────────────────────────────────────────────────────

class _MetricRow extends ConsumerWidget {
  const _MetricRow({required this.summary, required this.range});

  final ReportsSummary summary;
  final int range;

  /// A real period-over-period change from a trend series, or null when there
  /// isn't enough history to say anything — no fabricated percentage stands
  /// in for a number the API never gave us.
  String? _delta(List<double> series, {required void Function(bool up) report}) {
    if (series.length < 2) return null;
    final last = series.last;
    final prev = series[series.length - 2];
    if (prev == 0) return null;
    final change = (last - prev) / prev * 100;
    report(change >= 0);
    final sign = change >= 0 ? '+' : '';
    return '$sign${change.toStringAsFixed(1)}%';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final revenue = ref.watch(revenueTrendProvider(days: range)).valueOrNull;
    final sessions = ref.watch(occupancyTrendProvider(days: range)).valueOrNull;

    var revenueUp = true;
    var sessionsUp = true;
    final revenueDelta = revenue == null
        ? null
        : _delta(
            [for (final p in revenue) p.amount],
            report: (up) => revenueUp = up,
          );
    final sessionsDelta = sessions == null
        ? null
        : _delta(
            [for (final p in sessions) p.count.toDouble()],
            report: (up) => sessionsUp = up,
          );

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 1000
            ? 4
            : constraints.maxWidth > 560
            ? 2
            : 1;
        final width =
            (constraints.maxWidth - AppSpacing.gutter * (columns - 1)) /
            columns;

        return Wrap(
          spacing: AppSpacing.gutter,
          runSpacing: AppSpacing.gutter,
          children: [
            MetricCard(
              width: width,
              label: 'Sessions today',
              value: '${summary.sessionsToday}',
              icon: Icons.directions_car_outlined,
              dotColor: t.chart.series(0),
              delta: sessionsDelta,
              deltaPositive: sessionsUp,
              caption: '${summary.activeUsers} active accounts',
            ),
            MetricCard(
              width: width,
              label: 'Revenue collected',
              value: _money.format(summary.revenueCollected),
              icon: Icons.payments_outlined,
              dotColor: t.chart.series(4),
              delta: revenueDelta,
              deltaPositive: revenueUp,
              caption: summary.revenuePending > 0
                  ? '${_money.format(summary.revenuePending)} still outstanding'
                  : 'Nothing outstanding',
            ),
            MetricCard(
              width: width,
              label: 'Slots available',
              value: '${summary.availableSlots}',
              icon: Icons.local_parking_outlined,
              intent: summary.availableSlots == 0
                  ? StatusIntent.danger
                  : StatusIntent.accent,
              dotColor: summary.availableSlots == 0 ? null : t.chart.series(5),
              caption: summary.outOfServiceSlots > 0
                  ? 'of ${summary.usableSlots} usable'
                  : 'of ${summary.totalSlots} total',
            ),
            MetricCard(
              width: width,
              label: 'Open incidents',
              value: '${summary.openIncidents}',
              icon: Icons.report_outlined,
              intent: summary.openIncidents > 0
                  ? StatusIntent.warning
                  : StatusIntent.success,
              dotColor: summary.openIncidents > 0 ? null : t.chart.series(1),
              caption: '${summary.violationsIssued} violations issued',
            ),
          ],
        );
      },
    );
  }
}

// ── Gate hero card ───────────────────────────────────────────────────────────

/// The page's featured panel: a tinted, hatched band (the reference
/// dashboard's live-camera treatment, given to a real live figure instead)
/// with a floating status card over it, a gate switcher, and the two-tile
/// footer the reference uses under its turbine reading.
class _GateHeroCard extends ConsumerStatefulWidget {
  const _GateHeroCard();

  @override
  ConsumerState<_GateHeroCard> createState() => _GateHeroCardState();
}

class _GateHeroCardState extends ConsumerState<_GateHeroCard> {
  int? _gate;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final slotsAsync = ref.watch(parkingSlotsProvider);
    final devicesAsync = ref.watch(gateDeviceListProvider);
    final accent = t.chart.series(0);

    return AppCard(
      padding: EdgeInsets.zero,
      child: slotsAsync.when(
        loading: () => const SizedBox(height: 340, child: Center(child: CircularProgressIndicator())),
        error: (e, _) => SizedBox(
          height: 340,
          child: Center(
            child: Text('Could not load gate status',
                style: text.bodySmall?.copyWith(color: t.text.tertiary)),
          ),
        ),
        data: (availability) {
          final gates = availability.slots.map((s) => s.gate).toSet().toList()..sort();
          final gate = _gate != null && gates.contains(_gate) ? _gate! : (gates.isEmpty ? 1 : gates.first);
          final slots = availability.slots.where((s) => s.gate == gate).toList();
          final total = slots.length;
          final occupied = slots.where((s) => s.status == 'Occupied').length;
          final free = total - occupied;
          final ratio = total == 0 ? 0.0 : occupied / total;

          final devices = devicesAsync.valueOrNull?.where((d) => d.gate == gate).toList() ?? [];
          final activeDevices = devices.where((d) => !d.isRevoked).length;
          final lastSeen = devices
              .map((d) => d.lastSeenAt)
              .whereType<DateTime>()
              .fold<DateTime?>(null, (a, b) => a == null || b.isAfter(a) ? b : a);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 172,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(color: accent.withValues(alpha: 0.07)),
                    AppHatchPattern(color: accent.withValues(alpha: 0.16)),
                    Positioned(
                      left: AppSpacing.cardPadding,
                      top: AppSpacing.x3,
                      child: _GatePicker(
                        gates: gates,
                        selected: gate,
                        onChanged: (g) => setState(() => _gate = g),
                      ),
                    ),
                    Positioned(
                      right: AppSpacing.cardPadding,
                      top: AppSpacing.x3,
                      child: const StatusPill(
                          label: 'LIVE', intent: StatusIntent.success, dense: true),
                    ),
                    Center(
                      child: AppArcGauge(
                        value: ratio,
                        size: 130,
                        strokeWidth: 12,
                        color: accent,
                        minLabel: '0',
                        maxLabel: '$total',
                        center: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('$occupied',
                                style: AppTypography.tabular(text.headlineSmall!)),
                            Text('occupied',
                                style: text.bodySmall?.copyWith(color: t.text.secondary)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Transform.translate(
                offset: const Offset(0, -16),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
                  padding: const EdgeInsets.all(AppSpacing.cardPadding),
                  decoration: BoxDecoration(
                    color: t.surface.card,
                    borderRadius: AppRadii.lgAll,
                    border: Border.all(color: t.border.normal),
                    boxShadow: AppElevation.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Text('Status', style: text.titleMedium),
                          const Spacer(),
                          StatusPill.of(
                            activeDevices > 0 ? 'Active' : 'No devices',
                            intent: activeDevices > 0
                                ? StatusIntent.success
                                : StatusIntent.neutral,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.x3),
                      _FieldRow(label: 'Slots free', value: '$free'),
                      _FieldRow(
                          label: 'Devices online',
                          value: '$activeDevices of ${devices.length}'),
                      _FieldRow(
                        label: 'Last device sync',
                        value: lastSeen == null ? '—' : _timeLabel.format(lastSeen.toLocal()),
                      ),
                      const Divider(height: AppSpacing.x6),
                      Row(
                        children: [
                          Expanded(
                            child: _StatTile(label: 'Free bays', value: '$free'),
                          ),
                          Container(width: 1, height: 32, color: t.border.subtle),
                          Expanded(
                            child: _StatTile(label: 'Total bays', value: '$total'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.x2),
            ],
          );
        },
      ),
    );
  }
}

class _GatePicker extends StatelessWidget {
  const _GatePicker({required this.gates, required this.selected, required this.onChanged});

  final List<int> gates;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    return PopupMenuButton<int>(
      tooltip: 'Choose gate',
      onSelected: onChanged,
      color: t.surface.overlay,
      itemBuilder: (context) => [
        for (final g in gates)
          PopupMenuItem(value: g, child: Text('Gate $g')),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x3, vertical: AppSpacing.x1 + 2),
        decoration: BoxDecoration(
          color: t.surface.card,
          borderRadius: AppRadii.fullAll,
          boxShadow: AppElevation.sm,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Gate $selected', style: text.labelLarge),
            const SizedBox(width: AppSpacing.x1),
            Icon(Icons.expand_more, size: AppSizes.iconSm, color: t.text.secondary),
          ],
        ),
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  const _FieldRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.x1 + 1),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: text.bodySmall?.copyWith(color: t.text.secondary)),
          ),
          Text(value, style: AppTypography.tabular(text.titleSmall!)),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: text.labelSmall?.copyWith(color: t.text.tertiary)),
        const SizedBox(height: 2),
        Text(value, style: AppTypography.tabular(text.titleMedium!)),
      ],
    );
  }
}

// ── Sessions vs revenue chart ────────────────────────────────────────────────

class _SessionsRevenueChart extends ConsumerWidget {
  const _SessionsRevenueChart({required this.range});

  final int range;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(occupancyTrendProvider(days: range));
    final revenue = ref.watch(revenueTrendProvider(days: range));

    if (sessions.isLoading || revenue.isLoading) {
      return const SkeletonBlock();
    }
    final s = sessions.valueOrNull ?? [];
    final r = revenue.valueOrNull ?? [];
    final n = s.length < r.length ? s.length : r.length;

    return AppDualBarChart(
      labelA: 'Sessions',
      labelB: 'Revenue',
      formatB: _money.format,
      dataA: [
        for (var i = 0; i < n; i++)
          AppChartDatum(
            label: _dayLabel.format(s[i].date.toLocal()),
            value: s[i].count.toDouble(),
            tooltip: '${_dayLabel.format(s[i].date.toLocal())} · ${s[i].count} sessions',
          ),
      ],
      dataB: [
        for (var i = 0; i < n; i++)
          AppChartDatum(
            label: _dayLabel.format(r[i].date.toLocal()),
            value: r[i].amount,
            tooltip: '${_dayLabel.format(r[i].date.toLocal())} · ${_moneyExact.format(r[i].amount)}',
          ),
      ],
    );
  }
}

// ── Bottom row: gauge, gate levels, peak-hour rose, device health ───────────

class _BottomRow extends StatelessWidget {
  const _BottomRow({required this.summary, required this.range});

  final ReportsSummary summary;
  final int range;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 1200
            ? 4
            : constraints.maxWidth > 700
            ? 2
            : 1;
        final width =
            (constraints.maxWidth - AppSpacing.gutter * (columns - 1)) / columns;

        return Wrap(
          spacing: AppSpacing.gutter,
          runSpacing: AppSpacing.gutter,
          children: [
            SizedBox(width: width, child: _OccupancyGaugeCard(summary: summary)),
            SizedBox(width: width, child: const _GateLevelsCard()),
            SizedBox(width: width, child: _PeakHoursCard(range: range)),
            SizedBox(width: width, child: const _DeviceHealthCard()),
          ],
        );
      },
    );
  }
}

class _OccupancyGaugeCard extends StatelessWidget {
  const _OccupancyGaugeCard({required this.summary});

  final ReportsSummary summary;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final ratio = summary.occupancyRatio;
    final percent = (ratio * 100).round();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Real-time occupancy', style: text.titleMedium),
              const Spacer(),
              Icon(Icons.more_horiz, size: AppSizes.iconMd, color: t.text.tertiary),
            ],
          ),
          const SizedBox(height: AppSpacing.x3),
          Center(
            child: AppArcGauge(
              value: ratio,
              minLabel: '0',
              maxLabel: '${summary.usableSlots}',
              color: t.brand.primary,
              center: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${summary.occupiedSlots}',
                      style: AppTypography.tabular(text.headlineSmall!)),
                  Text('$percent%', style: text.bodySmall?.copyWith(color: t.text.secondary)),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.x4),
          Row(
            children: [
              Expanded(child: _StatTile(label: 'Occupied', value: '${summary.occupiedSlots}')),
              Expanded(child: _StatTile(label: 'Available', value: '${summary.availableSlots}')),
            ],
          ),
          const SizedBox(height: AppSpacing.x3),
          Row(
            children: [
              Expanded(child: _StatTile(label: 'Capacity', value: '$percent%')),
              Expanded(child: _StatTile(label: 'Total', value: '${summary.totalSlots}')),
            ],
          ),
        ],
      ),
    );
  }
}

class _GateLevelsCard extends ConsumerWidget {
  const _GateLevelsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final availability = ref.watch(parkingSlotsProvider).valueOrNull;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Gate fill level', style: text.titleMedium),
              const Spacer(),
              Icon(Icons.more_horiz, size: AppSizes.iconMd, color: t.text.tertiary),
            ],
          ),
          const SizedBox(height: AppSpacing.x4),
          if (availability == null)
            const SizedBox(height: 110)
          else
            Builder(builder: (context) {
              final gates = availability.slots.map((s) => s.gate).toSet().toList()..sort();
              final data = <AppLevelDatum>[];
              String? warning;
              for (final g in gates) {
                final slots = availability.slots.where((s) => s.gate == g).toList();
                final occupied = slots.where((s) => s.status == 'Occupied').length;
                final total = slots.length;
                final ratio = total == 0 ? 0.0 : occupied / total;
                if (ratio >= 0.9) warning = 'Gate $g is nearly full.';
                data.add(AppLevelDatum(
                  label: 'Gate $g',
                  valueLabel: '$occupied/$total',
                  ratio: ratio,
                  color: t.chart.series(gates.indexOf(g)),
                ));
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppLevelBars(data: data),
                  if (warning != null) ...[
                    const SizedBox(height: AppSpacing.x4),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.x3),
                      decoration: BoxDecoration(
                        color: t.status.warning.bg,
                        borderRadius: AppRadii.mdAll,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              size: AppSizes.iconSm, color: t.status.warning.fg),
                          const SizedBox(width: AppSpacing.x2),
                          Expanded(
                            child: Text(warning,
                                style: text.bodySmall?.copyWith(color: t.status.warning.fg)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              );
            }),
        ],
      ),
    );
  }
}

class _PeakHoursCard extends ConsumerWidget {
  const _PeakHoursCard({required this.range});

  final int range;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final points = ref.watch(peakHoursProvider(days: range)).valueOrNull;

    final byHour = <int, int>{for (var h = 0; h < 24; h++) h: 0};
    for (final p in points ?? <PeakHourPoint>[]) {
      byHour[p.hour] = p.count;
    }
    final busiest = byHour.entries.isEmpty
        ? null
        : byHour.entries.reduce((a, b) => a.value >= b.value ? a : b);
    final total = byHour.values.fold(0, (a, b) => a + b);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Peak hours', style: text.titleMedium),
              const Spacer(),
              Text('Last $range days',
                  style: text.labelSmall?.copyWith(color: t.text.secondary)),
            ],
          ),
          const SizedBox(height: AppSpacing.x3),
          Center(
            child: AppPolarBarChart(
              size: 176,
              lowColor: t.chart.series(4),
              highColor: t.chart.series(3),
              data: [
                for (final e in byHour.entries)
                  AppPolarDatum(label: '${e.key}', value: e.value.toDouble()),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.x3),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: 'Busiest hour',
                  value: busiest == null || busiest.value == 0
                      ? '—'
                      : _hour(busiest.key),
                ),
              ),
              Expanded(child: _StatTile(label: 'Total entries', value: '$total')),
            ],
          ),
        ],
      ),
    );
  }

  static String _hour(int hour) {
    final suffix = hour < 12 ? 'am' : 'pm';
    final display = hour % 12 == 0 ? 12 : hour % 12;
    return '$display$suffix';
  }
}

class _DeviceHealthCard extends ConsumerWidget {
  const _DeviceHealthCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final devices = ref.watch(gateDeviceListProvider).valueOrNull ?? [];
    final active = devices.where((d) => !d.isRevoked).length;
    final total = devices.length;
    final ratio = total == 0 ? 0.0 : active / total;
    final percent = (ratio * 100).round();
    final lastSeen = devices
        .map((d) => d.lastSeenAt)
        .whereType<DateTime>()
        .fold<DateTime?>(null, (a, b) => a == null || b.isAfter(a) ? b : a);
    final accent = t.chart.series(4);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: t.surface.inverse,
        borderRadius: AppRadii.lgAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Device health',
                  style: text.titleMedium?.copyWith(color: t.text.inverse)),
              const Spacer(),
              Icon(Icons.more_horiz, size: AppSizes.iconMd, color: t.text.inverseMuted),
            ],
          ),
          const SizedBox(height: AppSpacing.x3),
          Center(
            child: AppProgressRing(
              value: ratio,
              size: 128,
              strokeWidth: 12,
              color: accent,
              center: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('ACTIVE',
                      style: text.labelSmall?.copyWith(
                          color: t.text.inverseMuted, letterSpacing: 0.6)),
                  Text('$percent%',
                      style: AppTypography.tabular(text.headlineSmall!)
                          .copyWith(color: t.text.inverse)),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.x4),
          Divider(height: 1, color: t.text.inverseMuted.withValues(alpha: 0.16)),
          const SizedBox(height: AppSpacing.x3),
          _DarkFieldRow(label: 'Active devices', value: '$active'),
          _DarkFieldRow(label: 'Revoked', value: '${total - active}'),
          _DarkFieldRow(
            label: 'Last seen',
            value: lastSeen == null ? '—' : _timeLabel.format(lastSeen.toLocal()),
          ),
        ],
      ),
    );
  }
}

class _DarkFieldRow extends StatelessWidget {
  const _DarkFieldRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.x1 + 1),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: text.bodySmall?.copyWith(color: t.text.inverseMuted)),
          ),
          Text(value,
              style: AppTypography.tabular(text.titleSmall!).copyWith(color: t.text.inverse)),
        ],
      ),
    );
  }
}

// ── Active sessions + attention ──────────────────────────────────────────────

class _ActiveSessionsCard extends ConsumerWidget {
  const _ActiveSessionsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final async = ref.watch(activeParkingSessionsProvider);

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.cardPadding,
                AppSpacing.x3, AppSpacing.cardPadding, AppSpacing.x3),
            child: Row(
              children: [
                Text('Active sessions', style: text.titleMedium),
                const SizedBox(width: AppSpacing.x2),
                Text(
                  async.valueOrNull == null ? '' : '${async.valueOrNull!.length} on site',
                  style: text.labelSmall?.copyWith(color: t.text.tertiary),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => context.go('/parking'),
                  child: const Text('View all'),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 280,
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text('Could not load sessions',
                    style: text.bodySmall?.copyWith(color: t.text.tertiary)),
              ),
              data: (sessions) {
                if (sessions.isEmpty) {
                  return Center(
                    child: Text('No vehicles on site right now.',
                        style: text.bodySmall?.copyWith(color: t.text.tertiary)),
                  );
                }
                final rows = sessions.take(6).toList();
                return AppDataTable(
                  columns: const [
                    DataColumn(label: Text('Plate')),
                    DataColumn(label: Text('Slot')),
                    DataColumn(label: Text('Entered')),
                    DataColumn(label: Text('Type')),
                  ],
                  rows: [
                    for (final s in rows)
                      DataRow(cells: [
                        DataCell(AppPrimaryCell(
                          title: s.plateNumber ?? '—',
                          subtitle: s.userName,
                        )),
                        DataCell(Text(s.slotCode ?? '—')),
                        DataCell(Text(_timeLabel.format(s.entryTime.toLocal()))),
                        DataCell(StatusPill.of(
                          s.isVisitor ? 'Visitor' : 'Resident',
                          intent: s.isVisitor ? StatusIntent.accent : StatusIntent.info,
                          dense: true,
                        )),
                      ]),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AttentionCard extends ConsumerWidget {
  const _AttentionCard({required this.summary});

  final ReportsSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingRegistrationsProvider).valueOrNull?.length;

    final items = <_AttentionRow>[
      _AttentionRow(
        icon: Icons.pending_actions_outlined,
        label: 'Registrations awaiting review',
        description: 'Review submitted documents and approve or reject accounts.',
        count: pending,
        intent: (pending ?? 0) > 0 ? StatusIntent.warning : null,
        route: '/pending',
      ),
      _AttentionRow(
        icon: Icons.report_outlined,
        label: 'Incidents still open',
        description: 'Review reported incidents and decide violation appeals.',
        count: summary.openIncidents,
        intent: summary.openIncidents > 0 ? StatusIntent.danger : null,
        route: '/incidents',
      ),
      _AttentionRow(
        icon: Icons.payments_outlined,
        label: 'Payments outstanding',
        description: 'Track transactions, collected fees and outstanding balances.',
        valueOverride: _money.format(summary.revenuePending),
        intent: summary.revenuePending > 0 ? StatusIntent.info : null,
        route: '/payments',
      ),
    ];

    final open = items.where((i) => i.intent != null).length;

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.cardPadding,
                AppSpacing.x3, AppSpacing.cardPadding, AppSpacing.x3),
            child: Row(
              children: [
                Icon(Icons.flag_outlined,
                    size: AppSizes.iconMd,
                    color: context.tokens.text.secondary),
                const SizedBox(width: AppSpacing.x2),
                Expanded(
                  child: Text('Alerts', style: Theme.of(context).textTheme.titleMedium),
                ),
                if (open > 0)
                  StatusPill.of('$open open', intent: StatusIntent.warning, dense: true),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.cardPadding, 0,
                AppSpacing.cardPadding, AppSpacing.cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const SizedBox(height: AppSpacing.x2),
                  items[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One line of queued work, styled as its own small severity card — the same
/// pattern the reference dashboard uses for its Alarms list.
class _AttentionRow extends StatefulWidget {
  const _AttentionRow({
    required this.icon,
    required this.label,
    required this.description,
    required this.route,
    this.count,
    this.valueOverride,
    this.intent,
  });

  final IconData icon;
  final String label;

  /// The destination's own real description — reused rather than invented,
  /// so the row reads like the reference's alarm detail line without
  /// fabricating an event that never happened.
  final String description;
  final String route;
  final int? count;
  final String? valueOverride;
  final StatusIntent? intent;

  @override
  State<_AttentionRow> createState() => _AttentionRowState();
}

class _AttentionRowState extends State<_AttentionRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final colors = widget.intent == null ? null : t.status.of(widget.intent!);
    final accent = colors?.solid ?? t.border.strong;

    final value =
        widget.valueOverride ??
        (widget.count == null ? '—' : '${widget.count}');

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => context.go(widget.route),
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.standard,
          decoration: BoxDecoration(
            color: _hovered ? t.surface.hover : t.surface.canvas,
            borderRadius: AppRadii.mdAll,
            border: Border.all(color: t.border.subtle),
          ),
          padding: const EdgeInsets.all(AppSpacing.x3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: AppRadii.smAll,
                ),
              ),
              const SizedBox(width: AppSpacing.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.label, style: text.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      widget.description,
                      style: text.bodySmall?.copyWith(color: t.text.secondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.x3),
              Text(
                value,
                style: AppTypography.tabular(
                  text.titleMedium!,
                ).copyWith(color: colors?.fg ?? t.text.tertiary),
              ),
              const SizedBox(width: AppSpacing.x1),
              Icon(
                Icons.chevron_right,
                size: AppSizes.iconMd,
                color: _hovered ? t.text.secondary : t.text.tertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Layout helpers ───────────────────────────────────────────────────────────

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
              Text(
                caption,
                style: text.labelSmall?.copyWith(color: t.text.secondary),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x4),
          child,
        ],
      ),
    );
  }
}

class _TwoUp extends StatelessWidget {
  const _TwoUp({
    required this.left,
    required this.right,
    this.breakpoint = 1000,
    this.leftFlex = 1,
    this.rightFlex = 1,
  });

  final Widget left;
  final Widget right;
  final double breakpoint;
  final int leftFlex;
  final int rightFlex;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < breakpoint) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              left,
              const SizedBox(height: AppSpacing.gutter),
              right,
            ],
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: leftFlex, child: left),
              const SizedBox(width: AppSpacing.gutter),
              Expanded(flex: rightFlex, child: right),
            ],
          ),
        );
      },
    );
  }
}
