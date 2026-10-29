import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/utils/app_flushbar.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../payments/presentation/providers/payments_provider.dart';
import '../../data/models/parking_history_entry.dart';
import '../providers/parking_history_provider.dart';

/// Lets a driver who is still parked pay before driving to the gate.
///
/// The gate holds anyone who owes this session's fee, so without this the only
/// way to pay was to drive up to a shut barrier first. Paying here prices the
/// stay up to now; the barrier then opens on a tap for a short while (the
/// server says until when), and a driver who stays longer pays the rest at the
/// gate.
///
/// Draws a "Paid" note instead of the button once the session is paid and the
/// time to leave has not run out.
class PayAheadAction extends ConsumerStatefulWidget {
  const PayAheadAction({super.key, required this.session});

  /// The open session. Never one held at the exit: that has its own card.
  final ParkingHistoryEntry session;

  @override
  ConsumerState<PayAheadAction> createState() => _PayAheadActionState();
}

class _PayAheadActionState extends ConsumerState<PayAheadAction> {
  bool _busy = false;

  Future<void> _payAhead() async {
    setState(() => _busy = true);
    try {
      final result = await ref
          .read(parkingRepositoryProvider)
          .payAhead(widget.session.logId);
      if (!mounted) return;

      final billId = result.paymentId;
      if (billId == null) {
        // Paid already, or a stay that costs nothing: the gate will open.
        ref.invalidate(parkingHistoryNotifierProvider);
        showAppMessage(
          context,
          result.paid && result.leaveBy != null
              ? 'Already paid. Tap your card at the gate by '
                    '${Formatters.time(result.leaveBy!)}.'
              : 'Nothing to pay. Tap your card at the gate to leave.',
        );
        return;
      }

      await context.push('/home/user/payments/$billId');
      // Back from the bill, paid or not: both lists may have moved.
      ref.invalidate(parkingHistoryNotifierProvider);
      ref.invalidate(paymentsNotifierProvider);
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;

    if (session.isPaidToLeave()) {
      return AppNotice(
        intent: StatusIntent.success,
        title: 'Paid',
        message:
            'Tap your card at the gate by ${Formatters.time(session.leaveBy!)} '
            'and the barrier opens. After that, the extra time is charged at '
            'the gate.',
      );
    }

    // Paid once, but the time to leave ran out while still parked.
    final ranOut = session.leaveBy != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          ranOut
              ? 'Your paid time ran out at ${Formatters.time(session.leaveBy!)}. '
                    'Pay the extra time before you go to the gate.'
              : 'Leaving soon? Pay now and the gate opens when you tap your '
                    'card. You can also pay at the gate.',
          style: context.text.bodySmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: ranOut ? 'Pay the extra time' : 'Pay now & leave',
          icon: const Icon(Icons.logout_rounded),
          isLoading: _busy,
          onPressed: _busy ? null : _payAhead,
        ),
      ],
    );
  }
}
