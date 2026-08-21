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
import '../../data/models/violation.dart';
import '../providers/violations_provider.dart';

class ViolationsListScreen extends ConsumerWidget {
  const ViolationsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final violationsAsync = ref.watch(violationsNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        backgroundColor: AppColors.bgPage,
        elevation: 0,
        title: Text('My Violations', style: AppTextStyles.h3),
      ),
      body: SafeArea(
        child: violationsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => AppErrorState(
            title: "Couldn't load your violations",
            onRetry: () => ref.read(violationsNotifierProvider.notifier).refresh(),
          ),
          data: (result) {
            if (result.violations.isEmpty) {
              return const AppEmptyState(
                icon: Icons.verified_rounded,
                iconColor: AppColors.successDefault,
                title: 'Squeaky clean!',
                message: 'No violations on your record.',
              );
            }
            return RefreshIndicator(
              onRefresh: () => ref.read(violationsNotifierProvider.notifier).refresh(),
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  for (final v in result.violations) ...[
                    _ViolationTile(
                      violation: v,
                      onTap: () => context.push('/home/user/violations/${v.violationId}'),
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

class _ViolationTile extends StatelessWidget {
  const _ViolationTile({required this.violation, required this.onTap});
  final ViolationSummary violation;
  final VoidCallback onTap;

  AppBadgeTone get _tone {
    switch (violation.status.toLowerCase()) {
      case 'resolved':
      case 'dismissed':
        return AppBadgeTone.success;
      case 'appealed':
        return AppBadgeTone.tertiary;
      default:
        return AppBadgeTone.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  violation.policyRuleTitle,
                  style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  '${Formatters.peso(violation.penaltyAmount)} · '
                  '${Formatters.date(violation.createdAt)}',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
          AppBadge(label: violation.status, tone: _tone),
          const SizedBox(width: AppSpacing.xs),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
        ],
      ),
    );
  }
}
