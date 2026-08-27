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

  /// Asks for a password reset code.
  ///
  /// Succeeds for an address with no account, and for one that signed up with
  /// Google and so has no password to reset. That is deliberate on the server's
  /// side — the response must not tell a stranger which addresses are
  /// registered — so a 200 here means "we have finished looking", not "a code
  /// is on its way".
  Future<Response<dynamic>> forgotPassword(String email) {
    return _dio.post(ApiEndpoints.forgotPassword, data: {'email': email});
  }

  /// Sets a new password using the code from [forgotPassword].
  ///
  /// The email is sent again rather than held in a session: nothing was issued
  /// by the first call, and the code alone does not say whose account it is.
  Future<Response<dynamic>> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) {
    return _dio.post(
      ApiEndpoints.resetPassword,
      data: {'email': email, 'otp': otp, 'newPassword': newPassword},
    );
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

  /// Uploads the four photos with what the phone read from each, and gets back
  /// the values for the user to check.
  Future<Response<dynamic>> scanDocuments(FormData formData) {
    return _dio.post(ApiEndpoints.scanDocuments, data: formData);
  }

  /// Where the account stands, including any documents a reviewer sent back.
  Future<Response<dynamic>> registrationStatus() {
    return _dio.get(ApiEndpoints.registrationStatus);
  }

  /// Commits the values the user agreed to and completes registration.
  Future<Response<dynamic>> confirmDocuments(Map<String, dynamic> body) {
    return _dio.post(ApiEndpoints.confirmDocuments, data: body);
  }

  /// Exchanges a Google ID token for an AimPark token.
  ///
  /// [intent] is `login` or `signup`, and decides one thing: whether an address
  /// with no account gets one created for it. Without it the endpoint always
  /// created, which is why the sign-in screen's Google button was a sign-up
  /// button wearing the wrong label.
  Future<Response<dynamic>> googleSignIn(String idToken, {
    required String intent,
  }) {
    return _dio.post(
      ApiEndpoints.googleSignIn,
      data: {'idToken': idToken, 'intent': intent},
    );
  }
}
