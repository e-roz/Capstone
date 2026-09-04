import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../providers/auth_provider.dart';
import '../providers/incidents_provider.dart';
import '../providers/parking_provider.dart';
import '../providers/security_provider.dart';
import '../router/destinations.dart';
import '../theme/theme.dart';
import 'dashboard_screen.dart';
import '../widgets/ui/ui.dart';

/// What the guard on duty sees when they sign in.
///
/// Deliberately not the administrator's dashboard. That one is built on the
/// Reports endpoints, which the API refuses a Security account — so rendering
/// it for them would produce a screen of identical permission errors. This asks
/// the three questions a guard has instead: how full is the lot, who is inside,
/// and is anything waiting for me.
class SecurityOverviewScreen extends ConsumerWidget {
  const SecurityOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final availability = ref.watch(parkingSlotsProvider);
    final sessions = ref.watch(activeParkingSessionsProvider);
    final visitors = ref.watch(visitorsOnSiteCountProvider).valueOrNull;
    final openIncidents = ref.watch(openIncidentCountProvider).valueOrNull;

    final total = availability.valueOrNull?.totalSlots;
    final free = availability.valueOrNull?.availableSlots;
    final inside = sessions.valueOrNull?.length;

    return AppPage(
      title: 'Overview',
      subtitle: 'The lot as it stands right now.',
      scrollable: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
          onPressed: () {
            ref.invalidate(parkingSlotsProvider);
            ref.invalidate(activeParkingSessionsProvider);
            ref.invalidate(visitorsOnSiteCountProvider);
            ref.invalidate(openIncidentCountProvider);
          },
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: AppSpacing.gutter,
            runSpacing: AppSpacing.gutter,
            children: [
              MetricCard(
                label: 'Free slots',
                value: free == null ? '—' : '$free',
                caption: total == null ? null : 'of $total bays',
                icon: Icons.local_parking_outlined,
                intent: free == 0 ? StatusIntent.danger : StatusIntent.success,
              ),
              MetricCard(
                label: 'Vehicles inside',
                value: inside == null ? '—' : '$inside',
                icon: Icons.directions_car_outlined,
              ),
              MetricCard(
                label: 'Visitor cards out',
                value: visitors == null ? '—' : '$visitors',
                caption: 'not yet returned',
                icon: Icons.badge_outlined,
                intent:
                    (visitors ?? 0) > 0 ? StatusIntent.info : StatusIntent.neutral,
              ),
              MetricCard(
                label: 'Open incidents',
                value: openIncidents == null ? '—' : '$openIncidents',
                icon: Icons.report_outlined,
                intent: (openIncidents ?? 0) > 0
                    ? StatusIntent.warning
                    : StatusIntent.neutral,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => context.go('/gate'),
                  icon: const Icon(Icons.badge_outlined),
                  label: const Text('Gate check'),
                ),
              ),
              const SizedBox(width: AppSpacing.controlGap),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.go('/visitors'),
                  icon: const Icon(Icons.person_add_alt_outlined),
                  label: const Text('Issue a visitor card'),
                ),
              ),
              const SizedBox(width: AppSpacing.controlGap),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.go('/incidents'),
                  icon: const Icon(Icons.report_outlined),
                  label: const Text('Report an incident'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          Text(
            'Inside right now',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.x1),
          Text(
            'Every vehicle with an entry logged and no exit yet.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: context.tokens.text.secondary),
          ),
          const SizedBox(height: AppSpacing.headingGap),
          AsyncView(
            value: sessions,
            onRetry: () => ref.invalidate(activeParkingSessionsProvider),
            loading: const SkeletonList(count: 4),
            isEmpty: (list) => list.isEmpty,
            empty: const AppEmptyState(
              icon: Icons.local_parking_outlined,
              title: 'The lot is empty',
              message: 'Nothing has been logged in yet today.',
            ),
            data: (list) => AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final session in list)
                    ListTile(
                      leading: Icon(
                        session.isVisitor
                            ? Icons.badge_outlined
                            : Icons.person_outline,
                        color: context.tokens.text.secondary,
                      ),
                      title: Text(session.userName),
                      subtitle: Text(
                        [
                          ?session.plateNumber,
                          ?session.slotCode,
                          'in at ${DateFormat('HH:mm').format(session.entryTime.toLocal())}',
                        ].join(' · '),
                      ),
                      trailing: session.isVisitor
                          ? StatusPill.of(
                              'Visitor',
                              intent: StatusIntent.info,
                              dense: true,
                              showDot: false,
                            )
                          : null,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Picks the overview the signed-in account is entitled to.
///
/// A single widget rather than two routes, so the sidebar, the router guard and
/// the redirect after login can all keep pointing at `/dashboard` without
/// knowing which role is looking.
class RoleOverview extends ConsumerWidget {
  const RoleOverview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(staffRoleProvider) == StaffRole.security
        ? const SecurityOverviewScreen()
        : const DashboardScreen();
  }
}
