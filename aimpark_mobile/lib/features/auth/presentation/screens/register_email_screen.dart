import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/utils/app_flushbar.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../router/registration_back_stack.dart';
import '../providers/auth_provider.dart';
import '../providers/registration_provider.dart';
import '../widgets/google_auth_button.dart';
import '../widgets/registration_step_scaffold.dart';

class RegisterEmailScreen extends ConsumerStatefulWidget {
  const RegisterEmailScreen({super.key, this.notice});

  /// Why the flow is starting here rather than because the user chose to.
  ///
  /// Set when an expired registration session sent them back. Shown inline and
  /// left up: a transient bar would be gone before someone who put their phone
  /// down mid-OTP picked it up again, and this is the only thing on the screen
  /// that explains why they lost their place.
  final String? notice;

  @override
  ConsumerState<RegisterEmailScreen> createState() =>
      _RegisterEmailScreenState();
}

class _RegisterEmailScreenState extends ConsumerState<RegisterEmailScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  String? _emailError;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  /// Puts the reason under the field rather than in a bar over it.
  ///
  /// A flushbar names a field the user then has to go and find, and it is gone
  /// by the time they have found it. An error attached to the input says which
  /// one and stays until it is answered.
  bool _validate() {
    final email = _emailController.text.trim();

    final error = email.isEmpty
        ? 'Enter the email address to register with.'
        : !isValidEmail(email)
            ? "That doesn't look like an email address."
            : null;

    setState(() => _emailError = error);
    return error == null;
  }

  Future<void> _sendOtp() async {
    if (!_validate()) return;

    final email = _emailController.text.trim();
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

      final registration = ref.read(registrationNotifierProvider.notifier);
      // Anything still saved belongs to a registration that was abandoned, not
      // to this one.
      registration.startFresh();
      registration.setEmail(email);
      registration.setRegistrationSessionId(sessionToken);

      if (mounted) {
        context.goRegistrationStep('/register/otp', extra: email);
      }
    } catch (e) {
      if (mounted) {
        showApiError(context, e);
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
      busy: _isLoading || _isGoogleLoading,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const RegistrationStepHeading(
            title: 'Enter your email',
            subtitle:
                'We will send a one-time password to verify your email address.',
          ),
          if (widget.notice != null) ...[
            AppNotice(message: widget.notice!, intent: StatusIntent.warning),
            const SizedBox(height: AppSpacing.md),
          ],
          AppTextField(
            label: 'Email',
            controller: _emailController,
            enabled: !_isLoading && !_isGoogleLoading,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.email],
            prefixIcon: Icons.email_outlined,
            errorText: _emailError,
            // Clears the moment they start fixing it. Leaving the error up
            // while someone corrects the address makes the screen look like it
            // has stopped listening.
            onChanged: (_) {
              if (_emailError != null) setState(() => _emailError = null);
            },
            onSubmitted: (_) => _isLoading ? null : _sendOtp(),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Send OTP',
            isLoading: _isLoading,
            onPressed: _isLoading || _isGoogleLoading ? null : _sendOtp,
          ),
          const SizedBox(height: AppSpacing.md),
          // The other way to start. Google has already verified the address, so
          // this skips the OTP entirely and lands on the profile step — which is
          // why it belongs here, level with the email field it replaces, rather
          // than on the welcome screen a step earlier.
          const _OrDivider(),
          const SizedBox(height: AppSpacing.md),
          GoogleAuthButton(
            intent: GoogleAuthIntent.signup,
            enabled: !_isLoading,
            onBusyChanged: (busy) => setState(() => _isGoogleLoading = busy),
          ),
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: TextButton(
              onPressed: _isLoading || _isGoogleLoading
                  ? null
                  : () => context.go('/login/sign-in'),
              child: const Text('Already have an account? Log in'),
            ),
          ),
        ],
      ),
    );
  }
}

/// A rule with "or" set into it, separating two ways of doing the same thing.
///
/// Without it the Google button reads as the next step after sending the OTP
/// rather than as an alternative to it.
class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final line = Expanded(child: Divider(color: t.border.normal, height: 1));

    return Row(
      children: [
        line,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text('or', style: context.text.labelSmall),
        ),
        line,
      ],
    );
  }
}
