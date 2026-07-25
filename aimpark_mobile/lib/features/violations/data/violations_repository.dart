import 'package:dio/dio.dart';

import '../../../core/network/api_endpoints.dart';
import 'models/violation.dart';

class ViolationsRepository {
  ViolationsRepository(this._dio);

  final Dio _dio;

  Future<ViolationListResult> list({int page = 1, int pageSize = 20}) async {
    final response = await _dio.get(
      ApiEndpoints.violations,
      queryParameters: {'page': page, 'pageSize': pageSize},
    );
    return ViolationListResult.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ViolationDetail> getDetail(String violationId) async {
    final response = await _dio.get(ApiEndpoints.violationDetail(violationId));
    return ViolationDetail.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> submitAppeal(String violationId, String reasonText) {
    return _dio.post(
      ApiEndpoints.violationAppeal(violationId),
      data: {'reasonText': reasonText},
    );
  }
}
