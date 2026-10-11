import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/utils/app_flushbar.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/widgets.dart';
import '../../data/models/incident.dart';
import '../../domain/incident_stage.dart';
import '../incident_categories.dart';
import '../providers/incidents_provider.dart';
import '../widgets/incident_category_disc.dart';
import '../widgets/incident_progress.dart';
import 'edit_incident_screen.dart';

/// One report: what it is, where it stands, what the parking office said, and the
/// photos.
///
/// Reached from the list, and from the push notification that says a report's
/// status has changed — so the first thing it answers is "what's happening with
/// my report?", which is why the status and what it means sit right under the
/// heading and not in a corner badge.
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

  void _openPhoto(BuildContext context, List<String> urls, int index) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => PhotoViewerScreen(
          urls: urls.map(_resolveUrl).toList(),
          initialIndex: index,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(incidentDetailProvider(incidentId));
    final incident = async.valueOrNull;

    return AppScreen(
      title: 'Incident Report',
      // Pinned, and only while the report can still be changed. After that these
      // buttons would have nothing to do, and the explanation above says why.
      bottomBar: incident != null && incident.canModify
          ? AppBottomBar(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppButton(
                    label: 'Edit report',
                    icon: const Icon(Icons.edit_rounded),
                    onPressed: () => _edit(context, ref, incident),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppButton(
                    label: 'Withdraw report',
                    style: AppButtonStyle.dangerGhost,
                    onPressed: () => _withdraw(context, ref),
                  ),
                ],
              ),
            )
          : null,
      body: AsyncView(
        value: async,
        // Invalidate *and* await the rebuilt future. Without the await the
        // pull-to-refresh spinner snaps back the instant it is released,
        // which reads as the gesture having been ignored.
        onRefresh: () {
          ref.invalidate(incidentDetailProvider(incidentId));
          return ref.read(incidentDetailProvider(incidentId).future);
        },
        errorTitle: "Couldn't load this report",
        data: (incident) => _Report(
          incident: incident,
          onPhoto: (index) => _openPhoto(context, incident.evidenceUrls, index),
          resolveUrl: _resolveUrl,
        ),
      ),
    );
  }
}

class _Report extends StatelessWidget {
  const _Report({
    required this.incident,
    required this.onPhoto,
    required this.resolveUrl,
  });

  final IncidentDetail incident;
  final void Function(int index) onPhoto;
  final String Function(String url) resolveUrl;

  static String _when(DateTime d) => '${Formatters.date(d)} · ${Formatters.time(d)}';

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final stage = incident.stage;
    final intent = stage.intent;
    final c = t.status.of(intent);

    return ListView(
      padding: kScreenListPadding,
      children: [
        // ── Heading: what it is ──────────────────────────────────────────
        Row(
          children: [
            IncidentCategoryDisc(category: incident.category, size: 52),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    incidentCategoryLabel(incident.category),
                    style: context.text.headlineMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Reported ${_when(incident.createdAt)}',
                    style: context.text.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),

        // ── Where it stands ──────────────────────────────────────────────
        AppCard(
          borderColor: c.border,
          edgeColor: c.solid,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // A Wrap, not a Row: at a large text size the badge no longer fits
              // beside the word and drops underneath it instead of running off
              // the card.
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  Text(
                    'STATUS',
                    style: context.text.labelMedium?.copyWith(color: c.fg),
                  ),
                  AppStatusBadge(
                    label: stage.label,
                    intent: intent,
                    showDot: true,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              // A withdrawn report stepped off the path altogether, so it has no
              // tracker to show — only what happened.
              if (stage != IncidentStage.withdrawn) ...[
                IncidentProgress(stage: stage),
                const SizedBox(height: AppSpacing.md),
              ],
              Text(stage.explanation, style: context.text.bodyMedium),
              if (incident.wasUpdated) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Last updated ${_when(incident.updatedAt)}',
                  style: context.text.bodySmall,
                ),
              ],
            ],
          ),
        ),

        // ── What the office said ─────────────────────────────────────────
        if (incident.adminNotes != null &&
            incident.adminNotes!.trim().isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          AppAlertCard(
            intent: StatusIntent.brand,
            icon: Icons.support_agent_rounded,
            eyebrow: 'Note from the parking office',
            message: incident.adminNotes!,
          ),
        ],

        // ── What you reported ────────────────────────────────────────────
        const SizedBox(height: AppSpacing.lg),
        const AppSectionHeader(title: 'What you reported'),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppInfoRow(label: 'Description', value: incident.description),
              if (incident.location != null &&
                  incident.location!.trim().isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                AppInfoRow(label: 'Location', value: incident.location!),
              ],
            ],
          ),
        ),

        // ── Photos ───────────────────────────────────────────────────────
        if (incident.evidenceUrls.isNotEmpty ||
            incident.evidenceUnavailable > 0) ...[
          const SizedBox(height: AppSpacing.lg),
          AppSectionHeader(
            title: 'Photos',
            subtitle: incident.evidenceUrls.isEmpty
                ? null
                : 'Tap a photo to see it full size.',
          ),
          if (incident.evidenceUrls.isNotEmpty)
            AppPhotoThumb.grid(
              urls: [for (final u in incident.evidenceUrls) resolveUrl(u)],
              onTap: onPhoto,
            ),
          if (incident.evidenceUnavailable > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            AppNotice(
              intent: StatusIntent.warning,
              message: incident.evidenceUnavailable == 1
                  ? "1 photo can't be opened right now. It will show again when "
                      'the connection is back.'
                  : "${incident.evidenceUnavailable} photos can't be opened "
                      'right now. They will show again when the connection is '
                      'back.',
            ),
          ],
        ],
      ],
    );
  }
}
