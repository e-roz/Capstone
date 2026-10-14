import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../core/utils/ph_time.dart';
import '../models/parking_slot.dart';
import '../models/report.dart';
import '../providers/overview_provider.dart';
import '../providers/parking_provider.dart';
import '../providers/registrations_provider.dart';
import '../providers/site_link_provider.dart';
import '../theme/theme.dart';
import '../widgets/parking/gate_status.dart';
import '../widgets/ui/ui.dart';
import '../models/site_link.dart';

final _money = NumberFormat.currency(symbol: '₱', decimalDigits: 0);
final _clock = DateFormat('h:mm a');
final _dayAndClock = DateFormat('MMM d, h:mm a');

/// The administrator's front door.
///
/// It answers three questions in the order they get asked: what needs me
/// (Needs attention), how are we doing right now (Live bays, who is inside),
/// and what has gone on that I should look at (Recent activity, the period's
/// totals). The sidebar already lists every module, so this does not.
///
/// "Right now" and "history" are kept apart on purpose. The date picker moves
/// the history: the activity feed, the period's totals and the hourly chart.
/// Free bays, who is on site and what is waiting never follow it.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppPage(
      title: 'Overview',
      eyebrow: 'STI BALIUAG · PARKING OPERATIONS',
      subtitle: 'What needs you, how the lot stands, and what to look at.',
      scrollable: true,
      badge: const _GuardPostBadge(),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
          onPressed: () {
            ref.invalidate(overviewSummaryProvider);
            ref.invalidate(overviewHoursProvider);
            ref.invalidate(overviewFeedProvider);
            ref.invalidate(pendingRegistrationsProvider);
            ref.invalidate(activeParkingSessionsProvider);
          },
        ),
        const SizedBox(width: AppSpacing.x2),
        const _PeriodPicker(),
      ],
      body: AsyncView(
        value: ref.watch(overviewSummaryProvider),
        onRetry: () => ref.invalidate(overviewSummaryProvider),
        loading: const _OverviewSkeleton(),
        data: (summary) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _AttentionSection(summary: summary),
            const SizedBox(height: AppSpacing.gutter),
            _TwoUp(
              leftFlex: 4,
              rightFlex: 5,
              left: _LiveBaysCard(summary: summary),
              right: const _ActivityCard(),
            ),
            const SizedBox(height: AppSpacing.gutter),
            _TwoUp(
              leftFlex: 5,
              rightFlex: 4,
              matchHeights: false,
              left: const _ActiveSessionsCard(),
              right: _PeriodCard(summary: summary),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewSkeleton extends StatelessWidget {
  const _OverviewSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SkeletonMetricRow(count: 5, width: 200),
        SizedBox(height: AppSpacing.gutter),
        Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 4, child: SkeletonBlock(height: 280)),
            SizedBox(width: AppSpacing.gutter),
            Expanded(flex: 5, child: SkeletonBlock(height: 280)),
          ],
        ),
        SizedBox(height: AppSpacing.gutter),
        Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 5, child: SkeletonBlock(height: 260)),
            SizedBox(width: AppSpacing.gutter),
            Expanded(flex: 4, child: SkeletonBlock(height: 260)),
          ],
        ),
      ],
    );
  }
}

// ── Header ───────────────────────────────────────────────────────────────────

/// Whether the guard post is talking to the cloud, and when it last did.
///
/// The bays on this page come from the cloud, which only knows what the guard
/// post last sent. Saying "live" over data that stopped changing when the
/// guard post lost its internet would be worse than saying nothing.
class _GuardPostBadge extends ConsumerWidget {
  const _GuardPostBadge();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final link = ref.watch(siteLinkProvider).valueOrNull;
    // The cloud could not say (an older cloud): claim nothing.
    if (link == null) return const SizedBox.shrink();

    if (link.stale) {
      final since = link.staleSince;
      return StatusPill.of(
        since == null
            ? 'Guard post offline'
            : 'Guard post offline · last confirmed ${_clock.format(manila(since))}',
        intent: StatusIntent.warning,
        dense: true,
      );
    }

    final heard = link.lastContact;
    return StatusPill.of(
      heard == null
          ? 'Guard post live'
          : 'Guard post live · synced ${_clock.format(manila(heard))}',
      intent: StatusIntent.success,
      dense: true,
    );
  }
}

/// One control for the whole history side of the page: a few shortcuts, a
/// single day, or any range.
class _PeriodPicker extends ConsumerWidget {
  const _PeriodPicker();

  static final _shortcuts = <(String, OverviewPeriod)>[
    ('Today', OverviewPeriod.today),
    ('Yesterday', const OverviewPeriod(OverviewPreset.yesterday)),
    ('Last 7 days', const OverviewPeriod(OverviewPreset.last7)),
    ('Last 30 days', const OverviewPeriod(OverviewPreset.last30)),
    ('All time', const OverviewPeriod(OverviewPreset.allTime)),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(overviewPeriodProvider);
    void set(OverviewPeriod p) => ref.read(overviewPeriodProvider.notifier).state = p;

    return MenuAnchor(
      menuChildren: [
        for (final (label, p) in _shortcuts)
          MenuItemButton(
            leadingIcon: Icon(
              p == period ? Icons.check : null,
              size: AppSizes.iconSm,
            ),
            onPressed: () => set(p),
            child: Text(label),
          ),
        const Divider(height: 1),
        MenuItemButton(
          leadingIcon: const Icon(Icons.today_outlined, size: AppSizes.iconSm),
          onPressed: () async {
            final day = await _pickDay(context, period);
            if (day != null) {
              set(OverviewPeriod(OverviewPreset.day, from: day, to: day));
            }
          },
          child: const Text('Pick a day…'),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.date_range_outlined, size: AppSizes.iconSm),
          onPressed: () async {
            final range = await _pickRange(context, period);
            if (range != null) {
              set(OverviewPeriod(OverviewPreset.range,
                  from: range.start, to: range.end));
            }
          },
          child: const Text('Custom range…'),
        ),
      ],
      builder: (context, controller, _) => OutlinedButton.icon(
        icon: const Icon(Icons.calendar_today_outlined, size: AppSizes.iconSm),
        label: Text(period.label),
        onPressed: () => controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }

  static DateTime get _today {
    final m = manilaNow();
    return DateTime(m.year, m.month, m.day);
  }

  static Future<DateTime?> _pickDay(BuildContext context, OverviewPeriod current) {
    final today = _today;
    final shown = current.days?.from ?? today;
    return showDatePicker(
      context: context,
      initialDate: shown.isAfter(today) ? today : shown,
      firstDate: DateTime(today.year - 5),
      // A day that has not happened has nothing in it.
      lastDate: today,
    );
  }

  static Future<DateTimeRange?> _pickRange(BuildContext context, OverviewPeriod current) {
    final today = _today;
    final d = current.days;
    return showDateRangePicker(
      context: context,
      firstDate: DateTime(today.year - 5),
      lastDate: today,
      initialDateRange: d == null ? null : DateTimeRange(start: d.from, end: d.to),
    );
  }
}

// ── Needs attention ──────────────────────────────────────────────────────────

class _AttentionSection extends ConsumerWidget {
  const _AttentionSection({required this.summary});

  final ReportsSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final pending = ref.watch(pendingRegistrationsProvider).valueOrNull?.length;

    final tiles = <_AttentionTile>[
      _AttentionTile(
        label: 'Registrations to review',
        value: pending == null ? '—' : '$pending',
        intent: (pending ?? 0) > 0 ? StatusIntent.warning : null,
        route: '/pending',
      ),
      _AttentionTile(
        label: 'Open incidents',
        value: '${summary.openIncidents}',
        intent: summary.openIncidents > 0 ? StatusIntent.danger : null,
        route: '/incidents',
      ),
      _AttentionTile(
        label: 'Unpaid fees, total',
        value: _money.format(summary.feesPending),
        intent: summary.feesPending > 0 ? StatusIntent.info : null,
        route: '/payments',
      ),
      _AttentionTile(
        label: 'Unpaid fines, total',
        value: _money.format(summary.finesPending),
        intent: summary.finesPending > 0 ? StatusIntent.info : null,
        route: '/payments',
      ),
      _AttentionTile(
        label: 'Serious denials today',
        value: '${summary.seriousDenialsToday}',
        hint: 'Unknown card or plate mismatch',
        intent: summary.seriousDenialsToday > 0 ? StatusIntent.danger : null,
        route: '/gate-taps',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('NEEDS ATTENTION',
                style: text.labelSmall?.copyWith(color: t.text.secondary)),
            const Spacer(),
            Text('Live, not affected by the date',
                style: text.labelSmall?.copyWith(color: t.text.tertiary)),
          ],
        ),
        const SizedBox(height: AppSpacing.x2),
        LayoutBuilder(builder: (context, constraints) {
          final columns = constraints.maxWidth > 1100
              ? 5
              : constraints.maxWidth > 760
                  ? 3
                  : 2;
          final width =
              (constraints.maxWidth - AppSpacing.gutter * (columns - 1)) / columns;
          return Wrap(
            spacing: AppSpacing.gutter,
            runSpacing: AppSpacing.gutter,
            children: [for (final tile in tiles) tile.sized(width)],
          );
        }),
      ],
    );
  }
}

class _AttentionTile extends StatelessWidget {
  const _AttentionTile({
    required this.label,
    required this.value,
    required this.route,
    this.hint,
    this.intent,
    this.width,
  });

  final String label;
  final String value;
  final String route;
  final String? hint;

  /// Null when there is nothing to do: the tile stays quiet.
  final StatusIntent? intent;
  final double? width;

  _AttentionTile sized(double w) => _AttentionTile(
        label: label,
        value: value,
        route: route,
        hint: hint,
        intent: intent,
        width: w,
      );

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final colors = intent == null ? null : t.status.of(intent!);

    return AppCard(
      width: width,
      onTap: () => context.go(route),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: colors?.solid ?? t.border.strong,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.x2),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall?.copyWith(color: t.text.secondary),
                ),
              ),
              Icon(Icons.chevron_right,
                  size: AppSizes.iconMd, color: t.text.tertiary),
            ],
          ),
          const SizedBox(height: AppSpacing.x2),
          Text(
            value,
            style: AppTypography.tabular(text.headlineSmall!)
                .copyWith(color: colors?.fg ?? t.text.primary),
          ),
          if (hint != null) ...[
            const SizedBox(height: 2),
            Text(hint!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.labelSmall?.copyWith(color: t.text.tertiary)),
          ],
        ],
      ),
    );
  }
}

// ── Live bays ────────────────────────────────────────────────────────────────

/// Free and occupied bays, one number from the API and the same one the gates
/// use. When the guard post has gone quiet the card says so and shows the
/// figures as last known.
class _LiveBaysCard extends ConsumerWidget {
  const _LiveBaysCard({required this.summary});

  final ReportsSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final link = ref.watch(siteLinkProvider).valueOrNull;
    final stale = link?.stale ?? false;

    final heard = stale ? link?.staleSince : link?.lastContact;
    final fourWheelUsed = summary.usableFourWheel - summary.freeFourWheel;
    final motorcycleUsed = summary.usableMotorcycle - summary.freeMotorcycle;
    final noteParts = [
      if (summary.noSignalSlots > 0) '${summary.noSignalSlots} with no sensor signal',
      if (summary.outOfServiceSlots > 0) '${summary.outOfServiceSlots} out of service',
    ];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Live bays', style: text.titleMedium),
              const Spacer(),
              if (stale)
                StatusPill.of('Last known', intent: StatusIntent.warning, dense: true)
              else if (heard != null)
                Text('Updated ${_clock.format(manila(heard))}',
                    style: text.labelSmall?.copyWith(color: t.text.tertiary)),
            ],
          ),
          const SizedBox(height: AppSpacing.x3),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${summary.availableSlots}',
                  style: AppTypography.tabular(text.displaySmall!)
                      .copyWith(color: stale ? t.text.tertiary : t.text.primary),
                ),
                TextSpan(
                  text: '  free · ${summary.occupiedSlots} occupied',
                  style: text.bodyMedium?.copyWith(color: t.text.secondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.x4),
          if (summary.usableFourWheel > 0)
            _BayBar(
              label: 'Four-wheel',
              free: summary.freeFourWheel,
              used: fourWheelUsed,
              muted: stale,
            ),
          if (summary.usableFourWheel > 0 && summary.usableMotorcycle > 0)
            const SizedBox(height: AppSpacing.x3),
          if (summary.usableMotorcycle > 0)
            _BayBar(
              label: 'Motorcycle',
              free: summary.freeMotorcycle,
              used: motorcycleUsed,
              muted: stale,
            ),
          if (noteParts.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.x3),
            Text(noteParts.join(' · '),
                style: text.labelSmall?.copyWith(color: t.text.tertiary)),
          ],
          if (link != null && link.devices.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.x4),
            Divider(height: 1, color: t.border.subtle),
            const SizedBox(height: AppSpacing.x3),
            for (final gate in const [1, 2]) _GateRow(gate: gate, link: link),
          ],
          if (stale) ...[
            const SizedBox(height: AppSpacing.x3),
            Text(
              'Bays may have changed since. Gate decisions still run on the guard post.',
              style: text.bodySmall?.copyWith(color: t.status.warning.fg),
            ),
          ],
        ],
      ),
    );
  }
}

class _BayBar extends StatelessWidget {
  const _BayBar({
    required this.label,
    required this.free,
    required this.used,
    required this.muted,
  });

  final String label;
  final int free;
  final int used;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final total = free + used;
    final ratio = total == 0 ? 0.0 : used / total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(label, style: text.bodySmall?.copyWith(color: t.text.secondary)),
            const Spacer(),
            Text('$free free · $used occupied',
                style: AppTypography.tabular(text.bodySmall!)
                    .copyWith(color: t.text.secondary)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: AppRadii.smAll,
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 8,
            backgroundColor: t.surface.muted,
            color: muted ? t.text.tertiary : t.chart.series(0),
          ),
        ),
      ],
    );
  }
}

/// "Gate 1   ● Reader  ● Camera", from the device list the guard post relays.
class _GateRow extends StatelessWidget {
  const _GateRow({required this.gate, required this.link});

  final int gate;
  final SiteLink link;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final status = GateStatus.fromRelayed(gate, link.devices);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.x1),
      child: Row(
        children: [
          Text('Gate $gate',
              style: text.bodySmall?.copyWith(color: t.text.secondary)),
          const Spacer(),
          _DeviceDot(label: 'Reader', ok: status.reader),
          const SizedBox(width: AppSpacing.x3),
          _DeviceDot(label: 'Camera', ok: status.camera),
        ],
      ),
    );
  }
}

class _DeviceDot extends StatelessWidget {
  const _DeviceDot({required this.label, required this.ok});

  final String label;

  /// Null when nothing is known: grey, never red.
  final bool? ok;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final color = switch (ok) {
      true => t.status.success.solid,
      false => t.status.danger.solid,
      null => t.border.strong,
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: text.labelSmall?.copyWith(color: t.text.secondary)),
      ],
    );
  }
}

// ── Recent activity ──────────────────────────────────────────────────────────

class _ActivityCard extends ConsumerWidget {
  const _ActivityCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final period = ref.watch(overviewPeriodProvider);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Recent activity', style: text.titleMedium),
              const SizedBox(width: AppSpacing.x2),
              Text(period.label,
                  style: text.labelSmall?.copyWith(color: t.text.tertiary)),
              const Spacer(),
              TextButton(
                onPressed: () => context.go('/gate-taps'),
                child: const Text('Show all taps'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x2),
          AsyncView(
            value: ref.watch(overviewFeedProvider),
            onRetry: () => ref.invalidate(overviewFeedProvider),
            loading: const SkeletonList(count: 4),
            isEmpty: (items) => items.isEmpty,
            empty: const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.x6),
              child: AppEmptyState(
                icon: Icons.check_circle_outline,
                title: 'Nothing needs a look',
                message:
                    'Serious denials, new incidents and new violations in this period show up here.',
              ),
            ),
            data: (items) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [for (final item in items) _FeedRow(item: item)],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedRow extends StatelessWidget {
  const _FeedRow({required this.item});

  final FeedItem item;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final color = switch (item.kind) {
      FeedKind.denial => t.status.danger.solid,
      FeedKind.incident || FeedKind.violation => t.status.warning.solid,
    };

    final at = manila(item.at);
    final now = manilaNow();
    final sameDay =
        at.year == now.year && at.month == now.month && at.day == now.day;

    return InkWell(
      onTap: () => context.go(item.route),
      borderRadius: AppRadii.smAll,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.x3),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: t.border.subtle)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(top: 6),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: AppSpacing.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: text.bodyMedium),
                  Text(item.detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall?.copyWith(color: t.text.secondary)),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.x3),
            Text(
              sameDay ? _clock.format(at) : _dayAndClock.format(at),
              style: text.labelSmall?.copyWith(color: t.text.tertiary),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Who is on site ───────────────────────────────────────────────────────────

class _ActiveSessionsCard extends ConsumerWidget {
  const _ActiveSessionsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final async = ref.watch(activeParkingSessionsProvider);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Active sessions', style: text.titleMedium),
              const SizedBox(width: AppSpacing.x2),
              if (async.valueOrNull != null)
                Text('${async.valueOrNull!.length} on site',
                    style: text.labelSmall?.copyWith(color: t.text.tertiary)),
              const Spacer(),
              TextButton(
                onPressed: () => context.go('/parking-logs'),
                child: const Text('View all'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x2),
          AsyncView(
            value: async,
            onRetry: () => ref.invalidate(activeParkingSessionsProvider),
            loading: const SkeletonList(count: 4),
            isEmpty: (sessions) => sessions.isEmpty,
            empty: const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.x6),
              child: AppEmptyState(
                icon: Icons.local_parking_outlined,
                title: 'No vehicles on site',
                message: 'Vehicles that are inside right now appear here.',
              ),
            ),
            data: (sessions) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final s in sessions.take(6)) _SessionRow(session: s),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.session});

  final ActiveParkingSession session;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.x3),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: t.border.subtle)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(session.plateNumber ?? '—', style: text.bodyMedium),
                Text(session.userName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall?.copyWith(color: t.text.secondary)),
              ],
            ),
          ),
          Text('Entered ${_clock.format(manila(session.entryTime))}',
              style: text.labelSmall?.copyWith(color: t.text.tertiary)),
          const SizedBox(width: AppSpacing.x3),
          StatusPill.of(
            session.isVisitor ? 'Visitor' : 'Resident',
            intent: session.isVisitor ? StatusIntent.accent : StatusIntent.info,
            dense: true,
          ),
        ],
      ),
    );
  }
}

// ── The period ───────────────────────────────────────────────────────────────

/// The period's totals and when entries happen. This is the one place the
/// date picker's choice shows as numbers.
class _PeriodCard extends ConsumerWidget {
  const _PeriodCard({required this.summary});

  final ReportsSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final period = ref.watch(overviewPeriodProvider);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('This period', style: text.titleMedium),
              const Spacer(),
              Text(period.label,
                  style: text.labelSmall?.copyWith(color: t.text.tertiary)),
            ],
          ),
          const SizedBox(height: AppSpacing.x3),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _Stat(label: 'Sessions', value: '${summary.sessionsInPeriod}'),
              ),
              Expanded(
                child: _Stat(
                  label: 'Collected',
                  value: _money.format(summary.revenueCollected),
                  caption:
                      'fees ${_money.format(summary.feesCollected)} · fines ${_money.format(summary.finesCollected)}',
                ),
              ),
              Expanded(
                child: _Stat(
                    label: 'Violations issued', value: '${summary.violationsIssued}'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x4),
          Text('ENTRIES BY HOUR',
              style: text.labelSmall?.copyWith(color: t.text.secondary)),
          const SizedBox(height: AppSpacing.x2),
          AsyncView(
            value: ref.watch(overviewHoursProvider),
            onRetry: () => ref.invalidate(overviewHoursProvider),
            loading: const SkeletonBlock(height: 160),
            data: (points) {
              final byHour = {for (final p in points) p.hour: p.count};
              return AppBarChart(
                height: 160,
                data: [
                  for (var h = 0; h < 24; h++)
                    AppChartDatum(
                      label: _hourLabel(h),
                      value: (byHour[h] ?? 0).toDouble(),
                      tooltip:
                          '${_hourFull(h)} · ${byHour[h] ?? 0} ${(byHour[h] ?? 0) == 1 ? 'entry' : 'entries'}',
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  static String _hourLabel(int h) => h == 0
      ? '12a'
      : h < 12
          ? '${h}a'
          : h == 12
              ? '12p'
              : '${h - 12}p';

  static String _hourFull(int h) =>
      DateFormat('h:00 a').format(DateTime(2000, 1, 1, h));
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.caption});

  final String label;
  final String value;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: text.bodySmall?.copyWith(color: t.text.secondary)),
        const SizedBox(height: 2),
        Text(value, style: AppTypography.tabular(text.titleLarge!)),
        if (caption != null)
          Text(caption!,
              style: text.labelSmall?.copyWith(color: t.text.tertiary)),
      ],
    );
  }
}

// ── Layout ───────────────────────────────────────────────────────────────────

class _TwoUp extends StatelessWidget {
  const _TwoUp({
    required this.left,
    required this.right,
    this.leftFlex = 1,
    this.rightFlex = 1,
    this.matchHeights = true,
  });

  final Widget left;
  final Widget right;
  final int leftFlex;
  final int rightFlex;

  /// Stretch both cards to the taller one. Not for a row holding a table or a
  /// chart: both measure themselves with a LayoutBuilder, which cannot answer
  /// the intrinsic-height question this needs, and the row fails to draw.
  final bool matchHeights;

  static const _breakpoint = 1000.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < _breakpoint) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              left,
              const SizedBox(height: AppSpacing.gutter),
              right,
            ],
          );
        }
        final row = Row(
          crossAxisAlignment:
              matchHeights ? CrossAxisAlignment.stretch : CrossAxisAlignment.start,
          children: [
            Expanded(flex: leftFlex, child: left),
            const SizedBox(width: AppSpacing.gutter),
            Expanded(flex: rightFlex, child: right),
          ],
        );
        return matchHeights ? IntrinsicHeight(child: row) : row;
      },
    );
  }
}
