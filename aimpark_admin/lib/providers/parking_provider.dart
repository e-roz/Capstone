import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/constants/api_endpoints.dart';
import '../core/network/dio_client.dart';
import '../models/parking_slot.dart';

part 'parking_provider.g.dart';

@riverpod
Future<ParkingAvailability> parkingSlots(Ref ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get(ApiEndpoints.parkingSlots);
  return ParkingAvailability.fromJson(response.data as Map<String, dynamic>);
}

@riverpod
Future<List<ActiveParkingSession>> activeParkingSessions(Ref ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get(ApiEndpoints.activeParkingSessions);
  return (response.data as List<dynamic>)
      .map((s) => ActiveParkingSession.fromJson(s as Map<String, dynamic>))
      .toList();
}

@riverpod
class ParkingActions extends _$ParkingActions {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<String?> createSlot(String slotCode, String? vehicleType, int gate) async {
    return _run(() async {
      final dio = ref.read(dioProvider);
      final res = await dio.post(ApiEndpoints.parkingSlots, data: {
        'slotCode': slotCode,
        'vehicleType': vehicleType,
        'gate': gate,
      });
      return (res.data as Map<String, dynamic>)['message']?.toString();
    });
  }

  Future<String?> updateSlotStatus(String slotId, String status) async {
    return _run(() async {
      final dio = ref.read(dioProvider);
      final res = await dio
          .put(ApiEndpoints.slotStatus(slotId), data: {'status': status});
      return (res.data as Map<String, dynamic>)['message']?.toString();
    });
  }

  Future<String?> logEntry({
    String? userId,
    String? rfidTagId,
    String? slotId,
    int? gate,
  }) async {
    return _run(() async {
      final dio = ref.read(dioProvider);
      final res = await dio.post(ApiEndpoints.logParkingEntry, data: {
        if (userId != null && userId.isNotEmpty) 'userId': userId,
        if (rfidTagId != null && rfidTagId.isNotEmpty) 'rfidTagId': rfidTagId,
        if (slotId != null && slotId.isNotEmpty) 'slotId': slotId,
        'gate': ?gate,
      });
      final data = res.data as Map<String, dynamic>;
      final msg = data['message']?.toString() ?? 'Entry logged.';
      // Surface the assigned bay — on the automatic path this is the whole
      // answer, and it is what the gate display will show in production.
      final slotCode = data['slotCode']?.toString();
      final assignedGate = data['gate']?.toString();
      if (slotCode != null && assignedGate != null) {
        return '$msg Assigned Gate $assignedGate · $slotCode';
      }
      final logId = data['logId']?.toString();
      return logId != null ? '$msg Log ID: $logId' : msg;
    });
  }

  Future<String?> logExit(String logId) async {
    return _run(() async {
      final dio = ref.read(dioProvider);
      final res = await dio
          .post(ApiEndpoints.logParkingExit, data: {'logId': logId});
      final data = res.data as Map<String, dynamic>;
      final amount = data['amountDue'];
      final msg = data['message']?.toString() ?? 'Exit logged.';
      return amount != null ? '$msg Amount due: $amount' : msg;
    });
  }

  Future<String?> _run(Future<String?> Function() fn) async {
    state = const AsyncLoading();
    try {
      final msg = await fn();
      state = const AsyncData(null);
      return msg;
    } on DioException catch (e) {
      state = const AsyncData(null);
      final data = e.response?.data;
      if (data is Map) return data['message']?.toString() ?? e.message ?? 'Error';
      return e.message ?? 'Unknown error';
    }
  }
}
