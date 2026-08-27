import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/widgets.dart';
import '../../data/models/payment.dart';
import '../providers/payments_provider.dart';

class PaymentsListScreen extends ConsumerWidget {
  const PaymentsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> refresh() =>
        ref.read(paymentsNotifierProvider.notifier).refresh();

    return AppScreen(
      title: 'My Payments',
      body: AsyncView(
        value: ref.watch(paymentsNotifierProvider),
        onRefresh: refresh,
        errorTitle: "Couldn't load your payments",
        loading: const Padding(
          padding: kScreenListPadding,
          child: AppRowSkeleton(),
        ),
        isEmpty: (result) => result.payments.isEmpty,
        empty: const AppEmptyState(
          icon: Icons.payments_rounded,
          title: 'No payments yet',
          message: 'Parking fees and penalties will show up here.',
        ),
        data: (result) => ListView(
          padding: kScreenListPadding,
          children: [
            for (final p in result.payments) ...[
              _PaymentRow(payment: p),
              if (p != result.payments.last) const AppRowGap(),
            ],
          ],
        ),
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({required this.payment});

  final Payment payment;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final isViolation = payment.source.toLowerCase() == 'violation';

    return AppListRow(
      icon: isViolation ? Icons.gavel_rounded : Icons.local_parking_rounded,
      title: payment.slotCode ?? payment.source,
      subtitle: Formatters.date(payment.createdAt),
      note: payment.dueLabel == null
          ? null
          : Text(
              payment.dueLabel!,
              // Overdue is the one thing in this row worth alarming about; a
              // future deadline stays informational.
              style: context.text.labelSmall?.copyWith(
                color: payment.isOverdue ? t.status.danger.fg : null,
                fontWeight: payment.isOverdue ? FontWeight.w700 : null,
              ),
            ),
      // Stacked rather than sat side by side: a four-figure penalty next to an
      // "Unpaid" pill used to squeeze the slot code off a 360dp screen.
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            Formatters.peso(payment.amountDue),
            style: AppTypography.tabular(context.text.labelLarge!),
          ),
          const SizedBox(height: 4),
          AppStatusBadge(
            label: payment.status,
            intent: StatusIntents.payment(payment.status),
          ),
        ],
      ),
      onTap: () => context.push('/home/user/payments/${payment.paymentId}'),
    );
  }
}
