import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/api_error_message.dart';
import '../../../../core/utils/app_flushbar.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../providers/account_provider.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = false;
  bool _initialized = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final fullName = _fullNameController.text.trim();
    if (fullName.isEmpty) {
      showAppMessage(context, 'Full name cannot be empty.', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref.read(accountRepositoryProvider).updateProfile(
            fullName: fullName,
            phoneNumber: _phoneController.text.trim().isEmpty
                ? null
                : _phoneController.text.trim(),
          );
      await ref.read(profileNotifierProvider.notifier).refresh();
      if (mounted) {
        showAppMessage(context, 'Profile updated.');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) showAppMessage(context, apiErrorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileNotifierProvider);

    ref.listen(profileNotifierProvider, (previous, next) {
      if (!_initialized && next.hasValue) {
        _initialized = true;
        _fullNameController.text = next.value!.fullName;
        _phoneController.text = next.value!.phoneNumber ?? '';
      }
    });

    if (!_initialized && profileAsync.hasValue) {
      _initialized = true;
      _fullNameController.text = profileAsync.value!.fullName;
      _phoneController.text = profileAsync.value!.phoneNumber ?? '';
    }

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        backgroundColor: AppColors.bgPage,
        elevation: 0,
        title: Text('Edit Profile', style: AppTextStyles.h3),
      ),
      body: SafeArea(
        child: profileAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => const Center(child: Text('Failed to load profile.')),
          data: (_) => Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppTextField(
                  label: 'Full Name',
                  controller: _fullNameController,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Phone Number',
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: 'Save Changes',
                  isLoading: _isLoading,
                  onPressed: _isLoading ? null : _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
