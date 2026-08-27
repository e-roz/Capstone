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
    this.roles = const {StaffRole.admin},
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

  /// Who may see this destination.
  ///
  /// Admin-only by default, because that is what every entry was before
  /// Security could sign in — a destination that forgets to say who it is for
  /// should stay hidden rather than leak.
  final Set<StaffRole> roles;

  /// The name to show on a dashboard shortcut.
  String get displayLabel => moduleLabel ?? label;
}

/// The two kinds of account that can sign in to this panel.
///
/// Mapped from the JWT role claim. `User` never reaches here — the login screen
/// turns those away, since the whole panel is staff tooling.
enum StaffRole {
  admin,
  security;

  static StaffRole? fromClaim(String? role) => switch (role) {
        'Admin' => StaffRole.admin,
        'Security' => StaffRole.security,
        _ => null,
      };

  String get label => this == StaffRole.admin ? 'Administrator' : 'Security';
}

/// The groups this role may see, with the destinations it may not stripped out.
///
/// Filtered here rather than in the sidebar so the rail, the mobile drawer and
/// the dashboard's shortcut grid cannot disagree about what a Security account
/// is allowed to open — which is exactly the drift [navGroups] exists to stop.
List<NavGroup> navGroupsFor(StaffRole role) {
  final groups = <NavGroup>[];

  for (final group in navGroups) {
    final items = group.items.where((i) => i.roles.contains(role)).toList();
    if (items.isNotEmpty) groups.add(NavGroup(group.label, items));
  }

  return groups;
}

/// Flat list of the routes a role may open, for the router's guard.
List<String> routesFor(StaffRole role) => [
      for (final group in navGroupsFor(role))
        for (final item in group.items) item.route,
    ];

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
      roles: {StaffRole.admin, StaffRole.security},
    ),
  ]),
  NavGroup('Gate', [
    NavItem(
      icon: Icons.badge_outlined,
      selectedIcon: Icons.badge,
      label: 'Gate Check',
      route: '/gate',
      moduleLabel: 'Entry/Exit Verification',
      description:
          'Look up a card, check the vehicle matches, and log entry or exit.',
      roles: {StaffRole.admin, StaffRole.security},
    ),
    NavItem(
      icon: Icons.person_add_alt_outlined,
      selectedIcon: Icons.person_add_alt_1,
      label: 'Visitor Passes',
      route: '/visitors',
      moduleLabel: 'Visitor RFID Access',
      description: 'Lend spare RFID cards to guests and take them back.',
      roles: {StaffRole.admin, StaffRole.security},
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
      // Admin only, deliberately. Most of this screen is creating bays and
      // changing their status, which a guard may not do — and the two things
      // they need from it, occupancy and manual entry/exit, they get on their
      // own Overview and Gate Check without a screen of disabled buttons.
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
      // Security reports what they see on the ground and follows it up. The
      // appeals half of the module is admin work, and the screen hides that tab
      // for them rather than the whole destination being withheld.
      roles: {StaffRole.admin, StaffRole.security},
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
      // Security sees the inbox half only - "Receive Notifications" in the
      // spec. The screen hides the Sent tab and the Broadcast button for them.
      roles: {StaffRole.admin, StaffRole.security},
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
      // "Access Monitoring" in the spec. Security sees the RFID access tab only
      // — the API refuses them the other two, and the screen hides them.
      roles: {StaffRole.admin, StaffRole.security},
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
