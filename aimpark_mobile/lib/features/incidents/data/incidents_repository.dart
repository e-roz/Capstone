import 'package:dio/dio.dart';

import '../../../core/network/api_endpoints.dart';
import 'models/incident.dart';

class IncidentsRepository {
  IncidentsRepository(this._dio);

  final Dio _dio;

  Future<IncidentListResult> list({int page = 1, int pageSize = 20}) async {
    final response = await _dio.get(
      ApiEndpoints.incidents,
      queryParameters: {'page': page, 'pageSize': pageSize},
    );
    return IncidentListResult.fromJson(response.data as Map<String, dynamic>);
  }

  Future<IncidentDetail> getDetail(String incidentId) async {
    final response = await _dio.get(ApiEndpoints.incidentDetail(incidentId));
    return IncidentDetail.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> create({
    required String category,
    required String description,
    String? location,
    List<String> evidencePaths = const [],
  }) async {
    final formData = FormData.fromMap({
      'Category': category,
      'Description': description,
      if (location != null && location.isNotEmpty) 'Location': location,
    });
    for (final path in evidencePaths) {
      formData.files.add(MapEntry('Evidence', await MultipartFile.fromFile(path)));
    }
    await _dio.post(ApiEndpoints.incidents, data: formData);
  }
}
