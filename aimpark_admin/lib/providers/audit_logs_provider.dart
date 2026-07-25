import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/constants/api_endpoints.dart';
import '../core/network/dio_client.dart';
import '../models/audit_log_entry.dart';

part 'audit_logs_provider.g.dart';

class AuditLogsQuery {
  final int page;
  final int pageSize;
  final String? action; // null = all

  const AuditLogsQuery({
    this.page = 1,
    this.pageSize = 20,
    this.action,
  });

  AuditLogsQuery copyWith(
          {int? page, int? pageSize, String? action, bool clearAction = false}) =>
      AuditLogsQuery(
        page: page ?? this.page,
        pageSize: pageSize ?? this.pageSize,
        action: clearAction ? null : (action ?? this.action),
      );
}

@riverpod
class AuditLogsQueryNotifier extends _$AuditLogsQueryNotifier {
  @override
  AuditLogsQuery build() => const AuditLogsQuery();

  void setPage(int page) => state = state.copyWith(page: page);
  void setAction(String? action) => state =
      state.copyWith(action: action, clearAction: action == null, page: 1);
}

@riverpod
Future<AuditLogPage> auditLogs(Ref ref) async {
  final query = ref.watch(auditLogsQueryNotifierProvider);
  final dio = ref.watch(dioProvider);

  final params = <String, dynamic>{
    'page': query.page,
    'pageSize': query.pageSize,
    if (query.action != null) 'action': query.action,
  };

  final response = await dio.get(ApiEndpoints.auditLogs, queryParameters: params);
  return AuditLogPage.fromJson(response.data as Map<String, dynamic>);
}
