import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_notice.dart';
import '../../data/models/live_fee.dart';
import '../../data/models/parking_history_entry.dart';
import '../providers/parking_history_provider.dart';

/// The fee for the session the driver is in, kept up to date while they look
/// at it.
///
/// Every figure comes from the server (`GET .../live-fee`), which prices the
/// stay the same way as pay-ahead and the exit gate. The app does no fee maths
/// of its own, so it can never show a number the barrier disagrees with.
///
/// The big clock always shows the time being charged for:
/// - before paying: counting up from entry, with the fee under it;
/// - paid, in the 7-minute grace period: stopped at the moment of payment,
///   with a countdown to the end of the grace period;
/// - still inside after the grace period: counting up again from the moment
///   of payment, with why, and what the extra comes to. The grace period is
///   charged then too.
///
/// How it stays live without hammering the server: the reply says when the
/// price next goes up, so the card asks again right then. It also asks at least
/// once a minute (a payment can land at any time) and whenever the app comes
/// back to the front. Timing is measured on the server's clock, so a phone with
/// the wrong time still refreshes at the right moment.
class LiveFeeCard extends ConsumerStatefulWidget {
  const LiveFeeCard({super.key, required this.session, this.afterClock});

  /// The open session.
  final ParkingHistoryEntry session;

  /// Shown under the clock, above the fee: the driver's bay.
  final Widget? afterClock;

  @override
  ConsumerState<LiveFeeCard> createState() => _LiveFeeCardState();
}

class _LiveFeeCardState extends ConsumerState<LiveFeeCard>
    with WidgetsBindingObserver {
  static const _atMost = Duration(seconds: 60);
  static const _atLeast = Duration(seconds: 5);
  static const _afterError = Duration(seconds: 30);

  LiveFee? _fee;
  bool _failed = false;
  Timer? _next;

  /// Ticks once a second while a countdown is on screen.
  Timer? _tick;

  /// Time since the last reply, to move the countdown on the server's clock.
  final _sinceFetch = Stopwatch();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void didUpdateWidget(LiveFeeCard old) {
    super.didUpdateWidget(old);
    // A new session, or this one was just paid ahead: ask again now rather
    // than at the next tick.
    if (old.session.logId != widget.session.logId ||
        old.session.leaveBy != widget.session.leaveBy) {
      _load();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _load();
    } else if (state == AppLifecycleState.paused) {
      // Nobody is looking; no reason to keep asking.
      _next?.cancel();
      _tick?.cancel();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _next?.cancel();
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    _next?.cancel();
    final logId = widget.session.logId;
    try {
      final fee = await ref.read(parkingRepositoryProvider).liveFee(logId);
      if (!mounted || logId != widget.session.logId) return;
      setState(() {
        _fee = fee;
        _failed = false;
      });
      _sinceFetch
        ..reset()
        ..start();
      _tick?.cancel();
      if (fee.isCovered) {
        _tick = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) setState(() {});
        });
      }
      _schedule(fee.untilNextChange);
    } catch (_) {
      // Keep showing the last figure; it is only a little out of date. The
      // amount to pay is always priced again when the driver pays.
      if (!mounted) return;
      setState(() => _failed = true);
      _schedule(_afterError);
    }
  }

  void _schedule(Duration? wait) {
    // One second past the change, so the server is surely on the new minute.
    var d = wait == null ? _atMost : wait + const Duration(seconds: 1);
    if (d < _atLeast) d = _atLeast;
    if (d > _atMost) d = _atMost;
    _next = Timer(d, _load);
  }

  /// Now, on the server's clock.
  DateTime get _serverNow => _fee!.asOf.add(_sinceFetch.elapsed);

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final fee = _fee;
    final entry = widget.session.entryTime;

    // Which clock to show. Before the fee loads, the plain parked clock.
    final mode = fee == null || fee.isFree
        ? _Mode.counting
        : fee.isCovered
        ? _Mode.paid
        : fee.alreadyPaid > 0 && fee.owedNow > 0
        ? _Mode.extra
        : _Mode.counting;
    final paidAt = fee == null ? null : _lastPaidAt(fee);

    final (label, labelColor) = switch (mode) {
      _Mode.counting => ('YOU ARE PARKED', t.tertiary.subtleText),
      _Mode.paid => ('PAID · GRACE PERIOD', t.status.success.fg),
      _Mode.extra => ('EXTRA TIME', t.status.warning.fg),
    };
    final firstHourPaid =
        mode == _Mode.paid && !fee!.leaveBy!.isAfter(fee.firstHourEndsAt);

    final header = Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: labelColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.xs + 2),
        Text(
          firstHourPaid ? 'PAID · FIRST HOUR' : label,
          style: context.text.labelMedium?.copyWith(color: labelColor),
        ),
        const Spacer(),
        if (fee != null) _LiveTag(stale: _failed),
      ],
    );

    final clock = switch (mode) {
      _Mode.counting => MeterClock(
        from: entry,
        caption: 'Counting since ${Formatters.dayTime(entry)}',
      ),
      _Mode.paid => MeterClock(
        from: entry,
        stoppedAt: paidAt,
        caption: 'Stopped at ${Formatters.time(paidAt!)}, when you paid',
      ),
      _Mode.extra => MeterClock(
        from: paidAt!,
        caption: 'Counting since ${Formatters.time(paidAt)}, when you paid',
      ),
    };

    final Widget body;
    if (fee == null) {
      body = Text(
        _failed
            ? "Couldn't load the fee right now. You'll see the exact "
                  'amount when you pay.'
            : 'Checking the fee…',
        style: context.text.bodySmall,
      );
    } else if (fee.isFree) {
      body = Text('Parking is free right now.', style: context.text.bodySmall);
    } else if (mode == _Mode.paid) {
      body = _covered(context, fee, paidAt!);
    } else if (mode == _Mode.extra) {
      body = _extra(context, fee, paidAt!);
    } else if (fee.alreadyPaid == 0 && fee.meterState == 'FirstHour') {
      body = _firstHour(context, fee);
    } else {
      body = _owing(context, fee);
    }

    return Semantics(
      liveRegion: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          const SizedBox(height: AppSpacing.sm),
          clock,
          if (widget.afterClock != null) ...[
            const SizedBox(height: AppSpacing.sm),
            widget.afterClock!,
          ],
          const SizedBox(height: AppSpacing.md),
          body,
          if (fee?.paymentProcessing ?? false) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Payment in progress. This updates once it goes through.',
              style: context.text.bodySmall?.copyWith(color: t.status.info.fg),
            ),
          ],
        ],
      ),
    );
  }

  /// Inside the first hour, nothing paid yet.
  Widget _firstHour(BuildContext context, LiveFee fee) {
    final t = context.tokens;
    final used = fee.durationMinutes.clamp(0, 60);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('FIRST HOUR · FLAT FEE', style: context.text.labelSmall),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '${Formatters.peso(fee.ratePerHour)} covers '
          '${Formatters.time(fee.entryTime)} – '
          '${Formatters.time(fee.firstHourEndsAt)}',
          style: AppTypography.tabular(context.text.titleMedium!),
        ),
        const SizedBox(height: AppSpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: used / 60,
            minHeight: 8,
            backgroundColor: t.surface.muted,
            color: t.tertiary.primary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            Text('$used min used', style: context.text.bodySmall),
            const Spacer(),
            Text('${60 - used} min left', style: context.text.bodySmall),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Leave any time before ${Formatters.time(fee.firstHourEndsAt)} and '
          'you pay ${Formatters.peso(fee.ratePerHour)}, no more. After that '
          "it's ${_rate(fee)}, counted per minute.",
          style: context.text.bodySmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        _totalRow(context, 'To pay before you exit', fee.owedNow, bold: true),
      ],
    );
  }

  /// When the latest payment landed. The site's copy of a bill paid in the
  /// app can lack the time; then the grace period's start stands in for it.
  static DateTime _lastPaidAt(LiveFee fee) {
    DateTime? latest;
    for (final p in fee.payments) {
      final at = p.paidAt;
      if (at != null && (latest == null || at.isAfter(latest))) latest = at;
    }
    return latest ??
        fee.graceUntil?.subtract(const Duration(minutes: _graceMinutes)) ??
        fee.asOf;
  }

  /// The grace period after each payment, as the server applies it.
  static const _graceMinutes = 7;

  String _rate(LiveFee fee) => '${Formatters.pesoRate(fee.ratePerHour)} an hour';

  /// Paid up: the clock is stopped, and a countdown to the end of the grace
  /// period (or of a first hour paid for in full).
  Widget _covered(BuildContext context, LiveFee fee, DateTime paidAt) {
    final t = context.tokens;
    final leaveBy = fee.leaveBy!;
    var left = leaveBy.difference(_serverNow);
    if (left.isNegative) left = Duration.zero;
    final mm = left.inMinutes;
    final ss = (left.inSeconds % 60).toString().padLeft(2, '0');
    final inFirstHour = !leaveBy.isAfter(fee.firstHourEndsAt);
    final ok = t.status.success;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final p in fee.payments) _paidRow(context, p),
        const SizedBox(height: AppSpacing.sm),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: ok.bg,
            borderRadius: AppRadius.smAll,
            border: Border.all(color: ok.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                inFirstHour ? 'First hour' : 'Grace period',
                style: context.text.labelMedium?.copyWith(color: ok.fg),
              ),
              Text(
                '$mm:$ss left',
                style: AppTypography.tabular(
                  context.text.headlineSmall!,
                ).copyWith(color: ok.fg),
              ),
              Text(
                'Tap your card at the gate before '
                '${Formatters.time(leaveBy)} and you pay nothing more.',
                style: context.text.bodySmall?.copyWith(color: ok.fg),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppNotice(
          intent: StatusIntent.warning,
          message: inFirstHour
              ? 'Still inside after ${Formatters.time(leaveBy)}? The meter '
                    'starts at ${_rate(fee)}, counted per minute.'
              : 'Still inside after ${Formatters.time(leaveBy)}? The grace '
                    'period is charged too, from ${Formatters.time(paidAt)}, '
                    'at ${_rate(fee)}.',
        ),
      ],
    );
  }

  /// Paid once, then stayed past the grace period: the extra, and why.
  Widget _extra(BuildContext context, LiveFee fee, DateTime paidAt) {
    final graceEnded = fee.graceUntil;
    // Minutes since the bills end, by the server's own minute count.
    DateTime? coveredTo;
    for (final p in fee.payments) {
      final to = p.coversTo;
      if (to != null && (coveredTo == null || to.isAfter(coveredTo))) {
        coveredTo = to;
      }
    }
    final minutes = coveredTo == null
        ? (fee.owedNow / (fee.ratePerHour / 60)).round()
        : fee.durationMinutes -
              coveredTo.difference(fee.entryTime).inMinutes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppNotice(
          intent: StatusIntent.warning,
          message: graceEnded == null
              ? "You're still inside after paying, so the meter is running "
                    'again.'
              : 'Your grace period ended at ${Formatters.time(graceEnded)} '
                    "and you're still inside, so the meter is running again. "
                    'The $_graceMinutes grace period minutes are charged too.',
        ),
        const SizedBox(height: AppSpacing.sm),
        _totalRow(context, '$minutes min × ${_rate(fee)}', fee.owedNow),
        _totalRow(context, 'Extra so far', fee.owedNow, bold: true),
        for (final p in fee.payments)
          _totalRow(
            context,
            p.paidAt == null
                ? 'Already paid'
                : 'Already paid at ${Formatters.time(p.paidAt!)}',
            p.amount,
            muted: true,
          ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Inside since ${Formatters.dayTime(fee.entryTime)}',
          style: context.text.bodySmall,
        ),
      ],
    );
  }

  /// "Paid at 12:33 PM · GCash   ₱517.00".
  Widget _paidRow(BuildContext context, FeePayment p) {
    final when = p.paidAt == null ? 'Paid' : 'Paid at ${Formatters.time(p.paidAt!)}';
    final how = p.method == null ? '' : ' · ${p.method}';
    return _totalRow(context, '$when$how', p.amount);
  }

  /// Owing: the visit stretch by stretch, and what is still to pay.
  Widget _owing(BuildContext context, LiveFee fee) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('STILL TO PAY', style: context.text.labelSmall),
        const SizedBox(height: AppSpacing.xs),
        Text(
          Formatters.peso(fee.owedNow),
          style: AppTypography.tabular(context.text.headlineMedium!),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final s in fee.segments) ...[
          _segmentRow(context, fee, s),
          const SizedBox(height: AppSpacing.xs),
        ],
        const Divider(),
        _totalRow(context, 'Total so far', fee.totalSoFar),
        if (fee.alreadyPaid > 0)
          _totalRow(context, 'Already paid', -fee.alreadyPaid),
        _totalRow(context, 'Still to pay', fee.owedNow, bold: true),
        const SizedBox(height: AppSpacing.xs),
        Text(_howItGrows(fee), style: context.text.bodySmall),
      ],
    );
  }

  Widget _segmentRow(BuildContext context, LiveFee fee, FeeSegment s) {
    final t = context.tokens;
    final range = Formatters.timeRange(s.from, s.to);
    final (title, detail) = switch (s.kind) {
      'FirstHour' => ('First hour · flat', range),
      'Grace' => ('Grace period', '$range · ${s.minutes} min'),
      _ => ('Per minute', '$range · ${s.minutes} min × ${_rate(fee)}'),
    };
    final paid = fee.paymentFor(s);
    final note = s.isGrace
        ? 'Meter paused'
        : paid?.paidAt != null
        ? 'Paid ${Formatters.time(paid!.paidAt!)}'
        : 'Not paid';
    final noteColor = s.isGrace
        ? t.text.secondary
        : paid != null
        ? t.status.success.fg
        : t.status.warning.fg;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: context.text.titleSmall),
              Text(detail, style: context.text.bodySmall),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              Formatters.peso(s.amount),
              style: AppTypography.tabular(context.text.titleSmall!),
            ),
            Text(
              note,
              style: context.text.bodySmall?.copyWith(color: noteColor),
            ),
          ],
        ),
      ],
    );
  }

  Widget _totalRow(
    BuildContext context,
    String label,
    double amount, {
    bool bold = false,
    bool muted = false,
  }) {
    var style = bold ? context.text.titleSmall! : context.text.bodyMedium!;
    if (muted) style = style.copyWith(color: context.tokens.text.secondary);
    final value = amount < 0
        ? '− ${Formatters.peso(-amount)}'
        : Formatters.peso(amount);
    return Row(
      children: [
        Text(label, style: style),
        const Spacer(),
        Text(value, style: AppTypography.tabular(style)),
      ],
    );
  }

  /// One sentence on what happens to the amount next, in the server's numbers.
  String _howItGrows(LiveFee fee) {
    final next = fee.nextChangeAt;
    final rate = _rate(fee);
    if (next == null) return '$rate, counted per minute after the first hour.';
    return '$rate, counted per minute after the first hour. Goes up to '
        '${Formatters.peso(fee.nextTotal ?? fee.totalSoFar)} at '
        '${Formatters.time(next)}.';
  }
}

enum _Mode { counting, paid, extra }

/// The big clock on the parked card: counting up from [from], or stopped at
/// [stoppedAt] (then measured from the session's entry, which is [from]).
class MeterClock extends StatefulWidget {
  const MeterClock({
    super.key,
    required this.from,
    required this.caption,
    this.stoppedAt,
  });

  final DateTime from;
  final DateTime? stoppedAt;
  final String caption;

  @override
  State<MeterClock> createState() => _MeterClockState();
}

class _MeterClockState extends State<MeterClock> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(MeterClock old) {
    super.didUpdateWidget(old);
    if ((old.stoppedAt == null) != (widget.stoppedAt == null)) _start();
  }

  void _start() {
    _tick?.cancel();
    _tick = widget.stoppedAt != null
        ? null
        : Timer.periodic(const Duration(seconds: 1), (_) {
            if (mounted) setState(() {});
          });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  /// `0:10:55`, `25:45:15`. Hours unpadded: `00:10:55` reads like a time of
  /// day. A clock running slightly behind the server never shows negative.
  static String _hms(Duration d) {
    if (d.isNegative) d = Duration.zero;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.inHours}:${two(d.inMinutes.remainder(60))}:'
        '${two(d.inSeconds.remainder(60))}';
  }

  @override
  Widget build(BuildContext context) {
    final stopped = widget.stoppedAt;
    final elapsed = (stopped ?? DateTime.now()).difference(widget.from);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label:
              '${stopped == null ? 'Counting' : 'Stopped at'} '
              '${Formatters.duration(elapsed)}',
          excludeSemantics: true,
          child: Row(
            children: [
              Text(
                _hms(elapsed),
                style: AppTypography.tabular(context.text.headlineMedium!),
              ),
              if (stopped != null) ...[
                const SizedBox(width: AppSpacing.xs),
                Icon(
                  Icons.pause_rounded,
                  size: AppSizes.iconMd,
                  color: context.tokens.text.secondary,
                ),
              ],
            ],
          ),
        ),
        Text(widget.caption, style: context.text.bodySmall),
      ],
    );
  }
}

/// "Live" with a dot, or "Not updating" after a failed refresh, so a driver
/// never takes an old figure for a current one.
class _LiveTag extends StatelessWidget {
  const _LiveTag({required this.stale});

  final bool stale;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = stale ? t.text.secondary : t.status.success.solid;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          stale ? 'Not updating' : 'Live',
          style: context.text.labelSmall?.copyWith(color: color),
        ),
      ],
    );
  }
}
