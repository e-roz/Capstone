import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/utils/app_flushbar.dart';
import '../../../../core/utils/jwt_utils.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../router/registration_back_stack.dart';
import '../../../notifications/presentation/providers/push_registration_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/google_auth_button.dart';
import 'account_status_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.notice});

  /// A line to show above the form, from whatever sent the user here — a
  /// finished password reset, a session that ended while the app was open.
  /// Inline and left up rather than flashed: it is the only thing on the screen
  /// that says which password now works, or why the app is asking again, and a
  /// bar would be gone before the email field had been filled in.
  final ScreenNotice? notice;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isGoogleLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      showAppMessage(
        context,
        'Please enter your email and password.',
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(authRepositoryProvider);
      final response = await repo.login({'email': email, 'password': password});
      final data = response.data as Map<String, dynamic>;
      final token = data['token'] as String?;

      if (token == null || token.isEmpty) {
        throw Exception(data['message']?.toString() ?? 'Login failed.');
      }

      await repo.saveToken(token);

      // Registers this device for push. Must run after the auth token is stored,
      // since the register call is authenticated.
      await ref.read(pushRegistrationProvider.notifier).registerAfterLogin();

      if (mounted) {
        context.go(JwtUtils.routeAfterLogin(token));
      }
    } catch (e) {
      if (mounted && !_showAccountStatusIfBlocked(e)) {
        showApiError(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// A 403 from login is not an error to flash and forget — it means the account
  /// is pending, rejected or suspended, and the body carries the detail that
  /// explains it. Returns true when the status screen was shown.
  bool _showAccountStatusIfBlocked(Object error) {
    if (error is! DioException || error.response?.statusCode != 403) {
      return false;
    }

    final data = error.response?.data;
    if (data is! Map) return false;

    final status = data['registrationStatus'];
    final accountStatus = status is Map
        ? status['accountStatus']?.toString()
        : null;
    if (accountStatus == null) return false;

    final canReapplyRaw = status is Map ? status['canReapplyAt'] : null;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AccountStatusScreen(
          accountStatus: accountStatus,
          message: data['message']?.toString(),
          rejectionReason:
              data['rejectionReason']?.toString() ??
              (status is Map ? status['rejectionReason']?.toString() : null),
          canReapplyAt: canReapplyRaw == null
              ? null
              : DateTime.tryParse(canReapplyRaw.toString()),
        ),
      ),
    );

    return true;
  }

  @override
  Widget build(BuildContext context) {
    final isAnyLoading = _isLoading || _isGoogleLoading;

    return AppScreen(
      // Reached with `go` from the welcome screen, so there is no route
      // beneath this one — the automatic back arrow would render and then do
      // nothing. This goes where the user expects.
      onBack: isAnyLoading ? null : () => context.go('/login'),
      body: AppFormBody(
        children: [
          Center(
            child: Image.asset('assets/images/owl_mascot_head.png', width: 96),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Welcome back',
            textAlign: TextAlign.center,
            style: context.text.displayLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Log in to your AimPark account.',
            textAlign: TextAlign.center,
            style: context.text.bodyMedium
                ?.copyWith(color: context.tokens.text.secondary),
          ),
          const SizedBox(height: AppSpacing.xl),
          if (widget.notice != null) ...[
            AppNotice(
              message: widget.notice!.message,
              intent: widget.notice!.intent,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          AppTextField(
            label: 'Email',
            controller: _emailController,
            enabled: !isAnyLoading,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            prefixIcon: Icons.email_outlined,
          ),
          const SizedBox(height: AppSpacing.md),
          AppPasswordField(
            label: 'Password',
            controller: _passwordController,
            enabled: !isAnyLoading,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            onSubmitted: (_) => isAnyLoading ? null : _login(),
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              // Pushed, not gone to: the way back is the form as it was left,
              // with the email already in it.
              onPressed: isAnyLoading
                  ? null
                  : () => context.push(
                        '/login/forgot-password',
                        extra: _emailController.text.trim(),
                      ),
              child: const Text('Forgot password?'),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'Log in',
            isLoading: _isLoading,
            onPressed: isAnyLoading ? null : _login,
          ),
          const SizedBox(height: AppSpacing.md),
          // Log in, not sign up: with this intent the server refuses an address
          // it has no account for instead of quietly creating one.
          GoogleAuthButton(
            intent: GoogleAuthIntent.login,
            enabled: !isAnyLoading,
            onBusyChanged: (busy) => setState(() => _isGoogleLoading = busy),
          ),
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: TextButton(
              onPressed:
                  isAnyLoading
                      ? null
                      : () => context.startRegistration('/register/email'),
              child: const Text("Don't have an account? Register"),
            ),
          ),
        ],
      ),
    );
  }
}
