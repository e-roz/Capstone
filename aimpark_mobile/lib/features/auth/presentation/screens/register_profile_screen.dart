import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/api_error_message.dart';
import '../../../../core/utils/app_flushbar.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../providers/auth_provider.dart';
import '../providers/registration_provider.dart';
import '../widgets/registration_step_scaffold.dart';

class RegisterProfileScreen extends ConsumerStatefulWidget {
  const RegisterProfileScreen({super.key});

  @override
  ConsumerState<RegisterProfileScreen> createState() =>
      _RegisterProfileScreenState();
}

class _RegisterProfileScreenState extends ConsumerState<RegisterProfileScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _initialized = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  /// Pre-fill name fields from Google display name on first render.
  void _maybeInitFromOAuth(RegistrationState regState) {
    if (_initialized) return;
    _initialized = true;
    if (regState.isOAuthFlow && regState.googleDisplayName != null) {
      final parts = regState.googleDisplayName!.trim().split(' ');
      _firstNameController.text = parts.first;
      if (parts.length > 1) {
        _lastNameController.text = parts.sublist(1).join(' ');
      }
    }
  }

  String? _validate(bool isOAuth) {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();

    if (firstName.isEmpty || lastName.isEmpty) {
      return 'First name and last name are required.';
    }

    if (!isOAuth) {
      final password = _passwordController.text;
      final confirmPassword = _confirmPasswordController.text;
      if (password.length < 8) {
        return 'Password must be at least 8 characters.';
      }
      if (password != confirmPassword) {
        return 'Passwords do not match.';
      }
    }

    return null;
  }

  Future<void> _submit(bool isOAuth) async {
    final error = _validate(isOAuth);
    if (error != null) {
      showAppMessage(context, error, isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final firstName = _firstNameController.text.trim();
      final lastName = _lastNameController.text.trim();
      final phone = _phoneController.text.trim();

      final body = <String, dynamic>{
        'fullName': '$firstName $lastName',
      };
      if (!isOAuth) {
        body['password'] = _passwordController.text;
      }
      if (phone.isNotEmpty) {
        body['phoneNumber'] = phone;
      }

      final repo = ref.read(authRepositoryProvider);
      final response = await repo.completeProfile(body);
      final data = response.data as Map<String, dynamic>;
      final token = data['token'] as String?;

      if (token == null || token.isEmpty) {
        throw Exception('No authentication token returned.');
      }

      await repo.saveToken(token);
      await repo.clearSessionToken();
      ref.read(registrationNotifierProvider.notifier).clearSession();

      if (mounted) {
        context.go('/register/vehicle');
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

  @override
  Widget build(BuildContext context) {
    final regState = ref.watch(registrationNotifierProvider);
    final isOAuth = regState.isOAuthFlow;

    // Pre-fill on first build when coming from Google sign-in
    _maybeInitFromOAuth(regState);

    return RegistrationStepScaffold(
      step: 3,
      title: 'Your Profile',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Complete your profile', style: AppTextStyles.h2),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            label: 'First Name',
            controller: _firstNameController,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.givenName],
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: 'Last Name',
            controller: _lastNameController,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.familyName],
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: 'Phone Number (optional)',
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            textInputAction: isOAuth ? TextInputAction.done : TextInputAction.next,
            autofillHints: const [AutofillHints.telephoneNumber],
            prefixIcon: Icons.phone_outlined,
            onSubmitted: isOAuth ? (_) => _isLoading ? null : _submit(true) : null,
          ),
          // Password fields: only shown for local (non-OAuth) registration
          if (!isOAuth) ...[
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Password',
              controller: _passwordController,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newPassword],
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Confirm Password',
              controller: _confirmPasswordController,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.newPassword],
              onSubmitted: (_) => _isLoading ? null : _submit(false),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Continue',
            isLoading: _isLoading,
            onPressed: _isLoading ? null : () => _submit(isOAuth),
          ),
        ],
      ),
    );
  }
}
