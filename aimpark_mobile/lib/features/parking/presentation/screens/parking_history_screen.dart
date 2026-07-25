import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_badge.dart';
import '../../../../core/widgets/app_card.dart';
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
          error: (error, _) => _ErrorState(
            onRetry: () => ref.read(parkingHistoryNotifierProvider.notifier).refresh(),
          ),
          data: (result) {
            if (result.logs.isEmpty) {
              return const _EmptyState();
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

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes % 60;
    if (hours == 0) return '${minutes}m';
    return '${hours}h ${minutes}m';
  }

  String _formatTime(DateTime t) {
    final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final minute = t.minute.toString().padLeft(2, '0');
    final period = t.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

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
                  log.isOpen
                      ? 'Since ${_formatTime(log.entryTime)} · ${_formatDuration(log.duration)}'
                      : '${_formatTime(log.entryTime)} – ${_formatTime(log.exitTime!)} · ${_formatDuration(log.duration)}',
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

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.local_parking_rounded, size: 48, color: AppColors.textDisabled),
            const SizedBox(height: AppSpacing.md),
            Text('No parking history yet', style: AppTextStyles.h2),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Your entries and exits will show up here.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.errorDefault),
            const SizedBox(height: AppSpacing.md),
            Text("Couldn't load history", style: AppTextStyles.h2),
            const SizedBox(height: AppSpacing.sm),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
