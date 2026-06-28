import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/api_error_message.dart';
import '../../../../core/utils/app_flushbar.dart';
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

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validate() {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (firstName.isEmpty || lastName.isEmpty) {
      return 'First name and last name are required.';
    }
    if (password.length < 8) {
      return 'Password must be at least 8 characters.';
    }
    if (password != confirmPassword) {
      return 'Passwords do not match.';
    }
    return null;
  }

  Future<void> _submit() async {
    final error = _validate();
    if (error != null) {
      showAppMessage(context, error, isError: true);
      return;
    }

    final sessionId =
        ref.read(registrationNotifierProvider).registrationSessionId;
    if (sessionId == null || sessionId.isEmpty) {
      showAppMessage(
        context,
        'Registration session expired. Please start again.',
        isError: true,
      );
      context.go('/register/email');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final firstName = _firstNameController.text.trim();
      final lastName = _lastNameController.text.trim();
      final phone = _phoneController.text.trim();
      final password = _passwordController.text;

      final body = <String, dynamic>{
        'fullName': '$firstName $lastName',
        'password': password,
      };
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
    return RegistrationStepScaffold(
      step: 3,
      title: 'Your Profile',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Complete your profile',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _firstNameController,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.givenName],
            decoration: const InputDecoration(
              labelText: 'First Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _lastNameController,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.familyName],
            decoration: const InputDecoration(
              labelText: 'Last Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.telephoneNumber],
            decoration: const InputDecoration(
              labelText: 'Phone Number (optional)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.phone_outlined),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.newPassword],
            decoration: InputDecoration(
              labelText: 'Password',
              border: const OutlineInputBorder(),
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
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _confirmPasswordController,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.newPassword],
            decoration: const InputDecoration(
              labelText: 'Confirm Password',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _isLoading ? null : _submit(),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _isLoading ? null : _submit,
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Continue'),
          ),
        ],
      ),
    );
  }
}
