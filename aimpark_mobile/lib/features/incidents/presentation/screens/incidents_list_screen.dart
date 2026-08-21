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
          error: (error, _) => AppErrorState(
            title: "Couldn't load your reports",
            onRetry: () => ref.read(incidentsNotifierProvider.notifier).refresh(),
          ),
          data: (result) {
            if (result.incidents.isEmpty) {
              return AppEmptyState(
                icon: Icons.report_rounded,
                title: 'No reports yet',
                message: 'Spot something wrong in the parking area? Let us know.',
                actionLabel: 'Report an Incident',
                onAction: () => context.push('/home/user/incidents/new'),
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
    return AppCard(
      onTap: onTap,
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
                Text(Formatters.date(incident.createdAt), style: AppTextStyles.bodySmall),
              ],
            ),
          ),
          AppBadge(label: incident.status, tone: _tone),
          const SizedBox(width: AppSpacing.xs),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
        ],
      ),
    );
  }
}
