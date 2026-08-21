import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/api_error_message.dart';
import '../../../../core/utils/app_flushbar.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_badge.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_state_views.dart';
import '../../../../core/widgets/celebration_dialog.dart';
import '../providers/payments_provider.dart';

class PaymentDetailScreen extends ConsumerStatefulWidget {
  const PaymentDetailScreen({super.key, required this.paymentId});
  final String paymentId;

  @override
  ConsumerState<PaymentDetailScreen> createState() => _PaymentDetailScreenState();
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
      if (mounted) showAppMessage(context, apiErrorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _isPaying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(paymentDetailProvider(widget.paymentId));

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        backgroundColor: AppColors.bgPage,
        elevation: 0,
        title: Text('Payment Detail', style: AppTextStyles.h3),
      ),
      body: SafeArea(
        child: detailAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => AppErrorState(
            title: "Couldn't load this payment",
            onRetry: () => ref.invalidate(paymentDetailProvider(widget.paymentId)),
          ),
          data: (payment) {
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                AppCard(
                  color: AppColors.brandDefault,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Amount Due',
                        style: AppTextStyles.labelBold.copyWith(color: AppColors.textOnBrand),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        Formatters.peso(payment.amountDue),
                        style: AppTextStyles.displayHero.copyWith(
                          color: AppColors.textOnBrand,
                          fontSize: 32,
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
                              size: 16,
                              color: AppColors.textOnBrand,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              payment.dueLabel!,
                              style: AppTextStyles.labelBold.copyWith(
                                color: AppColors.textOnBrand,
                                // Overdue reads at full strength; a deadline
                                // still ahead sits quieter than the amount.
                                fontWeight: payment.isOverdue
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(payment.source, style: AppTextStyles.h3),
                          AppBadge(
                            label: payment.status,
                            tone: payment.isPaid ? AppBadgeTone.success : AppBadgeTone.error,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      if (payment.slotCode != null)
                        _InfoRow(label: 'Slot', value: payment.slotCode!),
                      _InfoRow(
                        label: 'Duration',
                        value: Formatters.duration(
                          Duration(minutes: payment.durationMinutes),
                        ),
                      ),
                      _InfoRow(
                        label: 'Rate',
                        value: '${Formatters.peso(payment.ratePerHourApplied)}/hr',
                      ),
                      _InfoRow(label: 'Created', value: Formatters.date(payment.createdAt)),
                      if (payment.dueAt != null)
                        _InfoRow(label: 'Due by', value: Formatters.date(payment.dueAt!)),
                      if (payment.paidAt != null)
                        _InfoRow(label: 'Paid', value: Formatters.date(payment.paidAt!)),
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
            );
          },
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.bodySmall),
          Text(value, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
