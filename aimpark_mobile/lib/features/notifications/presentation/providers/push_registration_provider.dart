import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/services/push_service.dart';
import '../../../parking/presentation/providers/parking_history_provider.dart';
import '../../../payments/presentation/providers/payments_provider.dart';
import '../../../violations/presentation/providers/violations_provider.dart';
import 'notifications_provider.dart';

part 'push_registration_provider.g.dart';

/// Owns the FCM token lifecycle: registers this device with the backend after
/// login, keeps it current when FCM rotates the token, and tears it down on logout.
///
/// Every call is best-effort — a user who denies notification permission, or a
/// device without Play Services, must still be able to use the whole app.
@Riverpod(keepAlive: true)
class PushRegistration extends _$PushRegistration {
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<dynamic>? _messageSub;
  String? _registeredToken;

  @override
  void build() {
    ref.onDispose(() {
      _tokenRefreshSub?.cancel();
      _messageSub?.cancel();
    });
  }

  /// Call right after a successful login (once an auth token exists, since the
  /// register call is authenticated).
  Future<void> registerAfterLogin() async {
    try {
      await PushService.instance.init();

      final token = await PushService.instance.requestPermissionAndGetToken();
      if (token == null) return;

      await ref
          .read(notificationsRepositoryProvider)
          .registerDeviceToken(token, PushService.instance.platform);
      _registeredToken = token;

      _listenForTokenRefresh();
      _listenForIncomingPushes();
    } catch (e) {
      debugPrint('Push registration failed (continuing without push): $e');
    }
  }

  /// Call during logout, before the auth token is cleared — the unregister
  /// endpoint is authenticated, so ordering matters here.
  Future<void> unregisterOnLogout() async {
    try {
      final token = _registeredToken;
      if (token != null) {
        await ref
            .read(notificationsRepositoryProvider)
            .unregisterDeviceToken(token);
      }
      // Drop the token itself too, so a different account signing in on this
      // phone gets a fresh one rather than inheriting the old registration.
      await PushService.instance.deleteToken();
    } catch (e) {
      debugPrint('Push unregistration failed: $e');
    } finally {
      _registeredToken = null;
      await _tokenRefreshSub?.cancel();
      await _messageSub?.cancel();
      _tokenRefreshSub = null;
      _messageSub = null;
    }
  }

  void _listenForTokenRefresh() {
    _tokenRefreshSub?.cancel();
    _tokenRefreshSub = PushService.instance.onTokenRefresh.listen((token) async {
      try {
        await ref
            .read(notificationsRepositoryProvider)
            .registerDeviceToken(token, PushService.instance.platform);
        _registeredToken = token;
      } catch (e) {
        debugPrint('Failed to re-register rotated FCM token: $e');
      }
    });
  }

  void _listenForIncomingPushes() {
    _messageSub?.cancel();
    // A push means something changed server-side, and it is almost never only
    // the notification list — a violation also changes the standing meter, a
    // fee adds a payment, an entry changes history. Refreshing just the alerts
    // tab was why a violation could arrive as a push and still leave the rest
    // of the app showing stale data until it was restarted.
    _messageSub = PushService.instance.onMessage.listen((_) => refreshAll());
  }

  /// Marks everything a server-side change could have touched as stale. Also
  /// called on app resume, since a backgrounded isolate receives no pushes and
  /// may have missed several.
  ///
  /// Invalidate rather than refresh: a provider being watched refetches
  /// immediately, while one nobody is looking at is simply dropped and reloads
  /// when it is next needed. Calling refresh() would fetch pages off-screen.
  void refreshAll() {
    ref.invalidate(notificationsNotifierProvider);
    ref.invalidate(violationsNotifierProvider);
    ref.invalidate(paymentsNotifierProvider);
    ref.invalidate(parkingHistoryNotifierProvider);
  }
}
