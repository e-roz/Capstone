import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/network/api_endpoints.dart';
import '../../../core/network/dio_client.dart';

class AuthRepository {
  AuthRepository(this._dio, this._storage);

  final Dio _dio;
  final FlutterSecureStorage _storage;

  Future<void> saveToken(String token) async {
    await _storage.write(key: authTokenKey, value: token);
  }

  Future<void> clearToken() async {
    await _storage.delete(key: authTokenKey);
  }

  Future<String?> getToken() => _storage.read(key: authTokenKey);

  Future<void> saveSessionToken(String token) async {
    await _storage.write(key: registrationSessionTokenKey, value: token);
  }

  Future<void> clearSessionToken() async {
    await _storage.delete(key: registrationSessionTokenKey);
  }

  Future<String?> getSessionToken() =>
      _storage.read(key: registrationSessionTokenKey);

  Future<Response<dynamic>> login(Map<String, dynamic> body) {
    return _dio.post(ApiEndpoints.login, data: body);
  }

  Future<Response<dynamic>> logout() {
    return _dio.delete(ApiEndpoints.logout);
  }

  Future<Response<dynamic>> initiateEmail(Map<String, dynamic> body) {
    return _dio.post(ApiEndpoints.initiateEmail, data: body);
  }

  Future<Response<dynamic>> verifyEmail(Map<String, dynamic> body) {
    return _dio.post(ApiEndpoints.verifyEmail, data: body);
  }

  Future<Response<dynamic>> resendOtp(Map<String, dynamic> body) {
    return _dio.post(ApiEndpoints.resendOtp, data: body);
  }

  Future<Response<dynamic>> completeProfile(Map<String, dynamic> body) {
    return _dio.post(ApiEndpoints.completeProfile, data: body);
  }

  Future<Response<dynamic>> registerVehicle(Map<String, dynamic> body) {
    return _dio.post(ApiEndpoints.registerVehicle, data: body);
  }

  /// Uploads the four photos with what the phone read from each, and gets back
  /// the values for the user to check.
  Future<Response<dynamic>> scanDocuments(FormData formData) {
    return _dio.post(ApiEndpoints.scanDocuments, data: formData);
  }

  /// Commits the values the user agreed to and completes registration.
  Future<Response<dynamic>> confirmDocuments(Map<String, dynamic> body) {
    return _dio.post(ApiEndpoints.confirmDocuments, data: body);
  }

  Future<Response<dynamic>> googleSignIn(String idToken) {
    return _dio.post(ApiEndpoints.googleSignIn, data: {'idToken': idToken});
  }
}
