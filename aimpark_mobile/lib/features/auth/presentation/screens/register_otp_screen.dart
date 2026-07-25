import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/api_error_message.dart';
import '../../../../core/utils/app_flushbar.dart';
import '../../../../core/widgets/app_button.dart';
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
      showAppMessage(context, 'Please enter the 6-digit OTP.', isError: true);
      return;
    }

    setState(() => _isVerifying = true);

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
        showAppMessage(context, apiErrorMessage(e), isError: true);
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
        showAppMessage(context, apiErrorMessage(e), isError: true);
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

    return RegistrationStepScaffold(
      step: 2,
      title: 'Verify Email',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Enter OTP', style: AppTextStyles.h2),
          const SizedBox(height: AppSpacing.xs),
          if (email.isNotEmpty)
            Text(
              'OTP sent to $email',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
            ),
          const SizedBox(height: AppSpacing.lg),
          PinCodeTextField(
            appContext: context,
            length: 6,
            controller: _otpController,
            keyboardType: TextInputType.number,
            animationType: AnimationType.fade,
            pinTheme: PinTheme(
              shape: PinCodeFieldShape.box,
              borderRadius: BorderRadius.circular(AppRadius.md),
              fieldHeight: 48,
              fieldWidth: 44,
              activeFillColor: AppColors.bgSurface,
              selectedFillColor: AppColors.bgSurface,
              inactiveFillColor: AppColors.bgSurface,
              activeColor: AppColors.brandDefault,
              selectedColor: AppColors.brandDefault,
              inactiveColor: AppColors.borderDefault,
              borderWidth: 1.5,
            ),
            enableActiveFill: true,
            onChanged: (_) {},
          ),
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
                      style: AppTextStyles.labelBold.copyWith(
                        fontSize: 14,
                        color: AppColors.brandPressed,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
