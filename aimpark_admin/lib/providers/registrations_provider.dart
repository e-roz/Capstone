import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/constants/api_endpoints.dart';
import '../core/network/dio_client.dart';
import '../models/pending_registration.dart';
import '../models/registration_detail.dart';

part 'registrations_provider.g.dart';

// ── Pending list ────────────────────────────────────────────────────────────

@riverpod
Future<List<PendingRegistration>> pendingRegistrations(Ref ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get(ApiEndpoints.pendingRegistrations);
  final data = response.data as List<dynamic>;
  return data
      .map((e) => PendingRegistration.fromJson(e as Map<String, dynamic>))
      .toList();
}

// ── Registration detail ─────────────────────────────────────────────────────

@riverpod
Future<RegistrationDetail> registrationDetail(Ref ref, String userId) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get(ApiEndpoints.registrationDetail(userId));
  return RegistrationDetail.fromJson(response.data as Map<String, dynamic>);
}

// ── Actions ─────────────────────────────────────────────────────────────────

@riverpod
class RegistrationActions extends _$RegistrationActions {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<String?> approve(String userId) async {
    state = const AsyncLoading();
    try {
      final dio = ref.read(dioProvider);
      final res =
          await dio.post(ApiEndpoints.approveRegistration(userId));
      state = const AsyncData(null);
      return (res.data as Map<String, dynamic>)['message']?.toString();
    } on DioException catch (e) {
      state = const AsyncData(null);
      return _errorMessage(e);
    }
  }

  Future<String?> reject(
      String userId, String reason, int cooldownHours) async {
    state = const AsyncLoading();
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.post(
        ApiEndpoints.rejectRegistration(userId),
        data: {'reason': reason, 'cooldownHours': cooldownHours},
      );
      state = const AsyncData(null);
      return (res.data as Map<String, dynamic>)['message']?.toString();
    } on DioException catch (e) {
      state = const AsyncData(null);
      return _errorMessage(e);
    }
  }

  String _errorMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map) return data['message']?.toString() ?? e.message ?? 'Error';
    return e.message ?? 'Unknown error';
  }
}
