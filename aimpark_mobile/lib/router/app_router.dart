import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/network/dio_client.dart';
import '../core/utils/jwt_utils.dart';
import '../features/auth/presentation/screens/admin_placeholder_screen.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/auth/presentation/screens/ocr_debug_screen.dart';
import '../features/auth/presentation/screens/register_document_step_screen.dart';
import '../features/auth/presentation/screens/register_email_screen.dart';
import '../features/auth/presentation/screens/register_otp_screen.dart';
import '../features/auth/presentation/screens/register_profile_screen.dart';
import '../features/account/presentation/screens/change_password_screen.dart';
import '../features/account/presentation/screens/edit_profile_screen.dart';
import '../features/auth/presentation/screens/security_placeholder_screen.dart';
import '../features/auth/presentation/screens/welcome_screen.dart';
import '../features/splash/presentation/screens/splash_screen.dart';
import '../features/dashboard/presentation/widgets/user_shell.dart';
import '../features/incidents/presentation/screens/incident_detail_screen.dart';
import '../features/incidents/presentation/screens/incidents_list_screen.dart';
import '../features/incidents/presentation/screens/report_incident_screen.dart';
import '../features/parking/presentation/screens/parking_slots_screen.dart';
import '../features/payments/presentation/screens/payment_detail_screen.dart';
import '../features/payments/presentation/screens/payments_list_screen.dart';
import '../features/violations/presentation/screens/violation_detail_screen.dart';
import '../features/violations/presentation/screens/violations_list_screen.dart';

part 'app_router.g.dart';

const _storage = FlutterSecureStorage();

bool _isProtectedRoute(String location) {
  return location.startsWith('/home/');
}

@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) async {
      final location = state.matchedLocation;

      if (location == '/splash') {
        return null;
      }

      final token = await _storage.read(key: authTokenKey);
      final hasValidToken = token != null && JwtUtils.isValid(token);

      if (hasValidToken) {
        final homeRoute = JwtUtils.homeRouteForRole(JwtUtils.getRole(token));

        // Covers both the welcome screen and the sign-in form under it — an
        // already-authenticated user has no business on either.
        if (location == '/login' || location.startsWith('/login/')) {
          return homeRoute ?? '/login';
        }

        final withinOwnHomeArea =
            homeRoute != null &&
            (location == homeRoute || location.startsWith('$homeRoute/'));

        if (_isProtectedRoute(location) && !withinOwnHomeArea) {
          return homeRoute ?? '/login';
        }

        return null;
      }

      if (_isProtectedRoute(location)) {
        return '/login';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/login/sign-in',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register/email',
        builder: (context, state) => const RegisterEmailScreen(),
      ),
      GoRoute(
        path: '/register/otp',
        builder: (context, state) {
          final email = state.extra as String?;
          return RegisterOtpScreen(email: email);
        },
      ),
      GoRoute(
        path: '/register/profile',
        builder: (context, state) => const RegisterProfileScreen(),
      ),
      // One document per screen. The index selects which, so the flow can send
      // someone straight back to the single document that needs another
      // photograph rather than to the start of the set.
      GoRoute(
        path: '/register/documents/:index',
        builder: (context, state) {
          final index = int.tryParse(state.pathParameters['index'] ?? '') ?? 0;
          return RegisterDocumentStepScreen(
            index: index.clamp(0, 3),
            retakeMessage: state.extra as String?,
          );
        },
      ),
      // Kept so the old path, and anything still linking to it, lands on the
      // first document instead of nothing at all.
      GoRoute(
        path: '/register/documents',
        redirect: (context, state) => '/register/documents/0',
      ),
      // Not linked from anywhere. Reached by typing the route, to photograph
      // documents and copy the recognition payload out for rule calibration.
      GoRoute(
        path: '/dev/ocr',
        builder: (context, state) => const OcrDebugScreen(),
      ),
      GoRoute(
        path: '/home/admin',
        builder: (context, state) => const AdminPlaceholderScreen(),
      ),
      GoRoute(
        path: '/home/security',
        builder: (context, state) => const SecurityPlaceholderScreen(),
      ),
      GoRoute(
        path: '/home/user',
        builder: (context, state) => const UserShell(),
      ),
      GoRoute(
        path: '/home/user/profile/edit',
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/home/user/profile/change-password',
        builder: (context, state) => const ChangePasswordScreen(),
      ),
      GoRoute(
        path: '/home/user/violations',
        builder: (context, state) => const ViolationsListScreen(),
      ),
      GoRoute(
        path: '/home/user/violations/:violationId',
        builder: (context, state) => ViolationDetailScreen(
          violationId: state.pathParameters['violationId']!,
        ),
      ),
      GoRoute(
        path: '/home/user/payments',
        builder: (context, state) => const PaymentsListScreen(),
      ),
      GoRoute(
        path: '/home/user/payments/:paymentId',
        builder: (context, state) =>
            PaymentDetailScreen(paymentId: state.pathParameters['paymentId']!),
      ),
      GoRoute(
        path: '/home/user/parking-slots',
        builder: (context, state) => const ParkingSlotsScreen(),
      ),
      GoRoute(
        path: '/home/user/incidents',
        builder: (context, state) => const IncidentsListScreen(),
      ),
      GoRoute(
        path: '/home/user/incidents/new',
        builder: (context, state) => const ReportIncidentScreen(),
      ),
      GoRoute(
        path: '/home/user/incidents/:incidentId',
        builder: (context, state) => IncidentDetailScreen(
          incidentId: state.pathParameters['incidentId']!,
        ),
      ),
    ],
  );
}
