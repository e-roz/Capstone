import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/utils/app_flushbar.dart';
import '../../../../core/widgets/widgets.dart';
import '../providers/auth_provider.dart';

/// Step two of a password reset: the code from the email, and the new password.
///
/// One screen rather than two, because the server takes the code and the new
/// password in a single call — checking the code on its own would need a second
/// endpoint, and would leave a verified-but-unused code sitting in the database
/// for the rest of its ten minutes.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key, required this.email});

  /// The address the code was sent to. Carried from the previous screen because
  /// the reset call identifies the account by it — nothing was issued to hold
  /// it for us, and the six digits alone do not say whose account they are for.
  final String email;

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _otpController = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();

  bool _isSubmitting = false;
  bool _isResending = false;
  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  String? _otpError;

  /// Set on submit rather than while typing, matching Change Password: telling
  /// someone their password is too short after four characters is noise.
  String? _newError;
  String? _confirmError;

  bool get _busy => _isSubmitting || _isResending;

  @override
  void initState() {
    super.initState();
    // A code was sent immediately before this screen opened, so the wait starts
    // now rather than when the user first reaches for "Resend".
    _startCooldown();
  }

  @override
  void dispose() {
    _otpController.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _resendCooldown = 60;
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendCooldown <= 1) {
        timer.cancel();
        setState(() => _resendCooldown = 0);
      } else {
        setState(() => _resendCooldown--);
      }
    });
  }

  Future<void> _submit() async {
    final otp = _otpController.text.trim();
    final newPassword = _newPassword.text;

    setState(() {
      _otpError = otp.length != 6 ? 'Enter all six digits.' : null;
      _newError =
          newPassword.length < 8 ? 'Must be at least 8 characters.' : null;
      _confirmError =
          newPassword != _confirmPassword.text ? 'These do not match.' : null;
    });

    if (_otpError != null || _newError != null || _confirmError != null) return;

    setState(() => _isSubmitting = true);

    try {
      await ref.read(authRepositoryProvider).resetPassword(
            email: widget.email,
            otp: otp,
            newPassword: newPassword,
          );

      if (mounted) {
        // Replaces the stack rather than popping back through the code screen,
        // and carries the reason it is there — a bar would be gone before
        // someone reading it had finished typing their email.
        context.go(
          '/login/sign-in',
          extra: const ScreenNotice(
            'Password reset. Log in with your new password.',
            intent: StatusIntent.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showApiError(context, e);
        // Every rejection here — wrong code, expired code, too many tries —
        // leaves six digits on screen that cannot be submitted again. Clearing
        // them is the next thing the user would do anyway.
        _otpController.clear();
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _resend() async {
    if (_resendCooldown > 0 || _busy) return;

    setState(() => _isResending = true);

    try {
      await ref.read(authRepositoryProvider).forgotPassword(widget.email);

      if (mounted) {
        showAppMessage(context, 'A new code is on its way to ${widget.email}.');
        _otpController.clear();
        _startCooldown();
      }
    } catch (e) {
      if (mounted) {
        showApiError(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return AppScreen(
      title: 'Reset Password',
      body: AppFormBody(
        children: [
          Text(
            'Enter your code',
            textAlign: TextAlign.center,
            style: context.text.displayLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'If ${widget.email} has an AimPark account, a six-digit code is on '
            'its way. It expires in 10 minutes.',
            textAlign: TextAlign.center,
            style: context.text.bodyMedium?.copyWith(color: t.text.secondary),
          ),
          const SizedBox(height: AppSpacing.xl),
          PinCodeTextField(
            appContext: context,
            length: 6,
            controller: _otpController,
            keyboardType: TextInputType.number,
            animationType: AnimationType.fade,
            enabled: !_isSubmitting,
            textStyle: context.text.bodyLarge,
            pinTheme: PinTheme(
              shape: PinCodeFieldShape.box,
              borderRadius: AppRadius.mdAll,
              fieldHeight: 48,
              fieldWidth: 44,
              activeFillColor: t.surface.card,
              selectedFillColor: t.surface.card,
              inactiveFillColor: t.surface.card,
              activeColor: t.brand.primary,
              selectedColor: t.border.focus,
              inactiveColor: t.border.normal,
              borderWidth: 1.5,
            ),
            enableActiveFill: true,
            // Deliberately not submitting on the sixth digit, unlike the
            // registration OTP: there are two more fields below this one, and
            // the code is the first of the three things this screen needs.
            onChanged: (_) {
              if (_otpError != null) setState(() => _otpError = null);
            },
          ),
          if (_otpError != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              _otpError!,
              style:
                  context.text.labelSmall?.copyWith(color: t.status.danger.fg),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          AppPasswordField(
            label: 'New Password',
            controller: _newPassword,
            enabled: !_isSubmitting,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.newPassword],
            errorText: _newError,
            helperText: 'At least 8 characters.',
          ),
          const SizedBox(height: AppSpacing.md),
          AppPasswordField(
            label: 'Confirm New Password',
            controller: _confirmPassword,
            enabled: !_isSubmitting,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.newPassword],
            errorText: _confirmError,
            onSubmitted: (_) => _isSubmitting ? null : _submit(),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Reset password',
            isLoading: _isSubmitting,
            onPressed: _isSubmitting ? null : _submit,
          ),
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: TextButton(
              onPressed: (_resendCooldown > 0 || _busy) ? null : _resend,
              child: _isResending
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      _resendCooldown > 0
                          ? 'Resend code (${_resendCooldown}s)'
                          : 'Resend code',
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
