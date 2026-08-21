import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/constants/api_endpoints.dart';
import '../core/network/dio_client.dart';
import '../models/rfid_access_log.dart';

part 'rfid_access_logs_provider.g.dart';

class RfidAccessLogsQuery {
  final int page;
  final int pageSize;

  /// "Device", "Manual", or null for both.
  final String? source;

  const RfidAccessLogsQuery({
    this.page = 1,
    this.pageSize = 20,
    this.source,
  });

  RfidAccessLogsQuery copyWith({
    int? page,
    int? pageSize,
    String? source,
    bool clearSource = false,
  }) =>
      RfidAccessLogsQuery(
        page: page ?? this.page,
        pageSize: pageSize ?? this.pageSize,
        source: clearSource ? null : (source ?? this.source),
      );
}

@riverpod
class RfidAccessLogsQueryNotifier extends _$RfidAccessLogsQueryNotifier {
  @override
  RfidAccessLogsQuery build() => const RfidAccessLogsQuery();

  void setPage(int page) => state = state.copyWith(page: page);
  void setSource(String? source) => state =
      state.copyWith(source: source, clearSource: source == null, page: 1);
}

@riverpod
Future<RfidAccessLogPage> rfidAccessLogs(Ref ref) async {
  final query = ref.watch(rfidAccessLogsQueryNotifierProvider);
  final dio = ref.watch(dioProvider);

  final params = <String, dynamic>{
    'page': query.page,
    'pageSize': query.pageSize,
    if (query.source != null) 'source': query.source,
  };

  final response =
      await dio.get(ApiEndpoints.rfidAccessLogs, queryParameters: params);
  return RfidAccessLogPage.fromJson(response.data as Map<String, dynamic>);
}
