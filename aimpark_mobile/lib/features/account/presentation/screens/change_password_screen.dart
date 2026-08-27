import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/utils/app_flushbar.dart';
import '../../../../core/widgets/widgets.dart';
import '../providers/account_provider.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _isLoading = false;

  /// Set on submit rather than while typing: telling someone their password is
  /// too short after four characters, while they are still typing it, is noise.
  String? _newError;
  String? _confirmError;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final current = _current.text;
    final newPassword = _new.text;
    final confirm = _confirm.text;

    setState(() {
      _newError = newPassword.length < 8
          ? 'Must be at least 8 characters.'
          : null;
      _confirmError =
          newPassword != confirm ? 'These do not match.' : null;
    });

    if (current.isEmpty) {
      showAppMessage(context, 'Enter your current password.', isError: true);
      return;
    }
    if (_newError != null || _confirmError != null) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(accountRepositoryProvider).changePassword(
            currentPassword: current,
            newPassword: newPassword,
          );
      if (mounted) {
        showAppMessage(context, 'Password changed.');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: 'Change Password',
      body: ListView(
        padding: kScreenListPadding,
        children: [
          AppPasswordField(
            label: 'Current Password',
            controller: _current,
            enabled: !_isLoading,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.password],
          ),
          const SizedBox(height: AppSpacing.md),
          AppPasswordField(
            label: 'New Password',
            controller: _new,
            enabled: !_isLoading,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.newPassword],
            errorText: _newError,
            // Stated up front rather than only after a rejected submit — the
            // rule was previously invisible until you got it wrong.
            helperText: 'At least 8 characters.',
          ),
          const SizedBox(height: AppSpacing.md),
          AppPasswordField(
            label: 'Confirm New Password',
            controller: _confirm,
            enabled: !_isLoading,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.newPassword],
            errorText: _confirmError,
            onSubmitted: (_) => _isLoading ? null : _submit(),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Update Password',
            isLoading: _isLoading,
            onPressed: _isLoading ? null : _submit,
          ),
        ],
      ),
    );
  }
}
