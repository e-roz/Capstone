import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/utils/responsive.dart';
import '../providers/auth_provider.dart';

const _navBackground = Color(0xFF1E293B);

/// One definition of the navigation, shared by the rail and the drawer so the
/// two can never drift apart.
class _NavItem {
  const _NavItem(this.icon, this.selectedIcon, this.label, this.route);

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String route;
}

const _navItems = <_NavItem>[
  _NavItem(Icons.pending_actions_outlined, Icons.pending_actions,
      'Pending Registrations', '/pending'),
  _NavItem(Icons.people_outline, Icons.people, 'User Management', '/users'),
  _NavItem(Icons.local_parking_outlined, Icons.local_parking, 'Parking', '/parking'),
  _NavItem(Icons.payments_outlined, Icons.payments, 'Payments', '/payments'),
  _NavItem(Icons.gavel_outlined, Icons.gavel, 'Violations', '/violations'),
  _NavItem(Icons.rule_outlined, Icons.rule, 'Policy Rules', '/policy-rules'),
  _NavItem(Icons.report_outlined, Icons.report, 'Incidents', '/incidents'),
  _NavItem(Icons.notifications_outlined, Icons.notifications, 'Notifications',
      '/notifications'),
  _NavItem(Icons.bar_chart_outlined, Icons.bar_chart, 'Reports', '/reports'),
  _NavItem(Icons.history_outlined, Icons.history, 'Audit Log', '/audit-logs'),
];

class AdminShell extends ConsumerWidget {
  const AdminShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;
    final selected = _selectedIndex(location);

    // On a phone an expanded rail would leave almost nothing for content, so
    // navigation moves behind a hamburger instead.
    if (context.isCompact) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: _navBackground,
          foregroundColor: Colors.white,
          title: Text(_navItems[selected].label,
              style: const TextStyle(fontSize: 16)),
        ),
        drawer: _NavDrawer(selected: selected, onLogout: () => _logout(context, ref)),
        body: child,
      );
    }

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            backgroundColor: _navBackground,
            selectedIconTheme: const IconThemeData(color: Colors.white),
            unselectedIconTheme: const IconThemeData(color: Colors.white54),
            selectedLabelTextStyle:
                const TextStyle(color: Colors.white, fontSize: 12),
            unselectedLabelTextStyle:
                const TextStyle(color: Colors.white54, fontSize: 12),
            // Labels only fit alongside icons on a reasonably wide window.
            extended: !context.isMedium,
            labelType: context.isMedium ? NavigationRailLabelType.none : null,
            leading: _RailHeader(showWordmark: !context.isMedium),
            trailing: _RailFooter(
              showLabel: !context.isMedium,
              onLogout: () => _logout(context, ref),
            ),
            selectedIndex: selected,
            onDestinationSelected: (i) => context.go(_navItems[i].route),
            destinations: [
              for (final item in _navItems)
                NavigationRailDestination(
                  icon: Icon(item.icon),
                  selectedIcon: Icon(item.selectedIcon),
                  label: Text(item.label),
                ),
            ],
          ),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(child: child),
        ],
      ),
    );
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    await ref.read(authNotifierProvider.notifier).logout();
    if (context.mounted) context.go('/login');
  }

  int _selectedIndex(String location) {
    // Longest-prefix first would matter if routes nested; they don't here.
    for (var i = 0; i < _navItems.length; i++) {
      if (location.startsWith(_navItems[i].route)) return i;
    }
    return 0; // default to pending
  }
}

class _RailHeader extends StatelessWidget {
  const _RailHeader({required this.showWordmark});

  final bool showWordmark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(showWordmark ? 16 : 0, 24, showWordmark ? 16 : 0, 32),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.admin_panel_settings, color: Colors.white, size: 28),
          if (showWordmark) ...[
            const SizedBox(width: 8),
            const Text(
              'AimPark\nAdmin',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RailFooter extends StatelessWidget {
  const _RailFooter({required this.showLabel, required this.onLogout});

  final bool showLabel;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: showLabel
          ? TextButton.icon(
              icon: const Icon(Icons.logout, color: Colors.white54),
              label: const Text('Logout', style: TextStyle(color: Colors.white54)),
              onPressed: onLogout,
            )
          // A labelled button doesn't fit in a collapsed rail.
          : IconButton(
              icon: const Icon(Icons.logout, color: Colors.white54),
              tooltip: 'Logout',
              onPressed: onLogout,
            ),
    );
  }
}

class _NavDrawer extends StatelessWidget {
  const _NavDrawer({required this.selected, required this.onLogout});

  final int selected;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: _navBackground,
      child: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 24, 16, 16),
              child: Row(
                children: [
                  Icon(Icons.admin_panel_settings, color: Colors.white, size: 28),
                  SizedBox(width: 8),
                  Text('AimPark Admin',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                ],
              ),
            ),
            const Divider(color: Colors.white24, height: 1),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  for (var i = 0; i < _navItems.length; i++)
                    ListTile(
                      leading: Icon(
                        i == selected ? _navItems[i].selectedIcon : _navItems[i].icon,
                        color: i == selected ? Colors.white : Colors.white54,
                      ),
                      title: Text(
                        _navItems[i].label,
                        style: TextStyle(
                          color: i == selected ? Colors.white : Colors.white70,
                          fontWeight:
                              i == selected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                      selected: i == selected,
                      selectedTileColor: Colors.white10,
                      onTap: () {
                        Navigator.pop(context);
                        context.go(_navItems[i].route);
                      },
                    ),
                ],
              ),
            ),
            const Divider(color: Colors.white24, height: 1),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.white54),
              title: const Text('Logout', style: TextStyle(color: Colors.white54)),
              onTap: () {
                Navigator.pop(context);
                onLogout();
              },
            ),
          ],
        ),
      ),
    );
  }
}
