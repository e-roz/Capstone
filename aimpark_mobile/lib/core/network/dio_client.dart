import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../router/app_router.dart';
import '../constants/api_constants.dart';
import 'api_endpoints.dart';

part 'dio_client.g.dart';

const authTokenKey = 'auth_token';
const registrationSessionTokenKey = 'registration_session_token';

class DioClient {
  DioClient(this._router) {
    dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        // 60s, not 30s: the API is on Render's free tier, which sleeps after
        // ~15 minutes idle. The first request then has to boot the container,
        // which routinely takes 30-60s and used to fail outright.
        connectTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 60),
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final jwt = await _storage.read(key: authTokenKey);
          if (jwt != null && jwt.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $jwt';
          } else {
            final sessionToken = await _storage.read(
              key: registrationSessionTokenKey,
            );
            if (sessionToken != null && sessionToken.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $sessionToken';
            }
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401 &&
              !_isSignInAttempt(error.requestOptions)) {
            final wasRegistering = _isRegistrationRequest(error.requestOptions);

            await _storage.delete(key: authTokenKey);
            await _storage.delete(key: registrationSessionTokenKey);

            if (wasRegistering) {
              // Registration sessions are short-lived, and someone who was
              // typing an OTP has no account to sign in to yet. Sending them to
              // a sign-in form they cannot use was the app telling them to do
              // something impossible; the flow starts again at the email step,
              // and says why.
              _router.go(
                '/register/email',
                extra: 'Your registration session expired. Enter your email '
                    'again and we will send a new code.',
              );
            } else {
              // Expired session: the user is known to have an account, so drop
              // them on the sign-in form rather than the welcome screen.
              _router.go('/login/sign-in');
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  /// Whether this request *is* an attempt to sign in.
  ///
  /// A 401 from these means the credentials were wrong or the Google token was
  /// not good enough — not that a session expired. They must be left to the
  /// screen that made the call, which can say what went wrong; running the
  /// expiry handling over them would clear storage and navigate away from the
  /// error the user is meant to read.
  static bool _isSignInAttempt(RequestOptions options) {
    const attempts = [ApiEndpoints.login, ApiEndpoints.googleSignIn];
    return attempts.any(options.path.endsWith);
  }

  /// Whether this request was authenticated by a registration session token
  /// rather than by a real JWT.
  ///
  /// The distinction decides where an expired token leaves the user, and it is
  /// exactly the line between "an account exists" and "one does not yet". The
  /// four steps up to and including the profile run on a session token and
  /// create nothing to sign in to — a password is only set at the end of the
  /// last of them. Everything after, the document scan and confirmation
  /// included, runs on a JWT, so an account with credentials is already there
  /// and signing in again is both possible and the shortest way back: the token
  /// it returns names the step to resume at.
  static bool _isRegistrationRequest(RequestOptions options) {
    const sessionEndpoints = [
      ApiEndpoints.initiateEmail,
      ApiEndpoints.verifyEmail,
      ApiEndpoints.resendOtp,
      ApiEndpoints.completeProfile,
    ];
    return sessionEndpoints.any(options.path.endsWith);
  }

  final GoRouter _router;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  late final Dio dio;
}

@Riverpod(keepAlive: true)
Dio dio(Ref ref) {
  final router = ref.watch(appRouterProvider);
  return DioClient(router).dio;
}
