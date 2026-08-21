import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models/report.dart';
import '../providers/registrations_provider.dart';
import '../providers/reports_provider.dart';
import '../router/destinations.dart';
import '../theme/theme.dart';
import '../widgets/ui/ui.dart';

final _money = NumberFormat.currency(symbol: '₱', decimalDigits: 0);
final _moneyExact = NumberFormat.currency(symbol: '₱', decimalDigits: 2);
final _dayLabel = DateFormat('M/d');

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
    return AppPage(
      title: 'Overview',
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
          },
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AsyncView(
            value: ref.watch(reportsSummaryProvider),
            onRetry: () => ref.invalidate(reportsSummaryProvider),
            loading: const SizedBox(
              height: 120,
              child: AppLoadingState(),
            ),
            data: (summary) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _MetricRow(summary: summary),
                const SizedBox(height: AppSpacing.gutter),
                _OccupancyAndAttention(summary: summary),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          const _ModuleShortcuts(),
          const SizedBox(height: AppSpacing.sectionGap),
          _ChartPanel(
            title: 'Revenue collected',
            caption: 'Last 14 days',
            child: AsyncView(
              value: ref.watch(revenueTrendProvider()),
              onRetry: () => ref.invalidate(revenueTrendProvider),
              data: (points) => AppAreaChart(
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
          _TwoUp(
            left: _ChartPanel(
              title: 'Parking sessions',
              caption: 'Last 14 days',
              child: AsyncView(
                value: ref.watch(occupancyTrendProvider()),
                onRetry: () => ref.invalidate(occupancyTrendProvider),
                data: (points) => AppBarChart(
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
            right: _ChartPanel(
              title: 'Peak hours',
              caption: 'Last 30 days',
              child: AsyncView(
                value: ref.watch(peakHoursProvider()),
                onRetry: () => ref.invalidate(peakHoursProvider),
                data: (points) => AppBarChart(
                  seriesIndex: 2,
                  data: [
                    for (final p in points)
                      AppChartDatum(
                        label: '${p.hour}',
                        value: p.count.toDouble(),
                        tooltip:
                            '${p.count} entries around ${_hour(p.hour)}',
                      ),
                  ],
                ),
              ),
            ),
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

// ── Module shortcuts ─────────────────────────────────────────────────────────

/// A tile per module, which is what the capstone document means by the
/// dashboard's job: "see and navigate tools and see different modules".
///
/// The sidebar can already reach all of these, and for a daily user it is the
/// faster route. This grid is for the visitor who does not yet know what the
/// system contains — the tile carries a sentence saying what the module is for,
/// which a 13px rail label cannot.
class _ModuleShortcuts extends StatelessWidget {
  const _ModuleShortcuts();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

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
            // Tiles carry a sentence each, so they need real width — four
            // across only once there is room for ~280px apiece.
            final columns = switch (constraints.maxWidth) {
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
                for (final item in moduleShortcuts)
                  _ModuleTile(item: item, width: width),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ModuleTile extends StatelessWidget {
  const _ModuleTile({required this.item, required this.width});

  final NavItem item;
  final double width;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    return AppCard(
      width: width,
      onTap: () => context.go(item.route),
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
                  color: t.brand.subtle,
                  borderRadius: AppRadii.mdAll,
                ),
                child: Icon(item.icon,
                    size: AppSizes.iconMd, color: t.brand.subtleText),
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
    );
  }
}

// ── Metric row ───────────────────────────────────────────────────────────────

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.summary});

  final ReportsSummary summary;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Four across on a monitor, two on a laptop, one on a phone — sized so
        // the tiles fill the row rather than leaving a ragged gap on the right.
        final columns = constraints.maxWidth > 1000
            ? 4
            : constraints.maxWidth > 560
                ? 2
                : 1;
        final width = (constraints.maxWidth -
                AppSpacing.gutter * (columns - 1)) /
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
              intent: StatusIntent.info,
              caption: '${summary.activeUsers} active accounts',
            ),
            MetricCard(
              width: width,
              label: 'Revenue collected',
              value: _money.format(summary.revenueCollected),
              icon: Icons.payments_outlined,
              intent: StatusIntent.success,
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
              caption: '${summary.violationsIssued} violations issued',
            ),
          ],
        );
      },
    );
  }
}

// ── Occupancy ring + what needs doing ────────────────────────────────────────

class _OccupancyAndAttention extends StatelessWidget {
  const _OccupancyAndAttention({required this.summary});

  final ReportsSummary summary;

  @override
  Widget build(BuildContext context) {
    return _TwoUp(
      breakpoint: 900,
      left: _OccupancyCard(summary: summary),
      right: _AttentionCard(summary: summary),
    );
  }
}

class _OccupancyCard extends StatelessWidget {
  const _OccupancyCard({required this.summary});

  final ReportsSummary summary;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    final total = summary.totalSlots;
    final occupied = summary.occupiedSlots;
    final outOfService = summary.outOfServiceSlots;

    // Measured against usable capacity, not every bay that physically exists.
    // Dividing by the total counted a broken bay as free space, so a lot that
    // was actually full could report 20% occupancy.
    final ratio = summary.occupancyRatio;
    final percent = (ratio * 100).round();

    // Nearly-full is the state worth reacting to, so the ring changes colour
    // before the lot is actually full rather than at the moment it is too late.
    final intent = switch (ratio) {
      >= 0.95 => StatusIntent.danger,
      >= 0.8 => StatusIntent.warning,
      _ => StatusIntent.success,
    };

    return AppSectionCard(
      title: 'Occupancy',
      subtitle: 'Live across both gates',
      icon: Icons.donut_large_outlined,
      child: Row(
        children: [
          AppProgressRing(
            value: ratio,
            intent: intent,
            center: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$percent%',
                  style: AppTypography.tabular(text.displaySmall!),
                ),
                Text(
                  'full',
                  style: text.bodySmall?.copyWith(color: t.text.secondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.x6),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Legend(
                  intent: intent,
                  label: 'Occupied',
                  value: '$occupied',
                ),
                const SizedBox(height: AppSpacing.x3),
                _Legend(
                  intent: StatusIntent.neutral,
                  label: 'Available',
                  value: '${summary.availableSlots}',
                ),
                // Only shown when there is something to show. A permanent
                // "Out of service: 0" row is noise on a healthy lot.
                if (outOfService > 0) ...[
                  const SizedBox(height: AppSpacing.x3),
                  _Legend(
                    intent: StatusIntent.danger,
                    label: 'Out of service',
                    value: '$outOfService',
                  ),
                ],
                const Divider(height: AppSpacing.x6),
                Text(
                  outOfService > 0
                      ? '${summary.usableSlots} usable of $total total'
                      : '$total slots total',
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

class _Legend extends StatelessWidget {
  const _Legend({
    required this.intent,
    required this.label,
    required this.value,
  });

  final StatusIntent intent;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: t.status.of(intent).solid,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: AppSpacing.x3),
        Expanded(
          child: Text(label,
              style: text.bodyMedium?.copyWith(color: t.text.secondary)),
        ),
        Text(value, style: AppTypography.tabular(text.titleMedium!)),
      ],
    );
  }
}

/// The queue of things a human still has to decide, with a way straight to each.
class _AttentionCard extends ConsumerWidget {
  const _AttentionCard({required this.summary});

  final ReportsSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingRegistrationsProvider).valueOrNull?.length;

    final items = <Widget>[
      _AttentionRow(
        icon: Icons.pending_actions_outlined,
        label: 'Registrations awaiting review',
        count: pending,
        intent: (pending ?? 0) > 0 ? StatusIntent.warning : null,
        route: '/pending',
      ),
      _AttentionRow(
        icon: Icons.report_outlined,
        label: 'Incidents still open',
        count: summary.openIncidents,
        intent:
            summary.openIncidents > 0 ? StatusIntent.danger : null,
        route: '/incidents',
      ),
      _AttentionRow(
        icon: Icons.payments_outlined,
        label: 'Payments outstanding',
        valueOverride: _money.format(summary.revenuePending),
        intent: summary.revenuePending > 0 ? StatusIntent.info : null,
        route: '/payments',
      ),
    ];

    return AppSectionCard(
      title: 'Needs attention',
      subtitle: 'Work that is waiting on a decision',
      icon: Icons.flag_outlined,
      padding: EdgeInsets.zero,
      child: Column(children: items),
    );
  }
}

class _AttentionRow extends StatefulWidget {
  const _AttentionRow({
    required this.icon,
    required this.label,
    required this.route,
    this.count,
    this.valueOverride,
    this.intent,
  });

  final IconData icon;
  final String label;
  final String route;

  /// Null while the count is still loading.
  final int? count;

  /// Used instead of [count] when the figure is not a count — money, a rate.
  final String? valueOverride;

  /// Null means "nothing to do here", which renders muted rather than coloured.
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

    final value = widget.valueOverride ??
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
          color: _hovered ? t.surface.hover : null,
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.cardPadding, vertical: AppSpacing.x3),
          child: Row(
            children: [
              Icon(
                widget.icon,
                size: AppSizes.iconMd,
                color: colors?.solid ?? t.text.tertiary,
              ),
              // The label sat almost against the icon; a full step of space
              // separates the two so the row reads as icon-then-sentence.
              const SizedBox(width: AppSpacing.x4),
              Expanded(child: Text(widget.label, style: text.bodyMedium)),
              Text(
                value,
                style: AppTypography.tabular(text.titleMedium!).copyWith(
                  color: colors?.fg ?? t.text.tertiary,
                ),
              ),
              const SizedBox(width: AppSpacing.x2),
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

/// A titled panel for a chart. Not [AppSectionCard], because a chart wants its
/// caption on the same line as the title rather than stacked under it.
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

/// Two panels side by side, stacking below [breakpoint].
class _TwoUp extends StatelessWidget {
  const _TwoUp({
    required this.left,
    required this.right,
    this.breakpoint = 1000,
  });

  final Widget left;
  final Widget right;
  final double breakpoint;

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
