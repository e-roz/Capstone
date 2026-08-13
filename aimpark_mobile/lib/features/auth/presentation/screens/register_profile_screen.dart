import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/api_error_message.dart';
import '../../../../core/utils/app_flushbar.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../providers/auth_provider.dart';
import '../providers/registration_provider.dart';
import '../widgets/registration_step_scaffold.dart';
import 'terms_screen.dart';

class RegisterProfileScreen extends ConsumerStatefulWidget {
  const RegisterProfileScreen({super.key});

  @override
  ConsumerState<RegisterProfileScreen> createState() =>
      _RegisterProfileScreenState();
}

class _RegisterProfileScreenState extends ConsumerState<RegisterProfileScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _initialized = false;
  bool _acceptedTerms = false;
  Affiliation _affiliation = Affiliation.student;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
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

    // The server rejects this too — checked here so the user is told before
    // filling in a form and losing it to a 400.
    if (!_acceptedTerms) {
      return 'Please accept the Terms & Conditions to continue.';
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

      final body = <String, dynamic>{
        'fullName': '$firstName $lastName',
        'acceptedTerms': _acceptedTerms,
        'affiliation': _affiliation.wireName,
      };
      if (!isOAuth) {
        body['password'] = _passwordController.text;
      }

      ref.read(registrationNotifierProvider.notifier).setAffiliation(_affiliation);

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
        context.go('/register/documents/0');
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
          // Decides which document proves affiliation at the upload step: a
          // registration form for students, a school ID for everyone else.
          Text('I am a…', style: AppTextStyles.labelBold),
          const SizedBox(height: AppSpacing.sm),
          SegmentedButton<Affiliation>(
            segments: [
              for (final option in Affiliation.values)
                ButtonSegment(value: option, label: Text(option.label)),
            ],
            selected: {_affiliation},
            showSelectedIcon: false,
            onSelectionChanged: (selection) =>
                setState(() => _affiliation = selection.first),
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
          const SizedBox(height: AppSpacing.md),
          _TermsCheckbox(
            value: _acceptedTerms,
            onChanged: (v) => setState(() => _acceptedTerms = v),
            onReadTerms: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const TermsScreen()),
            ),
          ),
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

class _TermsCheckbox extends StatelessWidget {
  const _TermsCheckbox({
    required this.value,
    required this.onChanged,
    required this.onReadTerms,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final VoidCallback onReadTerms;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sized down and de-padded so the checkbox sits level with the first
        // line of text rather than floating above it.
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: value,
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            onChanged: (v) => onChanged(v ?? false),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('I agree to the ', style: AppTextStyles.bodySmall),
                GestureDetector(
                  onTap: onReadTerms,
                  child: Text(
                    'Terms & Conditions',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.brandPressed,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.brandPressed,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
