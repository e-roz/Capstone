import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/constants/api_endpoints.dart';
import '../core/network/dio_client.dart';
import '../models/cash_summary.dart';
import '../models/parking_slot.dart';

part 'exit_payment_provider.g.dart';

/// How often the panel re-reads who is waiting at the exit. A car is sitting at
/// a shut barrier, so this is as live as the gate log.
const waitingToLeaveEvery = Duration(seconds: 3);

/// Drivers who tapped out, owe this session's fee, and are held at the barrier
/// until it is settled. Oldest first, since they have waited longest.
@riverpod
Future<List<ActiveParkingSession>> waitingToLeave(Ref ref) async {
  // Auto-disposed, so this only runs while a card is on screen.
  final timer = Timer(waitingToLeaveEvery, ref.invalidateSelf);
  ref.onDispose(timer.cancel);

  final response = await ref.watch(dioProvider).get(ApiEndpoints.activeParkingSessions);
  final waiting = (response.data as List<dynamic>)
      .map((s) => ActiveParkingSession.fromJson(s as Map<String, dynamic>))
      .where((s) => s.waitingToLeave)
      .toList()
    ..sort((a, b) => (a.waitingSince ?? a.entryTime).compareTo(b.waitingSince ?? b.entryTime));
  return waiting;
}

@riverpod
Future<CashSummary> cashSummary(Ref ref) async {
  final timer = Timer(const Duration(seconds: 20), ref.invalidateSelf);
  ref.onDispose(timer.cancel);

  final response = await ref.watch(dioProvider).get(ApiEndpoints.sitePaymentsCashSummary);
  return CashSummary.fromJson(response.data as Map<String, dynamic>);
}

@riverpod
class ExitPaymentActions extends _$ExitPaymentActions {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  /// The guard has taken the bill's amount in cash. Returns the message to show,
  /// or null on success with nothing to say.
  Future<String?> receiveCash(String paymentId) => _run(() async {
        final res = await ref.read(dioProvider).post(ApiEndpoints.sitePaymentCash(paymentId));
        final data = res.data as Map<String, dynamic>;
        final ref0 = data['referenceNumber']?.toString();
        return ref0 == null ? 'Cash recorded.' : 'Cash recorded. Receipt $ref0.';
      });

  /// Lets the driver through on their next tap while the bill stays owed.
  Future<String?> release(String paymentId, String reason) => _run(() async {
        final res = await ref
            .read(dioProvider)
            .post(ApiEndpoints.sitePaymentRelease(paymentId), data: {'reason': reason});
        return (res.data as Map<String, dynamic>)['message']?.toString() ??
            'The driver can tap to leave.';
      });

  Future<String?> _run(Future<String?> Function() fn) async {
    state = const AsyncLoading();
    try {
      final msg = await fn();
      state = const AsyncData(null);
      return msg;
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
