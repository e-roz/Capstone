import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/constants/api_endpoints.dart';
import '../core/network/dio_client.dart';
import '../models/parking_slot.dart';

part 'parking_provider.g.dart';

/// How often an open screen re-reads the bays. The slot sensors change a
/// bay's status on their own, with no tap or button to refresh after.
const slotRefreshEvery = Duration(seconds: 5);

@riverpod
Future<ParkingAvailability> parkingSlots(Ref ref) async {
  // Auto-disposed, so this only runs while something shows the bays. The
  // previous answer stays on screen while the next one loads.
  final timer = Timer(slotRefreshEvery, ref.invalidateSelf);
  ref.onDispose(timer.cancel);

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

/// Bays that may hold the wrong kind of vehicle. Read alongside the bays, on
/// the map's own refresh.
@riverpod
Future<List<WrongBayFlag>> wrongBayFlags(Ref ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get(ApiEndpoints.wrongBayFlags);
  return (response.data as List<dynamic>)
      .map((f) => WrongBayFlag.fromJson(f as Map<String, dynamic>))
      .toList();
}

@riverpod
class ParkingActions extends _$ParkingActions {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<String?> updateSlotStatus(String slotId, String status) async {
    return _run(() async {
      final dio = ref.read(dioProvider);
      final res = await dio
          .put(ApiEndpoints.slotStatus(slotId), data: {'status': status});
      return (res.data as Map<String, dynamic>)['message']?.toString();
    });
  }

  /// Closes the session belonging to a card, rather than to a picked log row.
  ///
  /// The gate screen only ever knows the card it just looked up - the same
  /// thing a reader knows - so it cannot supply a log id. The server resolves
  /// the open session from the tag, for an account or a visitor pass alike.
  Future<String?> logExitByTag(String rfidTagId) async {
    return _run(() async {
      final dio = ref.read(dioProvider);
      final res = await dio
          .post(ApiEndpoints.logParkingExit, data: {'rfidTagId': rfidTagId});
      return _exitMessage(res.data as Map<String, dynamic>);
    });
  }

  /// A guard's verdict after going to look: 'Confirmed' or 'FalseAlarm'.
  /// [note] is the follow-up report for the administrator, kept on a confirm.
  Future<String?> reviewWrongBay(String flagId, String outcome, {String? note}) async {
    return _run(() async {
      final dio = ref.read(dioProvider);
      final res = await dio.post(ApiEndpoints.reviewWrongBayFlag(flagId),
          data: {'outcome': outcome, 'note': ?note});
      return (res.data as Map<String, dynamic>)['message']?.toString();
    });
  }

  /// A visitor pays at the barrier, so the guard is told to collect it rather
  /// than being shown a bill that was never raised against anybody.
  String _exitMessage(Map<String, dynamic> data) {
    final amount = data['amountDue'];
    final msg = data['message']?.toString() ?? 'Exit logged.';
    if (amount == null) return msg;

    final cash = data['collectInCash'] == true;
    return cash
        ? '$msg Collect ₱$amount in cash.'
        : '$msg Amount due: ₱$amount';
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
