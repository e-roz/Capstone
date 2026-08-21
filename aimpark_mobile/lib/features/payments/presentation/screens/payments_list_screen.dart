import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_badge.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_state_views.dart';
import '../../data/models/payment.dart';
import '../providers/payments_provider.dart';

class PaymentsListScreen extends ConsumerWidget {
  const PaymentsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentsAsync = ref.watch(paymentsNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        backgroundColor: AppColors.bgPage,
        elevation: 0,
        title: Text('My Payments', style: AppTextStyles.h3),
      ),
      body: SafeArea(
        child: paymentsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => AppErrorState(
            title: "Couldn't load your payments",
            onRetry: () => ref.read(paymentsNotifierProvider.notifier).refresh(),
          ),
          data: (result) {
            if (result.payments.isEmpty) {
              return const AppEmptyState(
                icon: Icons.payments_rounded,
                title: 'No payments yet',
                message: 'Parking fees and penalties will show up here.',
              );
            }
            return RefreshIndicator(
              onRefresh: () => ref.read(paymentsNotifierProvider.notifier).refresh(),
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  for (final p in result.payments) ...[
                    _PaymentTile(
                      payment: p,
                      onTap: () => context.push('/home/user/payments/${p.paymentId}'),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({required this.payment, required this.onTap});
  final Payment payment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.bgSurfaceAlt,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(
              payment.source.toLowerCase() == 'violation'
                  ? Icons.gavel_rounded
                  : Icons.local_parking_rounded,
              color: AppColors.textSecondary,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  payment.slotCode ?? payment.source,
                  style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(Formatters.date(payment.createdAt), style: AppTextStyles.bodySmall),
                if (payment.dueLabel != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    payment.dueLabel!,
                    // Overdue is the one thing in this row worth alarming
                    // about; a future deadline stays informational.
                    style: AppTextStyles.labelSmall.copyWith(
                      color: payment.isOverdue
                          ? AppColors.errorPressed
                          : AppColors.textSecondary,
                      fontWeight: payment.isOverdue ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Stacked rather than sat side by side: a four-figure penalty next to
          // an "Unpaid" pill used to squeeze the slot code off a 360dp screen.
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                Formatters.peso(payment.amountDue),
                style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              AppBadge(
                label: payment.status,
                tone: payment.isPaid ? AppBadgeTone.success : AppBadgeTone.error,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
