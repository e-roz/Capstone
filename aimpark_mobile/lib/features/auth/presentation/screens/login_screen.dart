import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/api_error_message.dart';
import '../../../../core/utils/app_flushbar.dart';
import '../../../../core/utils/jwt_utils.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../notifications/presentation/providers/push_registration_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/registration_provider.dart';

final _googleSignIn = GoogleSignIn(
  serverClientId:
      '396722417831-3ldllppvag9pccpk9vupf20829f6be4h.apps.googleusercontent.com',
  scopes: ['email', 'profile'],
);

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
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
      showAppMessage(context, 'Please enter your email and password.',
          isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(authRepositoryProvider);
      final response = await repo.login({
        'email': email,
        'password': password,
      });
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
      if (mounted) {
        showAppMessage(context, apiErrorMessage(e), isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _googleLogin() async {
    setState(() => _isGoogleLoading = true);

    try {
      // Trigger the native Google sign-in dialog
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // User cancelled the sign-in sheet
        return;
      }

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        if (mounted) {
          showAppMessage(context, 'Could not obtain Google token. Please try again.',
              isError: true);
        }
        return;
      }

      final repo = ref.read(authRepositoryProvider);
      final response = await repo.googleSignIn(idToken);
      final data = response.data as Map<String, dynamic>;
      final token = data['token'] as String?;

      if (token == null || token.isEmpty) {
        throw Exception(data['message']?.toString() ?? 'Google sign-in failed.');
      }

      await repo.saveToken(token);

      // If the backend issued a registration-only token for a brand-new Google
      // user entering at ProfileSetup, set the OAuth flow flag so
      // RegisterProfileScreen hides the password fields and pre-fills the name.
      if (JwtUtils.isRegistrationOnly(token) &&
          JwtUtils.getRegistrationStep(token) == 'ProfileSetup') {
        final fullName = data['fullName'] as String? ?? googleUser.displayName ?? '';
        ref
            .read(registrationNotifierProvider.notifier)
            .setOAuthFlow(displayName: fullName);
      } else {
        // Only a full auth token can call the authenticated register endpoint —
        // users still mid-registration get registered once they finish and log in.
        await ref.read(pushRegistrationProvider.notifier).registerAfterLogin();
      }

      if (mounted) {
        context.go(JwtUtils.routeAfterLogin(token));
      }
    } on Exception catch (e) {
      final msg = apiErrorMessage(e);
      // HTTP 409 Conflict = email is already a local account
      if (msg.contains('already registered') || msg.contains('password instead')) {
        if (mounted) {
          await showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Account exists'),
              content: const Text(
                'This email is already registered with a password account. '
                'Please log in with your email and password instead.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      } else {
        if (mounted) {
          showAppMessage(context, msg, isError: true);
        }
      }
    } finally {
      // Always sign out of the Google SDK so the picker shows next time
      await _googleSignIn.signOut();
      if (mounted) {
        setState(() => _isGoogleLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAnyLoading = _isLoading || _isGoogleLoading;

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Image.asset(
                      'assets/images/owl_mascot.png',
                      width: 110,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'AimPark',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.displayHero,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Log in to continue',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AppTextField(
                    label: 'Email',
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    prefixIcon: Icons.email_outlined,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    label: 'Password',
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    prefixIcon: Icons.lock_outlined,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                    onSubmitted: (_) => isAnyLoading ? null : _login(),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppButton(
                    label: 'Login',
                    isLoading: _isLoading,
                    onPressed: isAnyLoading ? null : _login,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Row(
                    children: [
                      const Expanded(child: Divider(color: AppColors.borderDefault)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                        child: Text('or', style: AppTextStyles.labelSmall),
                      ),
                      const Expanded(child: Divider(color: AppColors.borderDefault)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppButton(
                    label: 'Continue with Google',
                    style: AppButtonStyle.ghost,
                    isLoading: _isGoogleLoading,
                    icon: const Icon(Icons.g_mobiledata_rounded),
                    onPressed: isAnyLoading ? null : _googleLogin,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Center(
                    child: TextButton(
                      onPressed: isAnyLoading
                          ? null
                          : () => context.go('/register/email'),
                      child: Text(
                        "Don't have an account? Register",
                        style: AppTextStyles.labelBold.copyWith(
                          fontSize: 14,
                          color: AppColors.brandPressed,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
