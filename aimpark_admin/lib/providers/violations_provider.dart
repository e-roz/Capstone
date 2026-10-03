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
    required String category,
    required double defaultPenaltyAmount,
    required String defaultSuspensionType,
    int? defaultSuspensionDays,
    required int appealWindowDays,
    required bool isActive,
  }) =>
      _run(() async {
        final dio = ref.read(dioProvider);
        final res = await dio.post(ApiEndpoints.policyRules, data: {
          'title': title,
          'description': description,
          'category': category,
          'defaultPenaltyAmount': defaultPenaltyAmount,
          'defaultSuspensionType': defaultSuspensionType,
          'defaultSuspensionDays': defaultSuspensionDays,
          'appealWindowDays': appealWindowDays,
          'isActive': isActive,
        });
        return (res.data as Map<String, dynamic>)['message']?.toString();
      });

  Future<String?> update({
    required String ruleId,
    required String title,
    required String description,
    required String category,
    required double defaultPenaltyAmount,
    required String defaultSuspensionType,
    int? defaultSuspensionDays,
    required int appealWindowDays,
    required bool isActive,
  }) =>
      _run(() async {
        final dio = ref.read(dioProvider);
        final res = await dio.put(ApiEndpoints.policyRule(ruleId), data: {
          'title': title,
          'description': description,
          'category': category,
          'defaultPenaltyAmount': defaultPenaltyAmount,
          'defaultSuspensionType': defaultSuspensionType,
          'defaultSuspensionDays': defaultSuspensionDays,
          'appealWindowDays': appealWindowDays,
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

  /// Matches name, student number or RFID tag.
  final String? search;

  /// Narrows to everyone who broke one rule.
  final String? ruleId;

  /// Narrows to one user's whole history. [userName] is only for the chip
  /// that shows the filter is on.
  final String? userId;
  final String? userName;

  const ViolationsQuery({
    this.page = 1,
    this.pageSize = 20,
    this.status,
    this.search,
    this.ruleId,
    this.userId,
    this.userName,
  });

  ViolationsQuery copyWith({
    int? page,
    int? pageSize,
    String? status,
    bool clearStatus = false,
    String? search,
    String? ruleId,
    bool clearRule = false,
    String? userId,
    String? userName,
    bool clearUser = false,
  }) =>
      ViolationsQuery(
        page: page ?? this.page,
        pageSize: pageSize ?? this.pageSize,
        status: clearStatus ? null : (status ?? this.status),
        search: search ?? this.search,
        ruleId: clearRule ? null : (ruleId ?? this.ruleId),
        userId: clearUser ? null : (userId ?? this.userId),
        userName: clearUser ? null : (userName ?? this.userName),
      );

  Map<String, dynamic> toParams() => {
        'page': page,
        'pageSize': pageSize,
        'status': ?status,
        if (search != null && search!.isNotEmpty) 'search': search,
        'ruleId': ?ruleId,
        'userId': ?userId,
      };
}

@riverpod
class ViolationsQueryNotifier extends _$ViolationsQueryNotifier {
  @override
  ViolationsQuery build() => const ViolationsQuery();

  void setPage(int page) => state = state.copyWith(page: page);
  void setStatus(String? status) => state = state.copyWith(
      status: status, clearStatus: status == null, page: 1);
  void setSearch(String search) =>
      state = state.copyWith(search: search, page: 1);
  void setRule(String? ruleId) =>
      state = state.copyWith(ruleId: ruleId, clearRule: ruleId == null, page: 1);

  /// Shows one user's entire violation history. Clears the other filters so
  /// the history is not silently cut down to one status or rule.
  void showUser(String userId, String userName) => state = ViolationsQuery(
      pageSize: state.pageSize, userId: userId, userName: userName);
  void clearUser() => state = state.copyWith(clearUser: true, page: 1);
}

@riverpod
Future<ViolationListPage> violationList(Ref ref) async {
  final query = ref.watch(violationsQueryNotifierProvider);
  final dio = ref.watch(dioProvider);

  final params = query.toParams();

  final response =
      await dio.get(ApiEndpoints.violations, queryParameters: params);
  return ViolationListPage.fromJson(response.data as Map<String, dynamic>);
}

/// One violation with everything the View dialog needs: the user, the full
/// rule, the appeal and the timeline.
@riverpod
Future<ViolationDetail> violationDetail(Ref ref, String violationId) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get(ApiEndpoints.violation(violationId));
  return ViolationDetail.fromJson(response.data as Map<String, dynamic>);
}

// ── Violation logs (System Logs module) ─────────────────────────────────────

/// The same endpoint as [violationList], behind its own query state.
///
/// System Logs shows violations as an audit trail while Violation Tracking
/// shows them as a work queue. Sharing one notifier between the two would mean
/// filtering the log silently re-filtered the queue you left behind on the
/// other screen, and paging one paged the other.
@riverpod
class ViolationLogsQueryNotifier extends _$ViolationLogsQueryNotifier {
  @override
  ViolationsQuery build() => const ViolationsQuery();

  void setPage(int page) => state = state.copyWith(page: page);
  void setStatus(String? status) => state =
      state.copyWith(status: status, clearStatus: status == null, page: 1);
}

@riverpod
Future<ViolationListPage> violationLogList(Ref ref) async {
  final query = ref.watch(violationLogsQueryNotifierProvider);
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

/// How many appeals are still waiting on a decision. See [openIncidentCount]
/// for why this is a request of its own rather than a count off the list.
@riverpod
Future<int> pendingAppealCount(Ref ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get(
    ApiEndpoints.violationAppeals,
    queryParameters: {'page': 1, 'pageSize': 1, 'status': 'Pending'},
  );
  return ViolationAppealListPage.fromJson(response.data as Map<String, dynamic>)
      .totalCount;
}

// ── Actions ───────────────────────────────────────────────────────────────

@riverpod
class ViolationActions extends _$ViolationActions {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  /// The rule decides the penalty, suspension and appeal window — there are
  /// no overrides to send.
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

  /// For a violation that should never have been issued. Reason required.
  Future<String?> dismiss(String violationId, String reason) => _run(() async {
        final dio = ref.read(dioProvider);
        final res = await dio.put(ApiEndpoints.dismissViolation(violationId),
            data: {'reason': reason});
        return (res.data as Map<String, dynamic>)['message']?.toString();
      });

  /// Makes the user accountable now, without waiting for the appeal deadline.
  Future<String?> makeAccountable(String violationId, String reason) =>
      _run(() async {
        final dio = ref.read(dioProvider);
        final res = await dio.put(
            ApiEndpoints.makeViolationAccountable(violationId),
            data: {'reason': reason});
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
