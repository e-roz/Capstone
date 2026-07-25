import 'package:flutter/material.dart';

import '../../../../core/widgets/app_bottom_nav.dart';
import '../../../account/presentation/screens/account_screen.dart';
import '../../../notifications/presentation/screens/notifications_screen.dart';
import '../../../parking/presentation/screens/parking_history_screen.dart';
import '../screens/user_dashboard_screen.dart';

/// Bottom-nav shell for the User role. Owns the active tab index and keeps
/// every tab's state alive via IndexedStack, rather than rebuilding screens
/// on every switch.
class UserShell extends StatefulWidget {
  const UserShell({super.key});

  @override
  State<UserShell> createState() => _UserShellState();
}

class _UserShellState extends State<UserShell> {
  int _navIndex = 0;

  void _goToTab(int index) => setState(() => _navIndex = index);

  @override
  Widget build(BuildContext context) {
    final tabs = [
      UserDashboardScreen(onNavigateToHistory: () => _goToTab(1)),
      const ParkingHistoryScreen(),
      const NotificationsScreen(),
      const AccountScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _navIndex, children: tabs),
      bottomNavigationBar: AppBottomNav(
        currentIndex: _navIndex,
        onTap: _goToTab,
        items: const [
          AppNavItem(icon: Icons.home_rounded, label: 'Home'),
          AppNavItem(icon: Icons.history_rounded, label: 'History'),
          AppNavItem(icon: Icons.notifications_rounded, label: 'Alerts'),
          AppNavItem(icon: Icons.person_rounded, label: 'Profile'),
        ],
      ),
    );
  }
}
