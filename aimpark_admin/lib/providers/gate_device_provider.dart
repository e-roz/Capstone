import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/constants/api_endpoints.dart';
import '../core/network/dio_client.dart';
import '../models/gate_device.dart';

part 'gate_device_provider.g.dart';

/// Every reader and camera ever registered, revoked ones included — a
/// revoked row stays as the record of what used to talk to this gate.
@riverpod
Future<List<GateDevice>> gateDeviceList(Ref ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get(ApiEndpoints.gateDevices);
  return (response.data as List<dynamic>)
      .map((d) => GateDevice.fromJson(d as Map<String, dynamic>))
      .toList();
}

@riverpod
class GateDeviceActions extends _$GateDeviceActions {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  /// Returns the created device's key on success, or null with [error] set
  /// on failure — kept separate from the string-message actions elsewhere in
  /// this app because the key itself must reach the caller, not just a
  /// confirmation message.
  Future<({CreatedGateDevice? device, String? error})> register({
    required String name,
    required int gate,
    required GateDeviceType deviceType,
  }) async {
    state = const AsyncLoading();
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.post(ApiEndpoints.gateDevices, data: {
        'name': name,
        'gate': gate,
        'deviceType': deviceType.toJson(),
      });
      state = const AsyncData(null);
      return (
        device: CreatedGateDevice.fromJson(res.data as Map<String, dynamic>),
        error: null,
      );
    } on DioException catch (e) {
      state = const AsyncData(null);
      final data = e.response?.data;
      final message = data is Map
          ? data['message']?.toString() ?? e.message ?? 'Error'
          : e.message ?? 'Unknown error';
      return (device: null, error: message);
    }
  }

  Future<String?> revoke(String deviceId) async {
    state = const AsyncLoading();
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.post(ApiEndpoints.revokeGateDevice(deviceId));
      state = const AsyncData(null);
      return (res.data as Map<String, dynamic>)['message']?.toString() ??
          'Device revoked.';
    } on DioException catch (e) {
      state = const AsyncData(null);
      final data = e.response?.data;
      if (data is Map) {
        return data['message']?.toString() ?? e.message ?? 'Error';
      }
      return e.message ?? 'Unknown error';
    }
  }
}
