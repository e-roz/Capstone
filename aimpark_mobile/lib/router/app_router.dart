import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/network/dio_client.dart';
import '../core/utils/jwt_utils.dart';
import '../features/auth/presentation/screens/admin_placeholder_screen.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/auth/presentation/screens/register_documents_screen.dart';
import '../features/auth/presentation/screens/register_email_screen.dart';
import '../features/auth/presentation/screens/register_otp_screen.dart';
import '../features/auth/presentation/screens/register_profile_screen.dart';
import '../features/auth/presentation/screens/register_vehicle_screen.dart';
import '../features/auth/presentation/screens/security_placeholder_screen.dart';
import '../features/auth/presentation/screens/user_placeholder_screen.dart';

part 'app_router.g.dart';

const _storage = FlutterSecureStorage();

bool _isProtectedRoute(String location) {
  return location.startsWith('/home/');
}

@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) async {
      final token = await _storage.read(key: authTokenKey);
      final location = state.matchedLocation;
      final hasValidToken = token != null && JwtUtils.isValid(token);

      if (hasValidToken) {
        final homeRoute = JwtUtils.homeRouteForRole(JwtUtils.getRole(token));

        if (location == '/login') {
          return homeRoute ?? '/login';
        }

        if (_isProtectedRoute(location) && homeRoute != location) {
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
        path: '/login',
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
      GoRoute(
        path: '/register/vehicle',
        builder: (context, state) => const RegisterVehicleScreen(),
      ),
      GoRoute(
        path: '/register/documents',
        builder: (context, state) => const RegisterDocumentsScreen(),
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
        builder: (context, state) => const UserPlaceholderScreen(),
      ),
    ],
  );
}
