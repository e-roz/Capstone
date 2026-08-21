import 'package:flutter/material.dart';

/// One definition of a destination, shared by the sidebar, the mobile drawer
/// and the dashboard's shortcut grid, so the three can never drift apart.
class NavItem {
  const NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.route,
    required this.description,
    this.moduleLabel,
  });

  final IconData icon;
  final IconData selectedIcon;

  /// What the sidebar calls it — kept short, because the rail is 248px wide.
  final String label;

  final String route;

  /// One line explaining what the module is for. Shown on the dashboard tile,
  /// where a first-time visitor is deciding where to go, and nowhere else.
  final String description;

  /// The name the capstone document uses, when it differs from [label]. The
  /// dashboard shows this so the panel can match each tile to the spec they
  /// are holding, while the sidebar keeps the shorter working name.
  final String? moduleLabel;

  /// The name to show on a dashboard shortcut.
  String get displayLabel => moduleLabel ?? label;
}

/// Destinations grouped by *what the admin is doing*, not by what the API calls
/// them. Eleven flat entries force a re-read of the whole list every time;
/// labelled groups let the eye jump straight to the right third.
class NavGroup {
  const NavGroup(this.label, this.items);

  /// Null for the lead group — Overview sits above the first heading the way a
  /// "Home" entry does, because it belongs to no category.
  final String? label;

  final List<NavItem> items;
}

const navGroups = <NavGroup>[
  NavGroup(null, [
    NavItem(
      icon: Icons.space_dashboard_outlined,
      selectedIcon: Icons.space_dashboard,
      label: 'Overview',
      route: '/dashboard',
      description: 'System status at a glance.',
    ),
  ]),
  NavGroup('Operations', [
    NavItem(
      icon: Icons.pending_actions_outlined,
      selectedIcon: Icons.pending_actions,
      label: 'Pending Registrations',
      route: '/pending',
      description: 'Review submitted documents and approve or reject accounts.',
    ),
    NavItem(
      icon: Icons.local_parking_outlined,
      selectedIcon: Icons.local_parking,
      label: 'Parking',
      route: '/parking',
      description: 'Live bay occupancy, and manual entry and exit logging.',
    ),
    NavItem(
      icon: Icons.payments_outlined,
      selectedIcon: Icons.payments,
      label: 'Payments',
      route: '/payments',
      moduleLabel: 'Payment Monitoring',
      description: 'Track transactions, collected fees and outstanding balances.',
    ),
  ]),
  NavGroup('Enforcement', [
    NavItem(
      icon: Icons.gavel_outlined,
      selectedIcon: Icons.gavel,
      label: 'Violations',
      route: '/violations',
      moduleLabel: 'Violation Tracking',
      description: 'Document offences and enforce parking suspensions.',
    ),
    NavItem(
      icon: Icons.rule_outlined,
      selectedIcon: Icons.rule,
      label: 'Policy Rules',
      route: '/policy-rules',
      moduleLabel: 'Policy & Rule Management',
      description: 'Define regulations, penalties and suspension defaults.',
    ),
    NavItem(
      icon: Icons.report_outlined,
      selectedIcon: Icons.report,
      label: 'Incidents',
      route: '/incidents',
      moduleLabel: 'Incidents & Appeals',
      description: 'Review reported incidents and decide violation appeals.',
    ),
  ]),
  NavGroup('System', [
    NavItem(
      icon: Icons.people_outline,
      selectedIcon: Icons.people,
      label: 'User Management',
      route: '/users',
      moduleLabel: 'Manage Users',
      description: 'Verify credentials and control RFID access permissions.',
    ),
    NavItem(
      icon: Icons.notifications_outlined,
      selectedIcon: Icons.notifications,
      label: 'Notifications',
      route: '/notifications',
      moduleLabel: 'Notifications Management',
      description: 'Broadcast parking announcements and policy updates.',
    ),
    NavItem(
      icon: Icons.bar_chart_outlined,
      selectedIcon: Icons.bar_chart,
      label: 'Reports',
      route: '/reports',
      moduleLabel: 'Reports & Monitoring',
      description: 'Usage summaries, trends and generated reports.',
    ),
    NavItem(
      icon: Icons.history_outlined,
      selectedIcon: Icons.history,
      label: 'System Logs',
      route: '/system-logs',
      description:
          'Administrative actions, RFID access and violations, with export.',
    ),
  ]),
];

/// The same destinations flattened into display order. The sidebar's selected
/// index and the compact app-bar title both index into this, so it must stay
/// derived from [navGroups] rather than written out a second time.
final navItems = [for (final group in navGroups) ...group.items];

/// Every destination except Overview — the dashboard's shortcut grid, which
/// would otherwise offer a link back to the page you are already on.
final moduleShortcuts =
    navItems.where((item) => item.route != '/dashboard').toList();
