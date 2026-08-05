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

  /// Multipart rather than JSON, so supporting photos ride along with the
  /// reason — reason text alone often cannot settle a dispute. The endpoint
  /// takes [FromForm], so a JSON body would not bind.
  Future<void> submitAppeal(
    String violationId,
    String reasonText, {
    List<String> evidencePaths = const [],
  }) async {
    final formData = FormData.fromMap({'ReasonText': reasonText});
    for (final path in evidencePaths) {
      formData.files.add(MapEntry('Evidence', await MultipartFile.fromFile(path)));
    }
    await _dio.post(ApiEndpoints.violationAppeal(violationId), data: formData);
  }
}
