import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/push_navigation.dart';
import '../../../../core/services/push_service.dart';
import '../../../../core/widgets/app_bottom_nav.dart';
import '../../../account/presentation/screens/account_screen.dart';
import '../../../notifications/presentation/providers/notifications_provider.dart';
import '../../../notifications/presentation/providers/push_registration_provider.dart';
import '../../../payments/presentation/screens/payments_list_screen.dart';
import '../../../parking/presentation/screens/parking_screen.dart';
import '../screens/user_dashboard_screen.dart';

/// Bottom-nav shell for the User role. Owns the active tab index and keeps
/// every tab's state alive via IndexedStack, rather than rebuilding screens
/// on every switch.
class UserShell extends ConsumerStatefulWidget {
  const UserShell({super.key, this.initialTab = 0});

  /// Which tab to open on: 0 Home, 1 Parking, 2 Payments, 3 Account. The app
  /// bar's "back" from a payment lands on Payments rather than always on Home.
  final int initialTab;

  /// Reads the tab out of `?tab=payments` and the like. Anything unrecognised is
  /// Home.
  static int tabFromName(String? name) => switch (name) {
        'parking' => 1,
        'payments' => 2,
        'account' => 3,
        _ => 0,
      };

  @override
  ConsumerState<UserShell> createState() => _UserShellState();
}

class _UserShellState extends ConsumerState<UserShell> with WidgetsBindingObserver {
  late int _navIndex = widget.initialTab;
  StreamSubscription<Map<String, String>>? _tapSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Taps are handled here, not app-wide: this shell only exists once a
    // User is signed in, so a tap that arrives before then waits for it
    // instead of opening a screen the router would bounce to login.
    _tapSub = PushService.instance.onTap.listen(_openFromPush);
    unawaited(_openLaunchTap());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tapSub?.cancel();
    super.dispose();
  }

  Future<void> _openLaunchTap() async {
    final tap = await PushService.instance.takeLaunchTap();
    if (tap != null && mounted) _openFromPush(tap);
  }

  /// Opens whatever the tapped notification is about, and marks it read —
  /// tapping it is reading it.
  void _openFromPush(Map<String, String> data) {
    final notificationId = data['notificationId'];
    if (notificationId != null && notificationId.isNotEmpty) {
      unawaited(
        ref
            .read(notificationsRepositoryProvider)
            .markRead(notificationId)
            .then((_) => ref.invalidate(notificationsNotifierProvider))
            .catchError((_) {}),
      );
    }

    // Also covers the tap arriving mid-refresh from the push itself.
    ref.read(pushRegistrationProvider.notifier).refreshAll();

    if (mounted) context.push(routeForPush(data));
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
    final tabs = [
      UserDashboardScreen(
        onNavigateToParking: () => _goToTab(1),
        onNavigateToPayments: () => _goToTab(2),
        onNavigateToAccount: () => _goToTab(3),
      ),
      const ParkingScreen(),
      const PaymentsListScreen.tab(),
      const AccountScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _navIndex, children: tabs),
      bottomNavigationBar: AppBottomNav(
        currentIndex: _navIndex,
        onTap: _goToTab,
        items: [
          const AppNavItem(icon: Icons.home_rounded, label: 'Home'),
          const AppNavItem(icon: Icons.local_parking_rounded, label: 'Parking'),
          const AppNavItem(icon: Icons.credit_card_rounded, label: 'Payments'),
          // No unread badge here any more. It moved to the bell in Home's header,
          // beside the avatar, where a notification is looked for; a count on
          // Account read as something wrong with the account.
          const AppNavItem(icon: Icons.person_rounded, label: 'Account'),
        ],
      ),
    );
  }
}
