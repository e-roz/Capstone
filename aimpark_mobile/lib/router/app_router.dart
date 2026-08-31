import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/network/dio_client.dart';
import '../core/utils/jwt_utils.dart';
import '../core/widgets/widgets.dart';
import '../features/auth/presentation/screens/admin_on_web_screen.dart';
import '../features/auth/presentation/screens/forgot_password_screen.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/auth/presentation/screens/register_document_step_screen.dart';
import '../features/auth/presentation/screens/register_email_screen.dart';
import '../features/auth/presentation/screens/register_otp_screen.dart';
import '../features/auth/presentation/screens/register_profile_screen.dart';
import '../features/auth/presentation/screens/reset_password_screen.dart';
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
import '../features/vehicles/presentation/screens/add_vehicle_screen.dart';
import '../features/vehicles/presentation/screens/vehicles_screen.dart';
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
        // A registration-only token is not a session. It carries the role the
        // account will have once it is approved, so routing on the role alone
        // let it through to the dashboard — where every request fails and
        // nothing leads back to the unfinished step. It is good for the
        // registration flow and for the way out of it, and nowhere else.
        if (JwtUtils.isRegistrationOnly(token)) {
          // Already inside the flow, and moving between its steps. Sending them
          // to the step the token names would undo every forward move, since
          // that claim only advances when the server issues a new token.
          if (location.startsWith('/register/')) return null;

          // Leaving the flow on purpose: back out of its first step, or go and
          // sign in as somebody else. Bouncing these straight back to the step
          // the token names is what made the back arrow look broken — the
          // screen simply never changed. Nothing is lost by allowing it, since
          // the token still names the step and signing in again returns to it.
          if (location == '/login' || location.startsWith('/login/')) {
            return null;
          }

          return JwtUtils.routeAfterLogin(token);
        }

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
        // `extra` is why the app is back here rather than where the user left
        // it — an account archived out from under a signed-in session, most of
        // all. The first screen of the app has to account for itself when it is
        // not the first thing the user did.
        builder: (context, state) =>
            WelcomeScreen(notice: ScreenNotice.from(state.extra)),
      ),
      GoRoute(
        path: '/login/sign-in',
        // `extra` is a line to show above the form — a finished password reset
        // explaining that the password just set is the one to type, or an
        // expired session explaining why the app is asking again.
        builder: (context, state) =>
            LoginScreen(notice: ScreenNotice.from(state.extra)),
      ),
      GoRoute(
        path: '/login/forgot-password',
        // Whatever was already typed on the sign-in form, so the address is not
        // entered twice.
        builder: (context, state) =>
            ForgotPasswordScreen(email: state.extra as String?),
      ),
      GoRoute(
        path: '/login/reset-password',
        // The address is the only thing tying the code to an account, and it is
        // carried in `extra` rather than the path so it stays out of logs and
        // out of the back stack. Reached any other way there is nothing to
        // reset, so the flow starts where it should.
        redirect: (context, state) =>
            state.extra is String ? null : '/login/forgot-password',
        builder: (context, state) =>
            ResetPasswordScreen(email: state.extra! as String),
      ),
      GoRoute(
        path: '/register/email',
        // `extra` carries the reason the flow was sent back here — an expired
        // registration session, most often. Shown on the screen rather than
        // flashed, because the user has to start the step again and deserves to
        // know why the OTP they were about to type stopped working.
        builder: (context, state) =>
            RegisterEmailScreen(notice: state.extra as String?),
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
      // Administration is the web panel's job. An Admin can still sign in
      // here, so the route exists to tell them where to go rather than to
      // leave them on a dead end.
      GoRoute(
        path: '/home/admin',
        builder: (context, state) => const AdminOnWebScreen(),
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
        path: '/home/user/vehicles',
        builder: (context, state) => const VehiclesScreen(),
      ),
      // Pushed rather than gone to, so finishing pops back to the list and the
      // newly added vehicle is the first thing seen.
      GoRoute(
        path: '/home/user/vehicles/add',
        builder: (context, state) => const AddVehicleScreen(),
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
