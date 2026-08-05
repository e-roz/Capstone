import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/api_error_message.dart';
import '../../../../core/utils/app_flushbar.dart';
import '../../../../core/widgets/app_badge.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../data/models/incident.dart';
import '../providers/incidents_provider.dart';
import 'edit_incident_screen.dart';

class IncidentDetailScreen extends ConsumerWidget {
  const IncidentDetailScreen({super.key, required this.incidentId});
  final String incidentId;

  String _resolveUrl(String url) {
    return url.startsWith('http') ? url : '${ApiConstants.baseUrl}$url';
  }

  Future<void> _edit(
      BuildContext context, WidgetRef ref, IncidentDetail incident) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EditIncidentScreen(incident: incident)),
    );

    if (saved == true) {
      ref.invalidate(incidentDetailProvider(incidentId));
      ref.invalidate(incidentsNotifierProvider);
    }
  }

  Future<void> _withdraw(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Withdraw report?', style: AppTextStyles.h3),
        content: Text(
          'This report will be marked as withdrawn and will no longer be '
          'reviewed. This cannot be undone.',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.errorDefault),
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(incidentsRepositoryProvider).withdraw(incidentId);
      ref.invalidate(incidentDetailProvider(incidentId));
      ref.invalidate(incidentsNotifierProvider);
      if (context.mounted) showAppMessage(context, 'Report withdrawn.');
    } catch (e) {
      if (context.mounted) {
        showAppMessage(context, apiErrorMessage(e), isError: true);
      }
    }
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
                if (incident.canModify) ...[
                  const SizedBox(height: AppSpacing.lg),
                  AppButton(
                    label: 'Edit Report',
                    style: AppButtonStyle.secondary,
                    onPressed: () => _edit(context, ref, incident),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppButton(
                    label: 'Withdraw Report',
                    style: AppButtonStyle.ghost,
                    onPressed: () => _withdraw(context, ref),
                  ),
                ] else ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'This report is being reviewed and can no longer be changed.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
