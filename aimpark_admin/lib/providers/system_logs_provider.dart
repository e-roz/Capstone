import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/constants/api_endpoints.dart';
import '../core/network/dio_client.dart';
import '../models/system_log_entries.dart';

part 'system_logs_provider.g.dart';

// ── User activity ────────────────────────────────────────────────────────────

/// The activity names the API writes, mirroring `UserActivities` on the server.
/// Kept in step by hand; a value the server adds and this misses simply never
/// appears in the filter, which is why the table degrades to showing everything
/// rather than throwing.
const userActivityOptions = <String, String>{
  'Login': 'Login',
  'LoginFailed': 'Failed login',
  'Logout': 'Logout',
  'Registered': 'Registered',
  'StatusChanged': 'Status changed',
  'Approved': 'Approved',
  'Rejected': 'Rejected',
  'RfidAssigned': 'RFID assigned',
  'RfidRevoked': 'RFID revoked',
};

class UserActivityQuery {
  final int page;
  final int pageSize;
  final String? activity;

  const UserActivityQuery({this.page = 1, this.pageSize = 20, this.activity});

  UserActivityQuery copyWith({
    int? page,
    int? pageSize,
    String? activity,
    bool clearActivity = false,
  }) =>
      UserActivityQuery(
        page: page ?? this.page,
        pageSize: pageSize ?? this.pageSize,
        activity: clearActivity ? null : (activity ?? this.activity),
      );
}

@riverpod
class UserActivityQueryNotifier extends _$UserActivityQueryNotifier {
  @override
  UserActivityQuery build() => const UserActivityQuery();

  void setPage(int page) => state = state.copyWith(page: page);
  void setActivity(String? activity) => state = state.copyWith(
      activity: activity, clearActivity: activity == null, page: 1);
}

@riverpod
Future<UserActivityLogPage> userActivityLogs(Ref ref) async {
  final query = ref.watch(userActivityQueryNotifierProvider);
  final dio = ref.watch(dioProvider);

  final params = <String, dynamic>{
    'page': query.page,
    'pageSize': query.pageSize,
    if (query.activity != null) 'activity': query.activity,
  };

  final response =
      await dio.get(ApiEndpoints.userActivityLogs, queryParameters: params);
  return UserActivityLogPage.fromJson(response.data as Map<String, dynamic>);
}

// ── System errors ────────────────────────────────────────────────────────────

@riverpod
class ErrorLogsPageNotifier extends _$ErrorLogsPageNotifier {
  @override
  int build() => 1;

  void setPage(int page) => state = page;
}

@riverpod
Future<SystemErrorLogPage> systemErrorLogs(Ref ref) async {
  final page = ref.watch(errorLogsPageNotifierProvider);
  final dio = ref.watch(dioProvider);

  final response = await dio.get(
    ApiEndpoints.systemErrorLogs,
    queryParameters: {'page': page, 'pageSize': 20},
  );
  return SystemErrorLogPage.fromJson(response.data as Map<String, dynamic>);
}
