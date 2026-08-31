import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/auth/presentation/providers/registration_provider.dart';
import '../../features/notifications/presentation/providers/push_registration_provider.dart';
import '../../router/app_router.dart';
import '../../router/registration_back_stack.dart';
import '../constants/api_constants.dart';
import '../theme/theme.dart';
import '../widgets/widgets.dart';
import 'api_endpoints.dart';

part 'dio_client.g.dart';

const authTokenKey = 'auth_token';
const registrationSessionTokenKey = 'registration_session_token';

/// What the server says is wrong when it refuses a token.
///
/// The app has to tell two things apart that look identical over the wire: a
/// token that simply ran out, which one sign-in fixes, and an account that has
/// been archived or suspended, which signing in will not fix at all. Matching
/// on the sentence would break the first time anyone reworded it, so the API
/// sends a code beside it.
const _accountUnavailableCode = 'account_unavailable';
const _accountBlockedCode = 'account_blocked';

class DioClient {
  DioClient(this._router, this._resetLocalState) {
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
              !_isSignInAttempt(error.requestOptions) &&
              // Screens load several things at once, so their 401s arrive
              // together. The first one ends the session; the rest would only
              // clear cleared storage and navigate somewhere the app already
              // is, replacing the explanation with an identical one.
              !_isAtTheWayIn) {
            await _endSession(error);
          }
          handler.next(error);
        },
      ),
    );
  }

  /// Whether the app is already showing the way back in.
  bool get _isAtTheWayIn {
    final location =
        _router.routerDelegate.currentConfiguration.uri.toString();
    return location == '/login' || location.startsWith('/login/');
  }

  /// Clears the session this request was made with and says why on the screen
  /// the user lands on.
  ///
  /// An archived account used to be invisible from in here: the token stayed
  /// signed and valid for the rest of its hour, so the app carried on as if
  /// nothing had happened. Now the server refuses it, and this is what the
  /// refusal has to look like from the user's side — signed out, back at the
  /// start, and told which of the two reasons it was.
  Future<void> _endSession(DioException error) async {
    final wasRegistering = _isRegistrationRequest(error.requestOptions);

    final body = error.response?.data;
    final code = body is Map ? body['code']?.toString() : null;
    final serverReason = body is Map ? body['message']?.toString() : null;
    // A 401 with nothing in it is still a 401 — from a proxy, or from a request
    // that carried no token at all. The user is signed out either way and is
    // owed a sentence rather than a status code.
    final reason = serverReason == null || serverReason.isEmpty
        ? 'Your session has ended. Please sign in again.'
        : serverReason;

    await _storage.delete(key: authTokenKey);
    await _storage.delete(key: registrationSessionTokenKey);

    // Whatever path was walked to get here belongs to a session that no longer
    // exists. Back out of wherever this lands and the welcome screen is where
    // it goes.
    registrationBackStack.clear();

    if (wasRegistering) {
      registrationBackStack.record('/login');
      // Registration sessions are short-lived, and someone who was typing an
      // OTP has no account to sign in to yet. Sending them to a sign-in form
      // they cannot use was the app telling them to do something impossible;
      // the flow starts again at the email step, and says why.
      _router.go(
        '/register/email',
        extra: 'Your registration session expired. Enter your email again and '
            'we will send a new code.',
      );
      return;
    }

    // The account itself is gone or barred. There is nothing to sign back in
    // to, so the app is put back to how it opens for someone who has never used
    // it — drafts, cached screens and push registration included — and the
    // reason is left on the welcome screen.
    if (code == _accountUnavailableCode || code == _accountBlockedCode) {
      _resetLocalState();
      _router.go(
        '/login',
        extra: ScreenNotice(reason, intent: StatusIntent.danger),
      );
      return;
    }

    // Just an expired token: the user is known to have an account, so drop them
    // on the sign-in form rather than the welcome screen.
    _router.go(
      '/login/sign-in',
      extra: ScreenNotice(reason, intent: StatusIntent.warning),
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

  /// Empties everything this device remembers about whoever was signed in.
  final void Function() _resetLocalState;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  late final Dio dio;
}

@Riverpod(keepAlive: true)
Dio dio(Ref ref) {
  final router = ref.watch(appRouterProvider);
  return DioClient(router, () {
    // The screens' own providers die with the screens as the app navigates
    // away. These two outlive them: a half-finished registration draft, and
    // this device's push registration with its listeners.
    ref.read(registrationNotifierProvider.notifier).startFresh();
    ref.invalidate(pushRegistrationProvider);
  }).dio;
}
