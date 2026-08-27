import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/utils/app_flushbar.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/widgets.dart';
import '../providers/auth_provider.dart';

/// Step one of a password reset: name the account.
///
/// The server answers identically for an address it knows and one it does not,
/// so this screen cannot report "no such account" and does not try. It moves on
/// to the code screen either way, and says as much before sending, so someone
/// who mistyped their address is not left waiting on an email that was never
/// addressed to them.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key, this.email});

  /// Prefills the field with whatever was already typed on the sign-in form.
  final String? email;

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  late final TextEditingController _emailController =
      TextEditingController(text: widget.email ?? '');
  bool _isLoading = false;
  String? _emailError;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  bool _validate() {
    final email = _emailController.text.trim();

    final error = email.isEmpty
        ? 'Enter the email address on your account.'
        : !isValidEmail(email)
            ? "That doesn't look like an email address."
            : null;

    setState(() => _emailError = error);
    return error == null;
  }

  Future<void> _sendCode() async {
    if (!_validate()) return;

    final email = _emailController.text.trim();
    setState(() => _isLoading = true);

    try {
      await ref.read(authRepositoryProvider).forgotPassword(email);

      if (mounted) {
        context.push('/login/reset-password', extra: email);
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
    return AppScreen(
      title: 'Forgot Password',
      body: AppFormBody(
        children: [
          Text(
            'Reset your password',
            textAlign: TextAlign.center,
            style: context.text.displayLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Enter the email on your account and we will send a six-digit code '
            'to it.',
            textAlign: TextAlign.center,
            style: context.text.bodyMedium
                ?.copyWith(color: context.tokens.text.secondary),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppTextField(
            label: 'Email',
            controller: _emailController,
            enabled: !_isLoading,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.email],
            prefixIcon: Icons.email_outlined,
            errorText: _emailError,
            onChanged: (_) {
              if (_emailError != null) setState(() => _emailError = null);
            },
            onSubmitted: (_) => _isLoading ? null : _sendCode(),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Send reset code',
            isLoading: _isLoading,
            onPressed: _isLoading ? null : _sendCode,
          ),
          const SizedBox(height: AppSpacing.lg),
          // A Google account has no AimPark password, so the code is never sent
          // for one — and since the response cannot say so, the screen has to.
          // Without this the only symptom is an email that never arrives.
          const AppNotice(
            message: 'Signed up with Google? There is no AimPark password to '
                'reset — use Continue with Google on the sign-in screen.',
          ),
        ],
      ),
    );
  }
}
