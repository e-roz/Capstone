import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models/parking_slot.dart';
import '../providers/auth_provider.dart';
import '../providers/incidents_provider.dart';
import '../providers/parking_provider.dart';
import '../providers/security_provider.dart';
import '../router/destinations.dart';
import '../theme/theme.dart';
import 'dashboard_screen.dart';
import '../widgets/guard_status_bar.dart';
import '../widgets/live_camera_view.dart';
import '../widgets/live_gate_log.dart';
import '../widgets/open_gate_button.dart';
import '../widgets/ui/ui.dart';

/// What the guard on duty sees when they sign in.
///
/// Deliberately not the administrator's dashboard. That one is built on the
/// Reports endpoints, which the API refuses a Security account — so rendering
/// it for them would produce a screen of identical permission errors. This asks
/// the questions a guard has instead: who just came through the gate, what does
/// the camera see, how full is the lot, who is inside, and is anything waiting
/// for me.
///
/// The live log and camera come from the guard post's site server. Opened from
/// the cloud panel they say so, and the rest of the screen still works.
class SecurityOverviewScreen extends ConsumerWidget {
  const SecurityOverviewScreen({super.key});

  /// Below this the log, camera and inside list stack in one column.
  static const double _twoColumnsFrom = 1100;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final availability = ref.watch(parkingSlotsProvider);
    final sessions = ref.watch(activeParkingSessionsProvider);
    final visitors = ref.watch(visitorsOnSiteCountProvider).valueOrNull;
    final openIncidents = ref.watch(openIncidentCountProvider).valueOrNull;

    final total = availability.valueOrNull?.totalSlots;
    final free = availability.valueOrNull?.availableSlots;
    final inside = sessions.valueOrNull?.length;

    void refreshLot() {
      ref.invalidate(parkingSlotsProvider);
      ref.invalidate(activeParkingSessionsProvider);
      ref.invalidate(visitorsOnSiteCountProvider);
    }

    final log = LiveGateLog(onNewTaps: refreshLot);
    final side = [
      const LiveCameras(),
      const SizedBox(height: AppSpacing.gutter),
      _InsideNow(sessions: sessions),
    ];
    final wide = MediaQuery.sizeOf(context).width >= _twoColumnsFrom;

    return AppPage(
      title: 'Overview',
      subtitle: 'The gates and the lot, live.',
      scrollable: true,
      actions: [
        const GuardStatusBar(),
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
          onPressed: () {
            refreshLot();
            ref.invalidate(openIncidentCountProvider);
          },
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StatStrip(
            stats: [
              _Stat(
                label: 'Free slots',
                value: free == null ? '—' : '$free',
                caption: total == null ? null : 'of $total bays',
                intent: free == 0 ? StatusIntent.danger : StatusIntent.success,
              ),
              _Stat(
                label: 'Vehicles inside',
                value: inside == null ? '—' : '$inside',
              ),
              _Stat(
                label: 'Visitor cards out',
                value: visitors == null ? '—' : '$visitors',
                caption: 'not yet returned',
                intent: (visitors ?? 0) > 0 ? StatusIntent.info : null,
              ),
              _Stat(
                label: 'Open incidents',
                value: openIncidents == null ? '—' : '$openIncidents',
                intent: (openIncidents ?? 0) > 0 ? StatusIntent.warning : null,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.gutter),
          const _ActionBar(),
          const SizedBox(height: AppSpacing.sectionGap),
          if (wide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // The log is what a guard watches, so it gets the room.
                Expanded(flex: 3, child: log),
                const SizedBox(width: AppSpacing.gutter),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: side,
                  ),
                ),
              ],
            )
          else ...[
            log,
            const SizedBox(height: AppSpacing.gutter),
            ...side,
          ],
        ],
      ),
    );
  }
}

class _Stat {
  const _Stat({
    required this.label,
    required this.value,
    this.caption,
    this.intent,
  });

  final String label;
  final String value;
  final String? caption;

  /// Colours the dot; null for a plain count.
  final StatusIntent? intent;
}

/// The lot's four numbers in one full-width card, split by thin lines. Two
/// by two on a narrow screen.
class _StatStrip extends StatelessWidget {
  const _StatStrip({required this.stats});

  final List<_Stat> stats;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    Widget cell(_Stat s) => Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.cardPadding,
        vertical: AppSpacing.x3,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: s.intent == null
                      ? t.status.neutral.solid
                      : t.status.of(s.intent!).solid,
                ),
              ),
              const SizedBox(width: AppSpacing.x2),
              Flexible(
                child: Text(
                  s.label,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelMedium?.copyWith(color: t.text.secondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x1),
          Text.rich(
            TextSpan(
              text: s.value,
              style: text.headlineSmall,
              children: [
                if (s.caption != null)
                  TextSpan(
                    text: '  ${s.caption}',
                    style: text.bodySmall?.copyWith(color: t.text.secondary),
                  ),
              ],
            ),
          ),
        ],
      ),
    );

    final divider = VerticalDivider(width: 1, color: t.border.subtle);

    return AppCard(
      padding: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, box) {
          if (box.maxWidth >= 700) {
            return IntrinsicHeight(
              child: Row(
                children: [
                  for (var i = 0; i < stats.length; i++) ...[
                    if (i > 0) divider,
                    Expanded(child: cell(stats[i])),
                  ],
                ],
              ),
            );
          }
          // Two rows of two.
          return Column(
            children: [
              for (var r = 0; r < stats.length; r += 2) ...[
                if (r > 0) Divider(height: 1, color: t.border.subtle),
                IntrinsicHeight(
                  child: Row(
                    children: [
                      Expanded(child: cell(stats[r])),
                      if (r + 1 < stats.length) ...[
                        divider,
                        Expanded(child: cell(stats[r + 1])),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Open gate is the one filled button: when the system can't let a car
/// through, the guard shouldn't have to hunt for it. The rest are equal,
/// quieter shortcuts.
class _ActionBar extends StatelessWidget {
  const _ActionBar();

  static const _height = 44.0;

  @override
  Widget build(BuildContext context) {
    Widget shortcut(IconData icon, String label, String route) => SizedBox(
      height: _height,
      child: OutlinedButton.icon(
        onPressed: () => context.go(route),
        icon: Icon(icon, size: 18),
        label: Text(label, overflow: TextOverflow.ellipsis),
      ),
    );

    const openGate = SizedBox(height: _height, child: OpenGateButton());
    final shortcuts = [
      shortcut(Icons.badge_outlined, 'Gate check', '/gate'),
      shortcut(
        Icons.person_add_alt_outlined,
        'Issue visitor card',
        '/visitors',
      ),
      shortcut(Icons.report_outlined, 'Report incident', '/incidents'),
    ];

    return LayoutBuilder(
      builder: (context, box) {
        if (box.maxWidth < 700) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              openGate,
              const SizedBox(height: AppSpacing.controlGap),
              Wrap(
                spacing: AppSpacing.controlGap,
                runSpacing: AppSpacing.controlGap,
                children: shortcuts,
              ),
            ],
          );
        }
        return Row(
          children: [
            const Expanded(flex: 2, child: openGate),
            for (final s in shortcuts) ...[
              const SizedBox(width: AppSpacing.controlGap),
              Expanded(child: s),
            ],
          ],
        );
      },
    );
  }
}

/// Every vehicle with an entry logged and no exit yet.
class _InsideNow extends ConsumerWidget {
  const _InsideNow({required this.sessions});

  final AsyncValue<List<ActiveParkingSession>> sessions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final count = sessions.valueOrNull?.length;

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.cardPadding),
            child: Row(
              children: [
                Icon(
                  Icons.local_parking_outlined,
                  size: 18,
                  color: t.text.secondary,
                ),
                const SizedBox(width: AppSpacing.x2),
                Text(
                  count == null ? 'Inside now' : 'Inside now ($count)',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
          ),
          AsyncView(
            value: sessions,
            onRetry: () => ref.invalidate(activeParkingSessionsProvider),
            loading: const SkeletonList(count: 2),
            isEmpty: (list) => list.isEmpty,
            // A line, not a big empty-state block: it would push the page down.
            empty: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.cardPadding,
                0,
                AppSpacing.cardPadding,
                AppSpacing.cardPadding,
              ),
              child: Text(
                'The lot is empty.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: t.text.secondary),
              ),
            ),
            data: (list) => Column(
              children: [
                for (final session in list)
                  ListTile(
                    dense: true,
                    leading: Icon(
                      session.isVisitor
                          ? Icons.badge_outlined
                          : Icons.person_outline,
                      color: t.text.secondary,
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
