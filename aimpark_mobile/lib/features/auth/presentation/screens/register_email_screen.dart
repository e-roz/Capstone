import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/api_error_message.dart';
import '../../../../core/utils/app_flushbar.dart';
import '../providers/auth_provider.dart';
import '../providers/registration_provider.dart';
import '../widgets/registration_step_scaffold.dart';

class RegisterEmailScreen extends ConsumerStatefulWidget {
  const RegisterEmailScreen({super.key});

  @override
  ConsumerState<RegisterEmailScreen> createState() =>
      _RegisterEmailScreenState();
}

class _RegisterEmailScreenState extends ConsumerState<RegisterEmailScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      showAppMessage(context, 'Please enter your email.', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(authRepositoryProvider);
      final response = await repo.initiateEmail({'email': email});
      final data = response.data as Map<String, dynamic>;
      final sessionToken = data['sessionToken'] as String?;

      if (sessionToken == null || sessionToken.isEmpty) {
        throw Exception('No session token returned.');
      }

      await repo.saveSessionToken(sessionToken);
      ref.read(registrationNotifierProvider.notifier).setEmail(email);
      ref
          .read(registrationNotifierProvider.notifier)
          .setRegistrationSessionId(sessionToken);

      if (mounted) {
        context.go('/register/otp', extra: email);
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
      step: 1,
      title: 'Register',
      showBackButton: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Enter your email',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'We will send a one-time password to verify your email address.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.email_outlined),
            ),
            onSubmitted: (_) => _isLoading ? null : _sendOtp(),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _isLoading ? null : _sendOtp,
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Send OTP'),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: _isLoading ? null : () => context.go('/login'),
            child: const Text('Already have an account? Log in'),
          ),
        ],
      ),
    );
  }
}
