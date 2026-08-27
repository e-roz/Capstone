import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/utils/app_flushbar.dart';
import '../../../../core/widgets/widgets.dart';
import '../providers/auth_provider.dart';
import '../providers/registration_provider.dart';
import '../widgets/registration_step_scaffold.dart';

class RegisterOtpScreen extends ConsumerStatefulWidget {
  const RegisterOtpScreen({super.key, this.email});

  final String? email;

  @override
  ConsumerState<RegisterOtpScreen> createState() => _RegisterOtpScreenState();
}

class _RegisterOtpScreenState extends ConsumerState<RegisterOtpScreen> {
  final _otpController = TextEditingController();
  bool _isVerifying = false;
  bool _isResending = false;
  int _resendCooldown = 0;
  Timer? _cooldownTimer;
  String? _otpError;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  @override
  void dispose() {
    _otpController.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  String get _email {
    final extra = widget.email;
    if (extra != null && extra.isNotEmpty) return extra;
    return ref.read(registrationNotifierProvider).email ?? '';
  }

  void _startCooldown() {
    _resendCooldown = 60;
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCooldown <= 1) {
        timer.cancel();
        setState(() => _resendCooldown = 0);
      } else {
        setState(() => _resendCooldown--);
      }
    });
  }

  void _clearOtp() {
    _otpController.clear();
  }

  Future<void> _verify() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      setState(() => _otpError = 'Enter all six digits.');
      return;
    }

    setState(() {
      _otpError = null;
      _isVerifying = true;
    });

    try {
      final repo = ref.read(authRepositoryProvider);
      final response = await repo.verifyEmail({'otp': otp});
      final data = response.data as Map<String, dynamic>;
      final sessionToken = data['sessionToken'] as String?;

      if (sessionToken == null || sessionToken.isEmpty) {
        throw Exception('No session token returned.');
      }

      await repo.saveSessionToken(sessionToken);
      ref
          .read(registrationNotifierProvider.notifier)
          .setRegistrationSessionId(sessionToken);

      if (mounted) {
        context.go('/register/profile');
      }
    } catch (e) {
      if (mounted) {
        showApiError(context, e);
        _clearOtp();
      }
    } finally {
      if (mounted) {
        setState(() => _isVerifying = false);
      }
    }
  }

  Future<void> _resendOtp() async {
    if (_resendCooldown > 0 || _isResending) return;

    setState(() => _isResending = true);

    try {
      final repo = ref.read(authRepositoryProvider);
      final response = await repo.resendOtp({'channel': 1});
      final data = response.data as Map<String, dynamic>;
      final sessionToken = data['sessionToken'] as String?;

      if (sessionToken != null && sessionToken.isNotEmpty) {
        await repo.saveSessionToken(sessionToken);
        ref
            .read(registrationNotifierProvider.notifier)
            .setRegistrationSessionId(sessionToken);
      }

      if (mounted) {
        showAppMessage(context, 'OTP resent to your email.');
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
    final email = _email;
    final t = context.tokens;

    final busy = _isVerifying || _isResending;

    return RegistrationStepScaffold(
      step: 2,
      title: 'Verify Email',
      // A mistyped address is only discoverable here — the code never arrives —
      // so this is exactly the screen that has to be able to go back and fix
      // it. Re-entering the email step issues a fresh session and a fresh code.
      busy: busy,
      onBack: () => context.go('/register/email'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RegistrationStepHeading(
            title: 'Enter OTP',
            subtitle: email.isEmpty ? null : 'OTP sent to $email',
          ),
          PinCodeTextField(
            appContext: context,
            length: 6,
            controller: _otpController,
            keyboardType: TextInputType.number,
            animationType: AnimationType.fade,
            enabled: !_isVerifying,
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
            // Submits as soon as the sixth digit lands. Making someone type six
            // digits and then reach for a button is a step the screen can take
            // for them.
            onCompleted: (_) => _isVerifying ? null : _verify(),
            onChanged: (_) {
              if (_otpError != null) setState(() => _otpError = null);
            },
          ),
          if (_otpError != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              _otpError!,
              style: context.text.labelSmall
                  ?.copyWith(color: t.status.danger.fg),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Verify',
            isLoading: _isVerifying,
            onPressed: _isVerifying ? null : _verify,
          ),
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: TextButton(
              onPressed: (_resendCooldown > 0 || _isResending || _isVerifying)
                  ? null
                  : _resendOtp,
              child: _isResending
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      _resendCooldown > 0
                          ? 'Resend OTP (${_resendCooldown}s)'
                          : 'Resend OTP',
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
