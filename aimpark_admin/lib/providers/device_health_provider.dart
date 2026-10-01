import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/api_endpoints.dart';
import '../core/network/dio_client.dart';
import '../models/device_health.dart';

class DeviceHealthState {
  /// Null until the first check answers.
  final DeviceHealthReport? report;

  /// False when the panel was opened from the cloud, which has no devices
  /// plugged into it to report on.
  final bool atGuardPost;

  /// The last check failed. [report] is the one before it.
  final String? error;

  const DeviceHealthState({this.report, this.atGuardPost = true, this.error});
}

/// Every device the guard post depends on, checked every few seconds while a
/// screen shows it.
///
/// Auto-disposed, so the polling stops when the Overview or the dashboard is
/// left. Both screens watch this one provider, which is what lets the
/// offline/back-online alert compare one check with the next.
final deviceHealthProvider =
    NotifierProvider.autoDispose<DeviceHealthMonitor, DeviceHealthState>(
  DeviceHealthMonitor.new,
);

class DeviceHealthMonitor extends AutoDisposeNotifier<DeviceHealthState> {
  /// A node is declared offline 16 s after its last heartbeat; checking
  /// faster than this would only repeat the same answer.
  static const refreshEvery = Duration(seconds: 5);

  bool _disposed = false;

  @override
  DeviceHealthState build() {
    final timer = Timer.periodic(refreshEvery, (_) => refresh());
    ref.onDispose(() {
      _disposed = true;
      timer.cancel();
    });
    Future.microtask(refresh);
    return const DeviceHealthState();
  }

  Future<void> refresh() async {
    try {
      final res = await ref.read(dioProvider).get(ApiEndpoints.deviceHealth);
      if (_disposed) return;
      state = DeviceHealthState(
        report: DeviceHealthReport.fromJson(res.data as Map<String, dynamic>),
      );
    } on DioException catch (e) {
      if (_disposed) return;
      final code = e.response?.statusCode;
      // The cloud panel: these are the guard post's own endpoints.
      state = code == 400 || code == 404
          ? const DeviceHealthState(atGuardPost: false)
          : DeviceHealthState(
              report: state.report,
              error: 'Could not reach the guard post server.',
            );
    }
  }
}
