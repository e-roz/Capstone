import 'package:dio/dio.dart';

import '../../../core/network/api_endpoints.dart';
import 'models/my_profile.dart';

class AccountRepository {
  AccountRepository(this._dio);

  final Dio _dio;

  Future<MyProfile> getProfile() async {
    final response = await _dio.get(ApiEndpoints.accountProfile);
    return MyProfile.fromJson(response.data as Map<String, dynamic>);
  }

  Future<AccessStatus> getAccessStatus() async {
    final response = await _dio.get(ApiEndpoints.accessStatus);
    return AccessStatus.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> updateProfile({required String fullName, String? phoneNumber}) {
    return _dio.put(
      ApiEndpoints.accountProfile,
      data: {'fullName': fullName, 'phoneNumber': phoneNumber},
    );
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) {
    return _dio.post(
      ApiEndpoints.changePassword,
      data: {'currentPassword': currentPassword, 'newPassword': newPassword},
    );
  }
}
