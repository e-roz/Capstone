import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/utils/jwt_utils.dart';
import '../screens/audit_log_screen.dart';
import '../screens/incidents_screen.dart';
import '../screens/login_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/parking_screen.dart';
import '../screens/payments_screen.dart';
import '../screens/pending_registrations_screen.dart';
import '../screens/policy_rules_screen.dart';
import '../screens/registration_detail_screen.dart';
import '../screens/reports_screen.dart';
import '../screens/user_detail_screen.dart';
import '../screens/user_management_screen.dart';
import '../screens/violations_screen.dart';
import '../widgets/admin_shell.dart';

part 'app_router.g.dart';

const _storage = FlutterSecureStorage();

@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  return GoRouter(
    initialLocation: '/pending',
    redirect: (context, state) async {
      final token = await _storage.read(key: 'admin_auth_token');
      final location = state.matchedLocation;
      final isLoggedIn = token != null && JwtUtils.isValid(token);
      final isAdmin = isLoggedIn && JwtUtils.isAdmin(token!);

      if (location == '/login') {
        // If already a valid admin, skip login screen
        return isAdmin ? '/pending' : null;
      }

      // All other routes require admin
      if (!isAdmin) return '/login';

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      // Shell with sidebar nav
      ShellRoute(
        builder: (context, state, child) => AdminShell(child: child),
        routes: [
          GoRoute(
            path: '/pending',
            builder: (context, state) =>
                const PendingRegistrationsScreen(),
          ),
          GoRoute(
            path: '/pending/:userId',
            builder: (context, state) => RegistrationDetailScreen(
              userId: state.pathParameters['userId']!,
            ),
          ),
          GoRoute(
            path: '/users',
            builder: (context, state) => const UserManagementScreen(),
          ),
          GoRoute(
            path: '/users/:userId',
            builder: (context, state) => UserDetailScreen(
              userId: state.pathParameters['userId']!,
            ),
          ),
          GoRoute(
            path: '/audit-logs',
            builder: (context, state) => const AuditLogScreen(),
          ),
          GoRoute(
            path: '/parking',
            builder: (context, state) => const ParkingScreen(),
          ),
          GoRoute(
            path: '/payments',
            builder: (context, state) => const PaymentsScreen(),
          ),
          GoRoute(
            path: '/violations',
            builder: (context, state) => const ViolationsScreen(),
          ),
          GoRoute(
            path: '/policy-rules',
            builder: (context, state) => const PolicyRulesScreen(),
          ),
          GoRoute(
            path: '/incidents',
            builder: (context, state) => const IncidentsScreen(),
          ),
          GoRoute(
            path: '/notifications',
            builder: (context, state) => const NotificationsScreen(),
          ),
          GoRoute(
            path: '/reports',
            builder: (context, state) => const ReportsScreen(),
          ),
        ],
      ),
    ],
  );
}
