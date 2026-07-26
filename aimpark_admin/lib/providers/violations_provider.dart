import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/constants/api_endpoints.dart';
import '../core/network/dio_client.dart';
import '../models/violation.dart';

part 'violations_provider.g.dart';

// ── Policy rules (also used as the picker when issuing a violation) ─────────

@riverpod
Future<List<PolicyRule>> policyRules(Ref ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get(ApiEndpoints.policyRules);
  return (response.data as List<dynamic>)
      .map((r) => PolicyRule.fromJson(r as Map<String, dynamic>))
      .toList();
}

@riverpod
class PolicyRuleActions extends _$PolicyRuleActions {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<String?> create({
    required String title,
    required String description,
    required double defaultPenaltyAmount,
    required String defaultSuspensionType,
    int? defaultSuspensionDays,
    required bool isActive,
  }) =>
      _run(() async {
        final dio = ref.read(dioProvider);
        final res = await dio.post(ApiEndpoints.policyRules, data: {
          'title': title,
          'description': description,
          'defaultPenaltyAmount': defaultPenaltyAmount,
          'defaultSuspensionType': defaultSuspensionType,
          'defaultSuspensionDays': defaultSuspensionDays,
          'isActive': isActive,
        });
        return (res.data as Map<String, dynamic>)['message']?.toString();
      });

  Future<String?> update({
    required String ruleId,
    required String title,
    required String description,
    required double defaultPenaltyAmount,
    required String defaultSuspensionType,
    int? defaultSuspensionDays,
    required bool isActive,
  }) =>
      _run(() async {
        final dio = ref.read(dioProvider);
        final res = await dio.put(ApiEndpoints.policyRule(ruleId), data: {
          'title': title,
          'description': description,
          'defaultPenaltyAmount': defaultPenaltyAmount,
          'defaultSuspensionType': defaultSuspensionType,
          'defaultSuspensionDays': defaultSuspensionDays,
          'isActive': isActive,
        });
        return (res.data as Map<String, dynamic>)['message']?.toString();
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
      if (data is Map) return data['message']?.toString() ?? e.message ?? 'Error';
      return e.message ?? 'Unknown error';
    }
  }
}

// ── Violations ────────────────────────────────────────────────────────────

class ViolationsQuery {
  final int page;
  final int pageSize;
  final String? status;

  const ViolationsQuery({this.page = 1, this.pageSize = 20, this.status});

  ViolationsQuery copyWith(
          {int? page, int? pageSize, String? status, bool clearStatus = false}) =>
      ViolationsQuery(
        page: page ?? this.page,
        pageSize: pageSize ?? this.pageSize,
        status: clearStatus ? null : (status ?? this.status),
      );
}

@riverpod
class ViolationsQueryNotifier extends _$ViolationsQueryNotifier {
  @override
  ViolationsQuery build() => const ViolationsQuery();

  void setPage(int page) => state = state.copyWith(page: page);
  void setStatus(String? status) => state = state.copyWith(
      status: status, clearStatus: status == null, page: 1);
}

@riverpod
Future<ViolationListPage> violationList(Ref ref) async {
  final query = ref.watch(violationsQueryNotifierProvider);
  final dio = ref.watch(dioProvider);

  final params = <String, dynamic>{
    'page': query.page,
    'pageSize': query.pageSize,
    if (query.status != null) 'status': query.status,
  };

  final response =
      await dio.get(ApiEndpoints.violations, queryParameters: params);
  return ViolationListPage.fromJson(response.data as Map<String, dynamic>);
}

// ── Appeals ───────────────────────────────────────────────────────────────

class AppealsQuery {
  final int page;
  final int pageSize;
  final String? status;

  const AppealsQuery({this.page = 1, this.pageSize = 20, this.status});

  AppealsQuery copyWith(
          {int? page, int? pageSize, String? status, bool clearStatus = false}) =>
      AppealsQuery(
        page: page ?? this.page,
        pageSize: pageSize ?? this.pageSize,
        status: clearStatus ? null : (status ?? this.status),
      );
}

@riverpod
class AppealsQueryNotifier extends _$AppealsQueryNotifier {
  @override
  AppealsQuery build() => const AppealsQuery();

  void setPage(int page) => state = state.copyWith(page: page);
  void setStatus(String? status) => state = state.copyWith(
      status: status, clearStatus: status == null, page: 1);
}

@riverpod
Future<ViolationAppealListPage> appealList(Ref ref) async {
  final query = ref.watch(appealsQueryNotifierProvider);
  final dio = ref.watch(dioProvider);

  final params = <String, dynamic>{
    'page': query.page,
    'pageSize': query.pageSize,
    if (query.status != null) 'status': query.status,
  };

  final response =
      await dio.get(ApiEndpoints.violationAppeals, queryParameters: params);
  return ViolationAppealListPage.fromJson(response.data as Map<String, dynamic>);
}

// ── Actions ───────────────────────────────────────────────────────────────

@riverpod
class ViolationActions extends _$ViolationActions {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<String?> issue({
    required String userId,
    required String policyRuleId,
    required String description,
  }) =>
      _run(() async {
        final dio = ref.read(dioProvider);
        final res = await dio.post(ApiEndpoints.violations, data: {
          'userId': userId,
          'policyRuleId': policyRuleId,
          'description': description,
        });
        return (res.data as Map<String, dynamic>)['message']?.toString();
      });

  Future<String?> dismiss(String violationId) => _run(() async {
        final dio = ref.read(dioProvider);
        final res = await dio.put(ApiEndpoints.dismissViolation(violationId));
        return (res.data as Map<String, dynamic>)['message']?.toString();
      });

  Future<String?> decideAppeal(String appealId, bool approve, String? adminNotes) =>
      _run(() async {
        final dio = ref.read(dioProvider);
        final res = await dio.put(ApiEndpoints.decideAppeal(appealId), data: {
          'approve': approve,
          'adminNotes': adminNotes,
        });
        return (res.data as Map<String, dynamic>)['message']?.toString();
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
      if (data is Map) return data['message']?.toString() ?? e.message ?? 'Error';
      return e.message ?? 'Unknown error';
    }
  }
}
