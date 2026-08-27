import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/constants/api_endpoints.dart';
import '../core/network/dio_client.dart';
import '../models/incident.dart';

part 'incidents_provider.g.dart';

class IncidentsQuery {
  final int page;
  final int pageSize;
  final String? status;

  const IncidentsQuery({this.page = 1, this.pageSize = 20, this.status});

  IncidentsQuery copyWith(
          {int? page, int? pageSize, String? status, bool clearStatus = false}) =>
      IncidentsQuery(
        page: page ?? this.page,
        pageSize: pageSize ?? this.pageSize,
        status: clearStatus ? null : (status ?? this.status),
      );
}

@riverpod
class IncidentsQueryNotifier extends _$IncidentsQueryNotifier {
  @override
  IncidentsQuery build() => const IncidentsQuery();

  void setPage(int page) => state = state.copyWith(page: page);
  void setStatus(String? status) => state = state.copyWith(
      status: status, clearStatus: status == null, page: 1);
}

@riverpod
Future<IncidentListPage> incidentList(Ref ref) async {
  final query = ref.watch(incidentsQueryNotifierProvider);
  final dio = ref.watch(dioProvider);

  final params = <String, dynamic>{
    'page': query.page,
    'pageSize': query.pageSize,
    if (query.status != null) 'status': query.status,
  };

  final response =
      await dio.get(ApiEndpoints.incidents, queryParameters: params);
  return IncidentListPage.fromJson(response.data as Map<String, dynamic>);
}

/// How many reports nobody has picked up yet.
///
/// Its own request rather than a count off [incidentList], because that list is
/// filtered and paged by whatever the admin last chose — a page showing only
/// resolved reports would report zero waiting, which is the opposite of the
/// truth. `pageSize: 1` because only `totalCount` is read.
@riverpod
Future<int> openIncidentCount(Ref ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get(
    ApiEndpoints.incidents,
    queryParameters: {'page': 1, 'pageSize': 1, 'status': 'Submitted'},
  );
  return IncidentListPage.fromJson(response.data as Map<String, dynamic>)
      .totalCount;
}

@riverpod
Future<IncidentDetail> incidentDetail(Ref ref, String incidentId) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get(ApiEndpoints.incidentDetail(incidentId));
  return IncidentDetail.fromJson(response.data as Map<String, dynamic>);
}

@riverpod
class IncidentActions extends _$IncidentActions {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  /// Files a report as the signed-in staff account.
  ///
  /// Posts to the user-facing route rather than the admin one: an incident a
  /// guard witnesses is the same kind of record as one reported from a phone,
  /// and it should land in the same queue for the same review. `FormData`
  /// because the endpoint reads a multipart form - it accepts photo evidence
  /// from the app, and sends none from here.
  Future<String?> report({
    required String category,
    required String description,
    String? location,
  }) async {
    state = const AsyncLoading();
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.post(
        ApiEndpoints.reportIncident,
        data: FormData.fromMap({
          'Category': category,
          'Description': description,
          if (location != null && location.isNotEmpty) 'Location': location,
        }),
      );
      state = const AsyncData(null);
      return (res.data as Map<String, dynamic>)['message']?.toString() ??
          'Report filed.';
    } on DioException catch (e) {
      state = const AsyncData(null);
      final data = e.response?.data;
      if (data is Map) return data['message']?.toString() ?? e.message ?? 'Error';
      return e.message ?? 'Unknown error';
    }
  }

  Future<String?> review(String incidentId, String status, String? adminNotes) async {
    state = const AsyncLoading();
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.put(ApiEndpoints.reviewIncident(incidentId), data: {
        'status': status,
        'adminNotes': adminNotes,
      });
      state = const AsyncData(null);
      return (res.data as Map<String, dynamic>)['message']?.toString();
    } on DioException catch (e) {
      state = const AsyncData(null);
      final data = e.response?.data;
      if (data is Map) return data['message']?.toString() ?? e.message ?? 'Error';
      return e.message ?? 'Unknown error';
    }
  }
}
