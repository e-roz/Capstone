import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/cash_summary.dart';
import '../models/parking_slot.dart';
import '../providers/exit_payment_provider.dart';
import '../providers/parking_provider.dart';
import '../theme/theme.dart';
import 'ui/ui.dart';

final _peso = NumberFormat.currency(symbol: '₱', decimalDigits: 2);

/// Drivers held at the exit barrier because they owe this session's fee.
///
/// The gate keeps them until the bill is settled: in the app, or in cash here.
/// A guard presses "Received cash" once the money is in hand, and the driver taps
/// their card again to leave. "Let out, still owing" is for the car that must go
/// (a dead phone, a lane that has to clear): the bill stays owed, so the driver
/// cannot come in again until it is paid, and the guard's name and reason are
/// kept on it.
///
/// Shown to guards and to admins; the actions work from either.
class WaitingToLeaveCard extends ConsumerWidget {
  const WaitingToLeaveCard({super.key, this.alwaysShow = false});

  /// A guard keeps the card (and the day's cash total) even when nobody is
  /// waiting; an admin only needs to see it when someone is.
  final bool alwaysShow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final waiting = ref.watch(waitingToLeaveProvider);
    final cash = ref.watch(cashSummaryProvider).valueOrNull;

    return waiting.when(
      // The previous answer stays while the next one loads, so the list does
      // not blink every few seconds.
      skipLoadingOnReload: true,
      loading: () => alwaysShow
          ? const AppSectionCard(
              title: 'Waiting to leave',
              icon: Icons.logout,
              child: SizedBox(height: 40),
            )
          : const SizedBox.shrink(),
      error: (e, _) => alwaysShow
          ? AppSectionCard(
              title: 'Waiting to leave',
              icon: Icons.logout,
              child: Row(
                children: [
                  const Expanded(
                    child: Text("Couldn't check who is waiting at the exit."),
                  ),
                  TextButton(
                    onPressed: () => ref.invalidate(waitingToLeaveProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : const SizedBox.shrink(),
      data: (rows) {
        if (rows.isEmpty && !alwaysShow) return const SizedBox.shrink();

        return AppSectionCard(
          title: 'Waiting to leave',
          subtitle: rows.isEmpty
              ? 'Nobody is held at the exit.'
              : 'Held at the barrier until the fee is paid. Updates every few seconds.',
          icon: Icons.logout,
          actions: [
            if (rows.isNotEmpty)
              StatusPill.of('${rows.length}',
                  intent: StatusIntent.warning, showDot: false, dense: true),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final s in rows) _Row(session: s),
              if (cash != null && (alwaysShow || cash.count > 0)) ...[
                if (rows.isNotEmpty) const Divider(height: AppSpacing.x4),
                _CashLine(cash: cash),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _CashLine extends StatelessWidget {
  const _CashLine({required this.cash});

  final CashSummary cash;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final everyone = cash.total != cash.mineTotal;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Cash today, taken by you',
            style: text.bodySmall?.copyWith(color: t.text.secondary)),
        Text(
          '${_peso.format(cash.mineTotal)} · ${cash.mineCount} '
          '${cash.mineCount == 1 ? 'payment' : 'payments'}'
          '${everyone ? '  (all guards ${_peso.format(cash.total)})' : ''}',
          style: text.bodySmall?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _Row extends ConsumerWidget {
  const _Row({required this.session});

  final ActiveParkingSession session;

  String _waited() {
    final since = session.waitingSince ?? session.entryTime;
    final m = DateTime.now().toUtc().difference(since.toUtc()).inMinutes;
    if (m < 1) return 'just now';
    if (m < 60) return '$m min ago';
    return '${m ~/ 60}h ${m % 60}m ago';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final amount = session.amountDue ?? 0;
    final paying = session.paymentStatus == 'Processing';
    final busy = ref.watch(exitPaymentActionsProvider).isLoading;
    final billId = session.paymentId;

    final where = [
      if (session.plateNumber != null) session.plateNumber!,
      if (session.gate != null) 'Gate ${session.gate}',
      'tapped ${_waited()}',
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.x2),
      child: Wrap(
        spacing: AppSpacing.x3,
        runSpacing: AppSpacing.x2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 200, maxWidth: 320),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(session.userName, style: text.titleSmall),
                Text(where,
                    style: text.bodySmall?.copyWith(color: t.text.secondary)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_peso.format(amount),
                  style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              Text(
                paying ? 'Paying in the app…' : 'Not paid',
                style: text.bodySmall?.copyWith(
                  color: paying ? t.status.warning.fg : t.text.secondary,
                ),
              ),
            ],
          ),
          FilledButton.icon(
            icon: const Icon(Icons.payments_outlined, size: AppSizes.iconSm),
            label: Text('Received cash ${_peso.format(amount)}'),
            onPressed: busy || billId == null
                ? null
                : () => _receiveCash(context, ref, billId, amount),
          ),
          OutlinedButton(
            onPressed: busy || billId == null
                ? null
                : () => _release(context, ref, billId),
            child: const Text('Let out, still owes'),
          ),
        ],
      ),
    );
  }

  void _refresh(WidgetRef ref) {
    ref.invalidate(waitingToLeaveProvider);
    ref.invalidate(cashSummaryProvider);
    ref.invalidate(activeParkingSessionsProvider);
  }

  void _say(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _receiveCash(
      BuildContext context, WidgetRef ref, String billId, double amount) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Received ${_peso.format(amount)} from ${session.userName}?'),
        content: const Text(
          'This records the payment in your name. The driver can then tap their '
          'card again to leave.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Yes, I have the cash')),
        ],
      ),
    );
    if (ok != true) return;

    final msg = await ref.read(exitPaymentActionsProvider.notifier).receiveCash(billId);
    _refresh(ref);
    if (context.mounted && msg != null) _say(context, msg);
  }

  Future<void> _release(BuildContext context, WidgetRef ref, String billId) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController();
        String? error;
        return StatefulBuilder(
          builder: (ctx, setState) => AlertDialog(
            title: Text('Let ${session.userName} out without paying?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'They can tap their card to leave. The ${_peso.format(session.amountDue ?? 0)} '
                  'stays unpaid, so they cannot enter again until it is settled. '
                  'This is logged under your name.',
                ),
                const SizedBox(height: AppSpacing.x3),
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Reason',
                    hintText: 'For example: phone battery dead',
                    errorText: error,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton(
                onPressed: () {
                  final r = ctrl.text.trim();
                  if (r.length < 3) {
                    setState(() => error = 'Say why, in a few words');
                    return;
                  }
                  Navigator.pop(ctx, r);
                },
                child: const Text('Let out'),
              ),
            ],
          ),
        );
      },
    );
    if (reason == null) return;

    final msg = await ref.read(exitPaymentActionsProvider.notifier).release(billId, reason);
    _refresh(ref);
    if (context.mounted && msg != null) _say(context, msg);
  }
}
