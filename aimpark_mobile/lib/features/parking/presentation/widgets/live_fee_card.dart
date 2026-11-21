import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/utils/formatters.dart';
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
/// It shows one of three things:
/// - inside the first hour, nothing paid: the flat first-hour fee and how much
///   of the hour is left;
/// - paid up: a countdown to when the meter starts again (the end of the first
///   hour, or the end of the 7-minute grace after a payment);
/// - owing: the visit stretch by stretch (first hour, per-minute runs, grace),
///   what is paid, and what is still to pay.
///
/// How it stays live without hammering the server: the reply says when the
/// price next goes up, so the card asks again right then. It also asks at least
/// once a minute (a payment can land at any time) and whenever the app comes
/// back to the front. Timing is measured on the server's clock, so a phone with
/// the wrong time still refreshes at the right moment.
class LiveFeeCard extends ConsumerStatefulWidget {
  const LiveFeeCard({super.key, required this.session});

  /// The open session.
  final ParkingHistoryEntry session;

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

    final header = Row(
      children: [
        Text(
          'FEE SO FAR',
          style: context.text.labelMedium?.copyWith(
            color: t.tertiary.subtleText,
          ),
        ),
        const Spacer(),
        if (fee != null) _LiveTag(stale: _failed),
      ],
    );

    if (fee == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          const SizedBox(height: AppSpacing.xs),
          Text(
            _failed
                ? "Couldn't load the fee right now. You'll see the exact "
                      'amount when you pay.'
                : 'Checking the fee…',
            style: context.text.bodySmall,
          ),
        ],
      );
    }

    final Widget body;
    if (fee.isFree) {
      body = Text('Parking is free right now.', style: context.text.bodySmall);
    } else if (fee.isCovered) {
      body = _covered(context, fee);
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
          const SizedBox(height: AppSpacing.xs),
          body,
          if (fee.paymentProcessing) ...[
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
    final perMinute = Formatters.peso(fee.ratePerHour / 60);
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
          'you pay ${Formatters.peso(fee.ratePerHour)}, no more. After that the '
          'meter counts per minute ($perMinute a minute).',
          style: context.text.bodySmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        _totalRow(context, 'To pay before you exit', fee.owedNow, bold: true),
      ],
    );
  }

  /// Paid up: a countdown to when the meter starts again.
  Widget _covered(BuildContext context, LiveFee fee) {
    final leaveBy = fee.leaveBy!;
    var left = leaveBy.difference(_serverNow);
    if (left.isNegative) left = Duration.zero;
    final mm = left.inMinutes;
    final ss = (left.inSeconds % 60).toString().padLeft(2, '0');
    final inFirstHour = !leaveBy.isAfter(fee.firstHourEndsAt);
    final perMinute = Formatters.peso(fee.ratePerHour / 60);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'LEAVE BY ${Formatters.time(leaveBy).toUpperCase()}',
          style: context.text.labelSmall,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '$mm:$ss left',
          style: AppTypography.tabular(context.text.headlineMedium!),
        ),
        Text(
          inFirstHour
              ? 'Meter is not running. Your first hour is paid until '
                    '${Formatters.time(fee.firstHourEndsAt)}.'
              : 'Paid. The meter is paused so you can leave. Tap your card '
                    'at the gate and it opens.',
          style: context.text.bodySmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          inFirstHour
              ? 'Still inside at ${Formatters.time(leaveBy)}? The meter starts '
                    'at $perMinute a minute.'
              : 'Still inside at ${Formatters.time(leaveBy)}? The meter starts '
                    'again at $perMinute a minute. These 7 minutes stay free.',
          style: context.text.bodySmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final p in fee.payments)
          _totalRow(
            context,
            p.paidAt == null ? 'Paid' : 'Paid ${Formatters.time(p.paidAt!)}',
            p.amount,
          ),
      ],
    );
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
    final range = '${Formatters.time(s.from)} – ${Formatters.time(s.to)}';
    final perMinute = Formatters.peso(fee.ratePerHour / 60);
    final (title, detail) = switch (s.kind) {
      'FirstHour' => ('First hour · flat', range),
      'Grace' => ('Grace · meter paused', '$range · ${s.minutes} min'),
      _ => ('Per minute', '$range · ${s.minutes} min × $perMinute'),
    };
    final paid = fee.paymentFor(s);
    final note = s.isGrace
        ? 'Free'
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
  }) {
    final style = bold ? context.text.titleSmall! : context.text.bodyMedium!;
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
    final rate = '${Formatters.peso(fee.ratePerHour)} an hour';
    if (next == null) return '$rate, counted per minute after the first hour.';
    return '$rate, counted per minute after the first hour. Goes up to '
        '${Formatters.peso(fee.nextTotal ?? fee.totalSoFar)} at '
        '${Formatters.time(next)}.';
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
