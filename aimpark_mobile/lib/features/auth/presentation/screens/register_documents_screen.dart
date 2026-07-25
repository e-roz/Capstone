import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/api_error_message.dart';
import '../../../../core/utils/app_flushbar.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/celebration_dialog.dart';
import '../providers/auth_provider.dart';
import '../widgets/image_picker_box.dart';
import '../widgets/registration_step_scaffold.dart';

class RegisterDocumentsScreen extends ConsumerStatefulWidget {
  const RegisterDocumentsScreen({super.key});

  @override
  ConsumerState<RegisterDocumentsScreen> createState() =>
      _RegisterDocumentsScreenState();
}

class _RegisterDocumentsScreenState
    extends ConsumerState<RegisterDocumentsScreen> {
  String? _govIdFrontPath;
  String? _govIdBackPath;
  String? _selfiePath;
  String? _orCrPath;
  bool _isLoading = false;

  String? _validate() {
    if (_govIdFrontPath == null) {
      return 'Government ID (front) is required.';
    }
    if (_govIdBackPath == null) {
      return 'Government ID (back) is required.';
    }
    if (_selfiePath == null) {
      return 'Selfie / face photo is required.';
    }
    if (_orCrPath == null) {
      return 'OR-CR document is required.';
    }
    return null;
  }

  Future<void> _submit() async {
    final error = _validate();
    if (error != null) {
      showAppMessage(context, error, isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final formData = FormData.fromMap({
        'License': await MultipartFile.fromFile(_govIdFrontPath!),
        'OR': await MultipartFile.fromFile(_govIdBackPath!),
        'CR': await MultipartFile.fromFile(_orCrPath!),
        'Selfie': await MultipartFile.fromFile(_selfiePath!),
      });

      final repo = ref.read(authRepositoryProvider);
      await repo.uploadDocuments(formData);

      if (mounted) {
        await CelebrationDialog.show(
          context,
          title: "You're all set!",
          message: 'Registration submitted — your account is pending review.',
        );
        if (mounted) context.go('/login');
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
      step: 5,
      title: 'Documents',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Upload documents', style: AppTextStyles.h2),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Please provide clear photos of your identification and vehicle documents.',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),
          ImagePickerBox(
            label: 'Government ID (front)',
            imagePath: _govIdFrontPath,
            onImageSelected: (path) => setState(() => _govIdFrontPath = path),
          ),
          const SizedBox(height: 16),
          ImagePickerBox(
            label: 'Government ID (back)',
            imagePath: _govIdBackPath,
            onImageSelected: (path) => setState(() => _govIdBackPath = path),
          ),
          const SizedBox(height: 16),
          ImagePickerBox(
            label: 'Selfie / face photo',
            imagePath: _selfiePath,
            onImageSelected: (path) => setState(() => _selfiePath = path),
          ),
          const SizedBox(height: 16),
          ImagePickerBox(
            label: 'OR-CR (vehicle registration)',
            imagePath: _orCrPath,
            onImageSelected: (path) => setState(() => _orCrPath = path),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Submit Registration',
            isLoading: _isLoading,
            onPressed: _isLoading ? null : _submit,
          ),
        ],
      ),
    );
  }
}
