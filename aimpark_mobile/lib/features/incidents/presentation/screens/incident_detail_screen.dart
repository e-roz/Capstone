import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/utils/app_flushbar.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/widgets.dart';
import '../../data/models/incident.dart';
import '../providers/incidents_provider.dart';
import 'edit_incident_screen.dart';

class IncidentDetailScreen extends ConsumerWidget {
  const IncidentDetailScreen({super.key, required this.incidentId});

  final String incidentId;

  /// Evidence comes back as a server-relative path on some endpoints and an
  /// absolute URL on others.
  String _resolveUrl(String url) =>
      url.startsWith('http') ? url : '${ApiConstants.baseUrl}$url';

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    IncidentDetail incident,
  ) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EditIncidentScreen(incident: incident)),
    );

    if (saved == true) {
      ref.invalidate(incidentDetailProvider(incidentId));
      ref.invalidate(incidentsNotifierProvider);
    }
  }

  Future<void> _withdraw(BuildContext context, WidgetRef ref) async {
    final confirmed = await confirmAction(
      context,
      title: 'Withdraw report?',
      message: 'This report will be marked as withdrawn and will no longer be '
          'reviewed. This cannot be undone.',
      confirmLabel: 'Withdraw',
      cancelLabel: 'Keep it',
    );
    if (!confirmed || !context.mounted) return;

    try {
      await ref.read(incidentsRepositoryProvider).withdraw(incidentId);
      ref.invalidate(incidentDetailProvider(incidentId));
      ref.invalidate(incidentsNotifierProvider);
      if (context.mounted) showAppMessage(context, 'Report withdrawn.');
    } catch (e) {
      if (context.mounted) {
        showApiError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppScreen(
      title: 'Incident Report',
      body: AsyncView(
        value: ref.watch(incidentDetailProvider(incidentId)),
        // Invalidate *and* await the rebuilt future. Without the await the
        // pull-to-refresh spinner snaps back the instant it is released,
        // which reads as the gesture having been ignored.
        onRefresh: () {
          ref.invalidate(incidentDetailProvider(incidentId));
          return ref.read(incidentDetailProvider(incidentId).future);
        },
        errorTitle: "Couldn't load this report",
        data: (incident) => ListView(
          padding: kScreenListPadding,
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          incident.category,
                          style: context.text.headlineSmall,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      AppStatusBadge(
                        label: incident.status,
                        intent: StatusIntents.incident(incident.status),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(incident.description, style: context.text.bodyMedium),
                  if (incident.location != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_rounded,
                          size: AppSizes.iconSm,
                          color: context.tokens.text.secondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          incident.location!,
                          style: context.text.bodySmall,
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    'Reported ${Formatters.date(incident.createdAt)}',
                    style: context.text.labelSmall,
                  ),
                ],
              ),
            ),
            if (incident.evidenceUrls.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              const AppSectionHeader(title: 'Evidence'),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: incident.evidenceUrls.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: AppSpacing.sm,
                  mainAxisSpacing: AppSpacing.sm,
                ),
                itemBuilder: (context, index) => _EvidenceThumb(
                  url: _resolveUrl(incident.evidenceUrls[index]),
                ),
              ),
            ],
            if (incident.adminNotes != null) ...[
              const SizedBox(height: AppSpacing.lg),
              const AppSectionHeader(title: 'Admin Notes'),
              AppCard(
                child: Text(
                  incident.adminNotes!,
                  style: context.text.bodyMedium,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            if (incident.canModify) ...[
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
            ] else
              Text(
                'This report is being reviewed and can no longer be changed.',
                textAlign: TextAlign.center,
                style: context.text.bodySmall,
              ),
          ],
        ),
      ),
    );
  }
}

/// One evidence photo.
///
/// The grid used to hand the URL straight to [Image.network] with no error
/// branch, so a deleted or unreachable file rendered as Flutter's grey
/// exception box inside the card.
class _EvidenceThumb extends StatelessWidget {
  const _EvidenceThumb({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return ClipRRect(
      borderRadius: AppRadius.smAll,
      child: Image.network(
        url,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : const AppSkeleton.block(height: 120),
        errorBuilder: (_, _, _) => ColoredBox(
          color: t.surface.muted,
          child: Icon(
            Icons.broken_image_rounded,
            color: t.text.secondary,
          ),
        ),
      ),
    );
  }
}
