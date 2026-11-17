import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../data/models/live_fee.dart';
import '../../data/models/parking_history_entry.dart';
import '../providers/parking_history_provider.dart';

/// The fee so far for the session the driver is in, kept up to date while they
/// look at it.
///
/// Every figure comes from the server (`GET .../live-fee`), which prices the
/// stay the same way as pay-ahead and the exit gate. The app does no fee maths
/// of its own, so it can never show a number the barrier disagrees with.
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
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _next?.cancel();
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

    return Semantics(
      liveRegion: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          const SizedBox(height: AppSpacing.xs),
          Text(
            fee.isFree ? 'Free' : Formatters.peso(fee.totalSoFar),
            style: AppTypography.tabular(context.text.headlineMedium!),
          ),
          if (!fee.isFree) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              _working(fee),
              style: AppTypography.tabular(context.text.bodyMedium!),
            ),
          ],
          const SizedBox(height: AppSpacing.xs),
          Text(_howItGrows(fee), style: context.text.bodySmall),
          if (fee.alreadyPaid > 0) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              fee.owedNow > 0
                  ? 'Paid ${Formatters.peso(fee.alreadyPaid)} · '
                        '${Formatters.peso(fee.owedNow)} still to pay'
                  : 'Paid ${Formatters.peso(fee.alreadyPaid)} · nothing '
                        'left to pay',
              style: context.text.titleSmall,
            ),
          ],
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

  /// How the time parked became the amount: "1 hr 24 min × ₱20.00/hr =
  /// ₱28.00". Every figure is the server's; the app only lays them out.
  String _working(LiveFee fee) {
    final h = fee.durationMinutes ~/ 60;
    final m = fee.durationMinutes % 60;
    final time = h > 0 ? '$h hr $m min' : '$m min';
    // Just the time × rate. The minimum, when it applies, is explained in
    // the sentence below, not mixed into the sum.
    return '$time × ${Formatters.peso(fee.ratePerHour)}/hr = '
        '${Formatters.peso(fee.meteredSoFar)}';
  }

  /// One sentence on what happens to the amount next, in the server's numbers.
  String _howItGrows(LiveFee fee) {
    final next = fee.nextChangeAt;
    if (fee.isFree || next == null) return 'Parking is free right now.';

    final rate = '${Formatters.peso(fee.ratePerHour)} an hour';
    final at = Formatters.time(next);

    if (fee.minimumFee <= 0) {
      return '$rate, charged by the minute. Every started minute counts.';
    }
    if (fee.totalSoFar <= 0) {
      return 'The ${Formatters.peso(fee.minimumFee)} minimum starts at $at, '
          'then $rate.';
    }
    if (fee.minimumFee > 0 && fee.totalSoFar <= fee.minimumFee) {
      return 'The ${Formatters.peso(fee.minimumFee)} minimum covers you until '
          '$at. After that it is $rate, charged by the minute.';
    }
    return '$rate, charged by the minute. '
        '${Formatters.peso(fee.nextTotal ?? fee.totalSoFar)} at $at.';
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
