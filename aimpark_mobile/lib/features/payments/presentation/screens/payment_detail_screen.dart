import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/utils/app_flushbar.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/widgets.dart';
import '../../data/models/payment.dart';
import '../providers/payments_provider.dart';

class PaymentDetailScreen extends ConsumerStatefulWidget {
  const PaymentDetailScreen({super.key, required this.paymentId});

  final String paymentId;

  @override
  ConsumerState<PaymentDetailScreen> createState() =>
      _PaymentDetailScreenState();
}

class _PaymentDetailScreenState extends ConsumerState<PaymentDetailScreen> {
  bool _isPaying = false;

  Future<void> _pay() async {
    setState(() => _isPaying = true);
    try {
      await ref.read(paymentsRepositoryProvider).pay(widget.paymentId);
      ref.invalidate(paymentDetailProvider(widget.paymentId));
      if (mounted) {
        await CelebrationDialog.show(
          context,
          title: 'Payment Complete',
          message: 'Thanks for settling up!',
        );
      }
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _isPaying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: 'Payment Detail',
      body: AsyncView(
        value: ref.watch(paymentDetailProvider(widget.paymentId)),
        onRefresh: () {
          ref.invalidate(paymentDetailProvider(widget.paymentId));
          return ref.read(paymentDetailProvider(widget.paymentId).future);
        },
        errorTitle: "Couldn't load this payment",
        data: (payment) => ListView(
          padding: kScreenListPadding,
          children: [
            _AmountCard(payment: payment),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(payment.source, style: context.text.headlineSmall),
                      AppStatusBadge(
                        label: payment.status,
                        intent: StatusIntents.payment(payment.status),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (payment.slotCode != null)
                    AppDetailRow(label: 'Slot', value: payment.slotCode!),
                  AppDetailRow(
                    label: 'Duration',
                    value: Formatters.duration(
                      Duration(minutes: payment.durationMinutes),
                    ),
                  ),
                  AppDetailRow(
                    label: 'Rate',
                    value:
                        '${Formatters.peso(payment.ratePerHourApplied)}/hr',
                  ),
                  AppDetailRow(
                    label: 'Created',
                    value: Formatters.date(payment.createdAt),
                  ),
                  if (payment.dueAt != null)
                    AppDetailRow(
                      label: 'Due by',
                      value: Formatters.date(payment.dueAt!),
                      intent:
                          payment.isOverdue ? StatusIntent.danger : null,
                    ),
                  if (payment.paidAt != null)
                    AppDetailRow(
                      label: 'Paid',
                      value: Formatters.date(payment.paidAt!),
                      intent: StatusIntent.success,
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (!payment.isPaid)
              AppButton(
                label: 'Pay Now',
                isLoading: _isPaying,
                onPressed: _isPaying ? null : _pay,
              ),
          ],
        ),
      ),
    );
  }
}

/// The one number this screen exists to show, on a full-bleed brand card.
class _AmountCard extends StatelessWidget {
  const _AmountCard({required this.payment});

  final Payment payment;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return AppCard(
      color: t.brand.primary,
      borderColor: t.brand.pressed,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Amount Due',
            style: context.text.labelLarge?.copyWith(color: t.brand.onSolid),
          ),
          const SizedBox(height: 4),
          Text(
            Formatters.peso(payment.amountDue),
            style: AppTypography.tabular(
              context.text.displayLarge!.copyWith(color: t.brand.onSolid),
            ),
          ),
          if (payment.dueLabel != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  payment.isOverdue
                      ? Icons.warning_amber_rounded
                      : Icons.schedule_rounded,
                  size: AppSizes.iconSm,
                  color: t.brand.onSolid,
                ),
                const SizedBox(width: 6),
                Text(
                  payment.dueLabel!,
                  style: context.text.labelLarge?.copyWith(
                    // Overdue reads at full strength on the card; a deadline
                    // still ahead sits quieter than the amount above it.
                    color: payment.isOverdue
                        ? t.brand.onSolid
                        : t.text.onDarkMuted,
                    fontWeight:
                        payment.isOverdue ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
