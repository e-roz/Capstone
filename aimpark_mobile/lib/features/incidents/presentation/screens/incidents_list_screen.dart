import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/widgets.dart';
import '../providers/incidents_provider.dart';

class IncidentsListScreen extends ConsumerWidget {
  const IncidentsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> refresh() =>
        ref.read(incidentsNotifierProvider.notifier).refresh();

    final async = ref.watch(incidentsNotifierProvider);

    // Only when there is a list to float over. With no reports the empty state
    // already offers "Report an Incident" in the middle of the screen, and the
    // button floating in the corner was a second one doing the same thing —
    // two calls to action on an otherwise empty screen.
    final hasReports = async.valueOrNull?.incidents.isNotEmpty ?? false;

    return AppScreen(
      title: 'My Incident Reports',
      floatingActionButton: !hasReports
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.push('/home/user/incidents/new'),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Report'),
            ),
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
          icon: Icons.report_rounded,
          title: 'No reports yet',
          message: 'Spot something wrong in the parking area? Let us know.',
          actionLabel: 'Report an Incident',
          onAction: () => context.push('/home/user/incidents/new'),
        ),
        data: (result) => ListView(
          padding: kScreenListPadding,
          children: [
            for (final incident in result.incidents) ...[
              AppListRow(
                icon: Icons.report_rounded,
                title: incident.category,
                subtitle: Formatters.date(incident.createdAt),
                trailing: AppStatusBadge(
                  label: incident.status,
                  intent: StatusIntents.incident(incident.status),
                ),
                onTap: () => context
                    .push('/home/user/incidents/${incident.incidentId}'),
              ),
              if (incident != result.incidents.last) const AppRowGap(),
            ],
          ],
        ),
      ),
    );
  }
}
