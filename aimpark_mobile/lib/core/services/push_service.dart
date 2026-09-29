import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Must match the channel id declared in AndroidManifest.xml and the one the
/// backend sets on outgoing messages — otherwise Android 8+ drops the heads-up display.
const _channelId = 'aimpark_default';

const _channel = AndroidNotificationChannel(
  _channelId,
  'AimPark Notifications',
  description: 'Parking announcements, violations, and account updates.',
  importance: Importance.high,
);

final _localNotifications = FlutterLocalNotificationsPlugin();

/// Handles pushes that arrive while the app is backgrounded or killed.
/// Must be a top-level function — Android spins up a separate isolate for it,
/// so it can't capture anything from the app's normal state.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  // Android already renders the system tray notification itself in this case,
  // so there's nothing to draw here. The handler still has to exist and be
  // registered, otherwise the plugin warns and data-only messages are dropped.
  await Firebase.initializeApp();
}

class PushService {
  PushService._();

  static final PushService instance = PushService._();

  /// Fires whenever a push arrives while the app is open, so screens can refresh.
  final _onMessage = StreamController<RemoteMessage>.broadcast();
  Stream<RemoteMessage> get onMessage => _onMessage.stream;

  /// Fires with a push's data when the user taps it, from the tray or from the
  /// heads-up drawn while the app was open. The data says where to go.
  final _onTap = StreamController<Map<String, String>>.broadcast();
  Stream<Map<String, String>> get onTap => _onTap.stream;

  /// A tap that launched the app from closed, kept until the home screen is
  /// ready to act on it. Taken once — see [takeLaunchTap].
  Map<String, String>? _launchTap;

  bool _initialized = false;
  Future<void>? _initializing;

  /// Sets up Firebase, the local-notification channel, and message listeners.
  /// Safe to call more than once. Never throws — a device without Google Play
  /// Services (or a missing google-services.json) must not crash the app.
  Future<void> init() => _initializing ??= _init();

  Future<void> _init() async {
    if (_initialized) return;

    try {
      await Firebase.initializeApp();

      FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);

      await _localNotifications.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
        // The heads-up drawn below for a foreground push carries the push's
        // data as its payload, so tapping it goes to the same place a tray tap
        // would.
        onDidReceiveNotificationResponse: (response) {
          final data = _decode(response.payload);
          if (data != null) _onTap.add(data);
        },
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);

      // A push that arrives while the app is in the foreground is NOT drawn by
      // the OS — we have to render it ourselves, and also tell listeners to refresh.
      FirebaseMessaging.onMessage.listen((message) {
        _showLocal(message);
        _onMessage.add(message);
      });

      // Tapping a tray notification while the app was in the background.
      // Still counts as a message too: something changed server-side.
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        _onMessage.add(message);
        _onTap.add(_strings(message.data));
      });

      // Tapping a notification while the app was closed. Nothing is listening
      // yet at this point, so it is held for the home screen to collect.
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) {
        _launchTap = _strings(initial.data);
      } else {
        // Or a heads-up we drew ourselves, tapped after the app was closed.
        final launch =
            await _localNotifications.getNotificationAppLaunchDetails();
        if (launch?.didNotificationLaunchApp ?? false) {
          _launchTap = _decode(launch!.notificationResponse?.payload);
        }
      }

      _initialized = true;
    } catch (e, st) {
      debugPrint('Push init failed (continuing without push): $e\n$st');
      // Let a later call try again rather than replaying this failure.
      _initializing = null;
    }
  }

  /// The tap that launched the app, if any, handed over once.
  ///
  /// Waits for [init], which runs in the background after login, so a home
  /// screen that builds first still gets the tap rather than missing it.
  Future<Map<String, String>?> takeLaunchTap() async {
    await init();
    final tap = _launchTap;
    _launchTap = null;
    return tap;
  }

  /// Asks the user for notification permission and returns the FCM token,
  /// or null if permission was denied or push is unavailable on this device.
  Future<String?> requestPermissionAndGetToken() async {
    try {
      final settings = await FirebaseMessaging.instance.requestPermission();

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return null;
      }

      return await FirebaseMessaging.instance.getToken();
    } catch (e) {
      debugPrint('Could not obtain FCM token: $e');
      return null;
    }
  }

  /// FCM rotates tokens (app reinstall, restore-from-backup, etc.), so the app
  /// has to re-send the new one or that device silently stops receiving pushes.
  Stream<String> get onTokenRefresh =>
      FirebaseMessaging.instance.onTokenRefresh;

  Future<void> deleteToken() async {
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (e) {
      debugPrint('Could not delete FCM token: $e');
    }
  }

  Future<void> _showLocal(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    await _localNotifications.show(
      id: notification.hashCode,
      title: notification.title,
      body: notification.body,
      payload: jsonEncode(message.data),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  static Map<String, String> _strings(Map<String, dynamic> data) =>
      data.map((k, v) => MapEntry(k, v.toString()));

  static Map<String, String>? _decode(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map) return null;
      return decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
    } catch (_) {
      return null;
    }
  }

  String get platform => Platform.isIOS ? 'ios' : 'android';
}
