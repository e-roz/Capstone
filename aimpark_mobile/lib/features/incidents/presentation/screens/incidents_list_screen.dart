import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_badge.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../data/models/incident.dart';
import '../providers/incidents_provider.dart';

class IncidentsListScreen extends ConsumerWidget {
  const IncidentsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incidentsAsync = ref.watch(incidentsNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        backgroundColor: AppColors.bgPage,
        elevation: 0,
        title: Text('My Incident Reports', style: AppTextStyles.h3),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/home/user/incidents/new'),
        backgroundColor: AppColors.brandDefault,
        icon: const Icon(Icons.add_rounded, color: AppColors.textOnBrand),
        label: const Text('Report', style: TextStyle(color: AppColors.textOnBrand)),
      ),
      body: SafeArea(
        child: incidentsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: TextButton(
              onPressed: () => ref.read(incidentsNotifierProvider.notifier).refresh(),
              child: const Text('Retry'),
            ),
          ),
          data: (result) {
            if (result.incidents.isEmpty) {
              return _EmptyState(
                onReport: () => context.push('/home/user/incidents/new'),
              );
            }
            return RefreshIndicator(
              onRefresh: () => ref.read(incidentsNotifierProvider.notifier).refresh(),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xxl,
                ),
                children: [
                  for (final incident in result.incidents) ...[
                    _IncidentTile(
                      incident: incident,
                      onTap: () => context.push('/home/user/incidents/${incident.incidentId}'),
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

class _IncidentTile extends StatelessWidget {
  const _IncidentTile({required this.incident, required this.onTap});
  final IncidentSummary incident;
  final VoidCallback onTap;

  AppBadgeTone get _tone {
    switch (incident.status.toLowerCase()) {
      case 'resolved':
        return AppBadgeTone.success;
      case 'reviewing':
        return AppBadgeTone.tertiary;
      default:
        return AppBadgeTone.brand;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AppCard(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    incident.category,
                    style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${incident.createdAt.month}/${incident.createdAt.day}/${incident.createdAt.year}',
                    style: AppTextStyles.bodySmall,
                  ),
                ],
              ),
            ),
            AppBadge(label: incident.status, tone: _tone),
            const SizedBox(width: AppSpacing.xs),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onReport});
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.report_rounded, size: 48, color: AppColors.textDisabled),
            const SizedBox(height: AppSpacing.md),
            Text('No reports yet', style: AppTextStyles.h2),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Spot something wrong in the parking area? Let us know.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(label: 'Report an Incident', onPressed: onReport),
          ],
        ),
      ),
    );
  }
}
