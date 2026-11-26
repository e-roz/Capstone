import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/widgets.dart';
import '../../data/models/live_fee.dart';
import '../providers/parking_history_provider.dart';

/// One visit, priced by the server exactly as the gate priced it.
final visitFeeProvider = FutureProvider.autoDispose.family<LiveFee, String>(
  (ref, logId) => ref.read(parkingRepositoryProvider).liveFee(logId),
);

/// One visit from entry to exit: what it cost, stretch by stretch (first hour,
/// per-minute runs, the free grace after each payment), and each payment.
///
/// An old visit charged under the earlier rules has bills that do not match
/// the first-hour rule. Then the timeline is hidden and only the bills shown,
/// so the screen never adds up to a total nobody paid.
class VisitDetailsScreen extends ConsumerWidget {
  const VisitDetailsScreen({super.key, required this.logId});

  final String logId;

  void _goBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home/user/parking-history');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppScreen(
      title: 'Visit details',
      onBack: () => _goBack(context),
      body: AsyncView(
        value: ref.watch(visitFeeProvider(logId)),
        onRefresh: () {
          ref.invalidate(visitFeeProvider(logId));
          return ref.read(visitFeeProvider(logId).future);
        },
        errorTitle: "Couldn't load this visit",
        data: (fee) => _VisitBody(fee: fee),
      ),
    );
  }
}

class _VisitBody extends StatelessWidget {
  const _VisitBody({required this.fee});

  final LiveFee fee;

  /// "Thu, Nov 19 · 1:02 PM".
  static String _dateTime(DateTime t) =>
      '${Formatters.date(t.toLocal())} · ${Formatters.time(t)}';

  static String _segmentLabel(FeeSegment s) => switch (s.kind) {
    'FirstHour' => 'First hour · flat',
    'Grace' => 'Grace period',
    _ => 'Per minute · ${s.minutes} min',
  };

  @override
  Widget build(BuildContext context) {
    final end = fee.exitTime ?? fee.asOf;
    final graceMinutes = fee.segments
        .where((s) => s.isGrace)
        .fold<int>(0, (sum, s) => sum + s.minutes);

    return ListView(
      padding: kScreenListPadding,
      children: [
        AppFactsCard(
          title: fee.chargedTotal <= 0
              ? 'Nothing to pay'
              : fee.chargedOwed <= 0
              ? 'Paid in full'
              : 'Still to pay',
          facts: [
            AppFact('Entered', _dateTime(fee.entryTime)),
            if (fee.exitTime != null)
              AppFact('Left', _dateTime(fee.exitTime!))
            else
              const AppFact('Left', 'Still parked'),
            AppFact(
              'Time parked',
              Formatters.duration(end.difference(fee.entryTime)),
            ),
            if (fee.chargedOwed > 0)
              AppFact(
                'Still to pay',
                Formatters.peso(fee.chargedOwed),
                intent: StatusIntent.warning,
              ),
          ],
          total: AppFact(
            'Total for this visit',
            Formatters.peso(fee.chargedTotal),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (fee.breakdownMatchesBills && fee.segments.isNotEmpty)
          AppFactsCard(
            title: 'How it was charged',
            facts: [
              for (final s in fee.segments)
                AppFact(
                  _segmentLabel(s),
                  '${Formatters.timeRange(s.from, s.to)} · '
                  '${s.isGrace ? 'meter paused' : Formatters.peso(s.amount)}',
                ),
              if (graceMinutes > 0)
                AppFact('Grace period (left in time)', '$graceMinutes min'),
            ],
            total: AppFact('Total', Formatters.peso(fee.totalSoFar)),
          )
        else if (!fee.breakdownMatchesBills)
          Text(
            'This visit was charged under the earlier rules. Its payments are '
            'below.',
            style: context.text.bodySmall,
          ),
        const SizedBox(height: AppSpacing.md),
        if (fee.payments.isNotEmpty) ...[
          AppFactsCard(
            title: 'Payments',
            facts: [
              for (final p in fee.payments)
                AppFact(
                  p.paidAt == null ? 'Paid' : 'Paid ${_dateTime(p.paidAt!)}',
                  '${Formatters.peso(p.amount)}'
                  '${p.method == null ? '' : ' · ${p.method}'}',
                  intent: StatusIntent.success,
                ),
            ],
            total: AppFact('Total paid', Formatters.peso(fee.alreadyPaid)),
          ),
          for (final p in fee.payments)
            Align(
              child: AppTextLink(
                label: 'Receipt for ${Formatters.peso(p.amount)}',
                icon: Icons.chevron_right_rounded,
                onTap: () => context.push('/home/user/payments/${p.paymentId}'),
              ),
            ),
        ] else
          Text('No payments on this visit yet.', style: context.text.bodySmall),
      ],
    );
  }
}
