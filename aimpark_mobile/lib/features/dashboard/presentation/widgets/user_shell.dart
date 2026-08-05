import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/app_bottom_nav.dart';
import '../../../account/presentation/screens/account_screen.dart';
import '../../../notifications/presentation/providers/notifications_provider.dart';
import '../../../notifications/presentation/providers/push_registration_provider.dart';
import '../../../notifications/presentation/screens/notifications_screen.dart';
import '../../../parking/presentation/screens/parking_history_screen.dart';
import '../screens/user_dashboard_screen.dart';

/// Bottom-nav shell for the User role. Owns the active tab index and keeps
/// every tab's state alive via IndexedStack, rather than rebuilding screens
/// on every switch.
class UserShell extends ConsumerStatefulWidget {
  const UserShell({super.key});

  @override
  ConsumerState<UserShell> createState() => _UserShellState();
}

class _UserShellState extends ConsumerState<UserShell> with WidgetsBindingObserver {
  int _navIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Keeping every tab alive in an IndexedStack means providers build once and
  /// then never refetch on their own — which is why the app appeared frozen
  /// until it was force-closed. Pushes cover the foreground; this covers coming
  /// back from the background, where no push was delivered to act on.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(pushRegistrationProvider.notifier).refreshAll();
    }
  }

  void _goToTab(int index) => setState(() => _navIndex = index);

  @override
  Widget build(BuildContext context) {
    // Drives the Alerts badge. Watched here rather than inside the tab so the
    // count is visible from any tab — a violation is no use sitting unseen
    // behind a screen the user has no reason to open.
    final unreadCount = ref.watch(notificationsNotifierProvider)
            .valueOrNull
            ?.unreadCount ??
        0;

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
        items: [
          const AppNavItem(icon: Icons.home_rounded, label: 'Home'),
          const AppNavItem(icon: Icons.history_rounded, label: 'History'),
          AppNavItem(
            icon: Icons.notifications_rounded,
            label: 'Alerts',
            badgeCount: unreadCount,
          ),
          const AppNavItem(icon: Icons.person_rounded, label: 'Profile'),
        ],
      ),
    );
  }
}
