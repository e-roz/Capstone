import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_badge.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_state_views.dart';
import '../../data/models/parking_history_entry.dart';
import '../providers/parking_history_provider.dart';

class ParkingHistoryScreen extends ConsumerWidget {
  const ParkingHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(parkingHistoryNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: SafeArea(
        child: historyAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => AppErrorState(
            title: "Couldn't load your history",
            onRetry: () => ref.read(parkingHistoryNotifierProvider.notifier).refresh(),
          ),
          data: (result) {
            if (result.logs.isEmpty) {
              return const AppEmptyState(
                icon: Icons.local_parking_rounded,
                title: 'No parking history yet',
                message: 'Your entries and exits will show up here.',
              );
            }
            return RefreshIndicator(
              onRefresh: () => ref.read(parkingHistoryNotifierProvider.notifier).refresh(),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xl,
                ),
                children: [
                  Text('History', style: AppTextStyles.h2),
                  const SizedBox(height: AppSpacing.lg),
                  for (final log in result.logs) ...[
                    _HistoryTile(log: log),
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

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.log});
  final ParkingHistoryEntry log;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.bgSurfaceAlt,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(
              log.isOpen ? Icons.login_rounded : Icons.logout_rounded,
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
                  log.slotCode ?? 'Unassigned slot',
                  style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  Formatters.sessionRange(log.entryTime, log.exitTime, log.duration),
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
          if (log.isOpen) const AppBadge(label: 'Parked now', tone: AppBadgeTone.success),
        ],
      ),
    );
  }
}
