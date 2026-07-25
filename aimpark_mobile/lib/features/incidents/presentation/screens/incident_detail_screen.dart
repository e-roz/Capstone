import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_badge.dart';
import '../../../../core/widgets/app_card.dart';
import '../providers/incidents_provider.dart';

class IncidentDetailScreen extends ConsumerWidget {
  const IncidentDetailScreen({super.key, required this.incidentId});
  final String incidentId;

  String _resolveUrl(String url) {
    return url.startsWith('http') ? url : '${ApiConstants.baseUrl}$url';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(incidentDetailProvider(incidentId));

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        backgroundColor: AppColors.bgPage,
        elevation: 0,
        title: Text('Incident Report', style: AppTextStyles.h3),
      ),
      body: SafeArea(
        child: detailAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: TextButton(
              onPressed: () => ref.invalidate(incidentDetailProvider(incidentId)),
              child: const Text('Retry'),
            ),
          ),
          data: (incident) {
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: Text(incident.category, style: AppTextStyles.h3)),
                          AppBadge(label: incident.status),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(incident.description, style: AppTextStyles.bodyMedium),
                      if (incident.location != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            const Icon(Icons.location_on_rounded,
                                size: 16, color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Text(incident.location!, style: AppTextStyles.bodySmall),
                          ],
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        'Reported ${incident.createdAt.month}/${incident.createdAt.day}/${incident.createdAt.year}',
                        style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                if (incident.evidenceUrls.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text('Evidence', style: AppTextStyles.h3),
                  const SizedBox(height: AppSpacing.sm),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: incident.evidenceUrls.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: AppSpacing.sm,
                      mainAxisSpacing: AppSpacing.sm,
                    ),
                    itemBuilder: (context, index) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        child: Image.network(
                          _resolveUrl(incident.evidenceUrls[index]),
                          fit: BoxFit.cover,
                        ),
                      );
                    },
                  ),
                ],
                if (incident.adminNotes != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text('Admin Notes', style: AppTextStyles.h3),
                  const SizedBox(height: AppSpacing.sm),
                  AppCard(child: Text(incident.adminNotes!, style: AppTextStyles.bodyMedium)),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
