import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';

class AdminShell extends ConsumerWidget {
  const AdminShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;

    return Scaffold(
      body: Row(
        children: [
          // ── Side nav ──────────────────────────────────────────────────────
          NavigationRail(
            backgroundColor: const Color(0xFF1E293B),
            selectedIconTheme:
                const IconThemeData(color: Colors.white),
            unselectedIconTheme:
                const IconThemeData(color: Colors.white54),
            selectedLabelTextStyle:
                const TextStyle(color: Colors.white, fontSize: 12),
            unselectedLabelTextStyle:
                const TextStyle(color: Colors.white54, fontSize: 12),
            extended: true,
            leading: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
              child: Row(
                children: [
                  const Icon(Icons.admin_panel_settings,
                      color: Colors.white, size: 28),
                  const SizedBox(width: 8),
                  Text(
                    'AimPark\nAdmin',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            trailing: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: TextButton.icon(
                icon: const Icon(Icons.logout, color: Colors.white54),
                label: const Text('Logout',
                    style: TextStyle(color: Colors.white54)),
                onPressed: () async {
                  await ref.read(authNotifierProvider.notifier).logout();
                  if (context.mounted) context.go('/login');
                },
              ),
            ),
            selectedIndex: _selectedIndex(location),
            onDestinationSelected: (i) {
              switch (i) {
                case 0:
                  context.go('/pending');
                  break;
                case 1:
                  context.go('/users');
                  break;
                case 2:
                  context.go('/parking');
                  break;
                case 3:
                  context.go('/payments');
                  break;
                case 4:
                  context.go('/violations');
                  break;
                case 5:
                  context.go('/policy-rules');
                  break;
                case 6:
                  context.go('/incidents');
                  break;
                case 7:
                  context.go('/notifications');
                  break;
                case 8:
                  context.go('/reports');
                  break;
                case 9:
                  context.go('/audit-logs');
                  break;
              }
            },
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.pending_actions_outlined),
                selectedIcon: Icon(Icons.pending_actions),
                label: Text('Pending Registrations'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.people_outline),
                selectedIcon: Icon(Icons.people),
                label: Text('User Management'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.local_parking_outlined),
                selectedIcon: Icon(Icons.local_parking),
                label: Text('Parking'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.payments_outlined),
                selectedIcon: Icon(Icons.payments),
                label: Text('Payments'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.gavel_outlined),
                selectedIcon: Icon(Icons.gavel),
                label: Text('Violations'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.rule_outlined),
                selectedIcon: Icon(Icons.rule),
                label: Text('Policy Rules'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.report_outlined),
                selectedIcon: Icon(Icons.report),
                label: Text('Incidents'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.notifications_outlined),
                selectedIcon: Icon(Icons.notifications),
                label: Text('Notifications'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.bar_chart_outlined),
                selectedIcon: Icon(Icons.bar_chart),
                label: Text('Reports'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.history_outlined),
                selectedIcon: Icon(Icons.history),
                label: Text('Audit Log'),
              ),
            ],
          ),
          const VerticalDivider(width: 1, thickness: 1),
          // ── Main content ──────────────────────────────────────────────────
          Expanded(child: child),
        ],
      ),
    );
  }

  int _selectedIndex(String location) {
    if (location.startsWith('/users')) return 1;
    if (location.startsWith('/parking')) return 2;
    if (location.startsWith('/payments')) return 3;
    if (location.startsWith('/violations')) return 4;
    if (location.startsWith('/policy-rules')) return 5;
    if (location.startsWith('/incidents')) return 6;
    if (location.startsWith('/notifications')) return 7;
    if (location.startsWith('/reports')) return 8;
    if (location.startsWith('/audit-logs')) return 9;
    return 0; // default to pending
  }
}
