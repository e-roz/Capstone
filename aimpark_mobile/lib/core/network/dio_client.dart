import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../router/app_router.dart';
import '../constants/api_constants.dart';

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
          if (error.response?.statusCode == 401) {
            await _storage.delete(key: authTokenKey);
            await _storage.delete(key: registrationSessionTokenKey);
            // Expired session: the user is known to have an account, so drop
            // them on the sign-in form rather than the welcome screen.
            _router.go('/login/sign-in');
          }
          handler.next(error);
        },
      ),
    );
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
