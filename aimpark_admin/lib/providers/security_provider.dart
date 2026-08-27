import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/constants/api_endpoints.dart';
import '../core/network/dio_client.dart';
import '../models/security.dart';

part 'security_provider.g.dart';

/// The card the guard is currently looking at, or null when the box is empty.
///
/// Held in a provider rather than in the screen so the lookup result and the
/// entry/exit buttons that act on it cannot disagree about which card is in
/// hand — they read the same value.
@riverpod
class GateTagQuery extends _$GateTagQuery {
  @override
  String? build() => null;

  void set(String? tag) =>
      state = (tag == null || tag.trim().isEmpty) ? null : tag.trim();

  void clear() => state = null;
}

@riverpod
Future<TagLookup?> gateTagLookup(Ref ref) async {
  final tag = ref.watch(gateTagQueryProvider);
  if (tag == null) return null;

  final dio = ref.watch(dioProvider);
  final response = await dio.get(ApiEndpoints.securityTagLookup(tag));
  return TagLookup.fromJson(response.data as Map<String, dynamic>);
}

class VisitorPassQuery {
  final int page;
  final int pageSize;

  /// Active, Returned, Expired, or null for all.
  final String? status;

  const VisitorPassQuery({this.page = 1, this.pageSize = 20, this.status});

  VisitorPassQuery copyWith({
    int? page,
    int? pageSize,
    String? status,
    bool clearStatus = false,
  }) =>
      VisitorPassQuery(
        page: page ?? this.page,
        pageSize: pageSize ?? this.pageSize,
        status: clearStatus ? null : (status ?? this.status),
      );
}

@riverpod
class VisitorPassQueryNotifier extends _$VisitorPassQueryNotifier {
  @override
  VisitorPassQuery build() => const VisitorPassQuery(status: 'Active');

  void setPage(int page) => state = state.copyWith(page: page);

  void setStatus(String? status) => state = state.copyWith(
        status: status,
        clearStatus: status == null,
        page: 1,
      );
}

@riverpod
Future<VisitorPassListPage> visitorPassList(Ref ref) async {
  final query = ref.watch(visitorPassQueryNotifierProvider);
  final dio = ref.watch(dioProvider);

  final response = await dio.get(ApiEndpoints.visitorPasses, queryParameters: {
    'page': query.page,
    'pageSize': query.pageSize,
    if (query.status != null) 'status': query.status,
  });

  return VisitorPassListPage.fromJson(response.data as Map<String, dynamic>);
}

/// How many cards are out right now — for the sidebar badge and the dashboard.
@riverpod
Future<int> visitorsOnSiteCount(Ref ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get(ApiEndpoints.visitorPasses, queryParameters: {
    'page': 1,
    'pageSize': 1,
    'status': 'Active',
  });
  return VisitorPassListPage.fromJson(response.data as Map<String, dynamic>)
      .totalCount;
}

@riverpod
class VisitorPassActions extends _$VisitorPassActions {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<String?> issue({
    required String rfidTagId,
    required String visitorName,
    required String plateNumber,
    required String vehicleType,
    String? purpose,
    String? contactNumber,
    int? validForHours,
  }) async {
    return _run(() async {
      final dio = ref.read(dioProvider);
      final res = await dio.post(ApiEndpoints.visitorPasses, data: {
        'rfidTagId': rfidTagId,
        'visitorName': visitorName,
        'plateNumber': plateNumber,
        'vehicleType': vehicleType,
        if (purpose != null && purpose.isNotEmpty) 'purpose': purpose,
        if (contactNumber != null && contactNumber.isNotEmpty)
          'contactNumber': contactNumber,
        'validForHours': ?validForHours,
      });
      final data = res.data as Map<String, dynamic>;
      final name = data['visitorName']?.toString();
      return name == null ? 'Pass issued.' : 'Card issued to $name.';
    });
  }

  Future<String?> returnPass(String passId) async {
    return _run(() async {
      final dio = ref.read(dioProvider);
      final res = await dio.post(ApiEndpoints.returnVisitorPass(passId));
      return (res.data as Map<String, dynamic>)['message']?.toString() ??
          'Card returned.';
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
      if (data is Map) {
        return data['message']?.toString() ?? e.message ?? 'Error';
      }
      return e.message ?? 'Unknown error';
    }
  }
}
