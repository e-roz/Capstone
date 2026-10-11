import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/widgets.dart';
import '../../data/models/incident.dart';
import '../incident_categories.dart';
import '../providers/incidents_provider.dart';
import '../widgets/incident_category_disc.dart';

/// "My Incident Reports": every report the user has filed, with where each stands.
///
/// Split into **Active** — submitted, or being looked at — and **Closed** —
/// resolved, dismissed or withdrawn. The first group is the one a person opens
/// this screen to check, and with a long history it would otherwise be buried
/// among reports that are long finished.
class IncidentsListScreen extends ConsumerWidget {
  const IncidentsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> refresh() =>
        ref.read(incidentsNotifierProvider.notifier).refresh();

    final async = ref.watch(incidentsNotifierProvider);

    // Only when there are reports to sit above. With none, the empty state already
    // offers "Report an incident" in the middle of the screen, and a second one
    // pinned underneath it would be two calls to action for one thing.
    final hasReports = async.valueOrNull?.incidents.isNotEmpty ?? false;

    return AppScreen(
      title: 'My Incident Reports',
      // A pinned button rather than a floating one. The floating button was drawn
      // as a circle by the app theme, which cut its "Report" label in half, and
      // it also sat on top of the last row of a long list.
      bottomBar: hasReports
          ? AppBottomBar(
              child: AppButton(
                label: 'Report an incident',
                icon: const Icon(Icons.add_rounded),
                onPressed: () => context.push('/home/user/incidents/new'),
              ),
            )
          : null,
      body: AsyncView(
        value: async,
        onRefresh: refresh,
        errorTitle: "Couldn't load your reports",
        loading: const Padding(
          padding: kScreenListPadding,
          child: AppRowSkeleton(),
        ),
        isEmpty: (result) => result.incidents.isEmpty,
        empty: AppEmptyState(
          icon: Icons.flag_rounded,
          title: 'No reports yet',
          message: 'Spot something wrong in the parking area? Let us know.',
          actionLabel: 'Report an incident',
          onAction: () => context.push('/home/user/incidents/new'),
        ),
        data: (result) {
          // Newest first within each group.
          final sorted = [...result.incidents]
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          final active = sorted.where((i) => i.stage.isActive).toList();
          final closed = sorted.where((i) => !i.stage.isActive).toList();

          return ListView(
            padding: kScreenListPadding,
            children: [
              if (active.isNotEmpty) ...[
                AppSectionHeader(title: 'Active · ${active.length}'),
                _Group(incidents: active),
              ],
              if (closed.isNotEmpty) ...[
                if (active.isNotEmpty) const SizedBox(height: AppSpacing.lg),
                AppSectionHeader(title: 'Closed · ${closed.length}'),
                _Group(incidents: closed),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.incidents});

  final List<IncidentSummary> incidents;

  @override
  Widget build(BuildContext context) {
    return AppRowGroup(
      children: [
        for (final incident in incidents)
          _IncidentRow(
            incident: incident,
            onTap: () =>
                context.push('/home/user/incidents/${incident.incidentId}'),
          ),
      ],
    );
  }
}

class _IncidentRow extends StatelessWidget {
  const _IncidentRow({required this.incident, required this.onTap});

  final IncidentSummary incident;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final stage = incident.stage;
    final preview = incident.descriptionPreview?.trim();

    return AppListRow(
      leading: IncidentCategoryDisc(category: incident.category),
      title: incidentCategoryLabel(incident.category),
      // The first words of what was written, so two reports in the same category
      // are not the same row twice. Absent until the server sends it.
      subtitle: preview == null || preview.isEmpty ? null : preview,
      // The status sits under the name, beside the date, rather than at the far
      // right of the row. It is the first thing someone looks for, and a badge
      // pinned to the end of a row cannot shrink: at a large text size it pushed
      // the whole row off the screen. Here it wraps onto its own line instead.
      note: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          AppStatusBadge(label: stage.label, intent: stage.intent),
          Text(
            '${Formatters.date(incident.createdAt)} · '
            '${Formatters.time(incident.createdAt)}',
            style: context.text.bodySmall,
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}
