import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/utils/app_flushbar.dart';
import '../../../../core/widgets/widgets.dart';
import '../../data/models/my_profile.dart';
import '../providers/account_provider.dart';

/// Who you are and how you sign in, on one screen.
///
/// Edit profile and Change password used to be two screens and two rows on
/// Account. They are merged, but deliberately keep **separate buttons**: saving
/// a name should never depend on typing a password, and a wrong current password
/// should not throw away a name change. The password half is folded away until
/// asked for, so most visits are just the name.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _fullName = TextEditingController();
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();

  bool _savingProfile = false;
  bool _savingPassword = false;
  bool _passwordOpen = false;

  /// The form is seeded once, from whichever frame the profile first arrives
  /// in. Seeding on every build would overwrite what the user is typing the
  /// moment anything else invalidated the provider.
  bool _seeded = false;
  MyProfile? _profile;

  @override
  void initState() {
    super.initState();
    // The buttons enable and the checklist ticks as the user types.
    for (final c in [_fullName, _current, _new, _confirm]) {
      c.addListener(_onTyped);
    }
  }

  @override
  void dispose() {
    _fullName.dispose();
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _onTyped() => setState(() {});

  void _seed(MyProfile profile) {
    _profile = profile;
    if (_seeded) return;
    _seeded = true;
    _fullName.text = profile.fullName;
  }

  bool get _nameChanged {
    final p = _profile;
    final typed = _fullName.text.trim();
    return p != null && typed.isNotEmpty && typed != p.fullName;
  }

  bool get _longEnough => _new.text.length >= 8;
  bool get _matches => _confirm.text.isNotEmpty && _new.text == _confirm.text;
  bool get _passwordReady =>
      _current.text.isNotEmpty && _longEnough && _matches;

  Future<void> _saveProfile() async {
    final fullName = _fullName.text.trim();
    if (fullName.isEmpty) {
      showAppMessage(context, 'Full name cannot be empty.', isError: true);
      return;
    }

    setState(() => _savingProfile = true);
    try {
      await ref.read(accountRepositoryProvider).updateProfile(
            fullName: fullName,
            // Not asked for here any more, but sent back as it was so an
            // existing number is kept rather than wiped by the save.
            phoneNumber: _profile?.phoneNumber,
          );
      await ref.read(profileNotifierProvider.notifier).refresh();
      if (mounted) {
        showAppMessage(context, 'Profile updated.');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  Future<void> _savePassword() async {
    setState(() => _savingPassword = true);
    try {
      await ref.read(accountRepositoryProvider).changePassword(
            currentPassword: _current.text,
            newPassword: _new.text,
          );
      if (mounted) {
        _current.clear();
        _new.clear();
        _confirm.clear();
        setState(() => _passwordOpen = false);
        showAppMessage(context, 'Password changed.');
      }
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _savingPassword = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: 'Profile',
      body: AsyncView(
        value: ref.watch(profileNotifierProvider),
        onRefresh: () => ref.read(profileNotifierProvider.notifier).refresh(),
        errorTitle: "Couldn't load your profile",
        data: (profile) {
          _seed(profile);

          return ListView(
            padding: kScreenListPadding,
            children: [
              Center(child: AppAvatar(name: profile.fullName, size: 64)),
              const SizedBox(height: AppSpacing.md),
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppTextField(
                      label: 'Full name',
                      controller: _fullName,
                      enabled: !_savingProfile,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.name],
                      onSubmitted: (_) =>
                          _nameChanged && !_savingProfile ? _saveProfile() : null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _ReadOnlyField(
                      label: 'Email',
                      value: profile.email,
                      helperText:
                          "Your email is how you sign in, so it can't be "
                          'changed here.',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppButton(
                      label: 'Save changes',
                      isLoading: _savingProfile,
                      onPressed:
                          _nameChanged && !_savingProfile ? _saveProfile : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const AppSectionHeader(title: 'Password'),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _PasswordHeader(
                      open: _passwordOpen,
                      onTap: () =>
                          setState(() => _passwordOpen = !_passwordOpen),
                    ),
                    if (_passwordOpen)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          0,
                          AppSpacing.md,
                          AppSpacing.md,
                        ),
                        child: _passwordForm(),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _passwordForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppPasswordField(
          label: 'Current password',
          controller: _current,
          enabled: !_savingPassword,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.password],
        ),
        const SizedBox(height: AppSpacing.md),
        AppPasswordField(
          label: 'New password',
          controller: _new,
          enabled: !_savingPassword,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.newPassword],
        ),
        if (_new.text.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          PasswordStrengthMeter(password: _new.text),
        ],
        const SizedBox(height: AppSpacing.sm),
        _Check(met: _longEnough, label: 'At least 8 characters'),
        const SizedBox(height: 2),
        _Check(met: _matches, label: 'Matches the confirmation'),
        const SizedBox(height: AppSpacing.md),
        AppPasswordField(
          label: 'Confirm new password',
          controller: _confirm,
          enabled: !_savingPassword,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.newPassword],
          onSubmitted: (_) =>
              _passwordReady && !_savingPassword ? _savePassword() : null,
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: 'Update password',
          style: AppButtonStyle.ghost,
          isLoading: _savingPassword,
          onPressed: _passwordReady && !_savingPassword ? _savePassword : null,
        ),
      ],
    );
  }
}

/// A field that is shown but cannot be edited: greyed, with a lock, so it reads
/// as information rather than as a broken input.
class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({
    required this.label,
    required this.value,
    this.helperText,
  });

  final String label;
  final String value;
  final String? helperText;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return AppFieldShell(
      label: label,
      enabled: false,
      helperText: helperText,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + 4,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value,
                style: context.text.bodyMedium?.copyWith(
                  color: t.text.secondary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.lock_outline_rounded,
              size: AppSizes.iconSm,
              color: t.text.secondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _PasswordHeader extends StatelessWidget {
  const _PasswordHeader({required this.open, required this.onTap});

  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Semantics(
      button: true,
      expanded: open,
      child: InkWell(
        borderRadius: AppRadius.mdAll,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: AppSizes.rowIcon,
                height: AppSizes.rowIcon,
                decoration: BoxDecoration(
                  color: t.brand.subtle,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  Icons.lock_outline_rounded,
                  size: AppSizes.iconMd,
                  color: t.brand.subtleText,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Change password',
                  style: context.text.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(
                open
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
                color: t.text.secondary,
                size: AppSizes.iconLg,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One line of the live password checklist. A tick and a word, so the state is
/// not carried by colour alone.
class _Check extends StatelessWidget {
  const _Check({required this.met, required this.label});

  final bool met;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = met ? t.status.success.fg : t.text.secondary;

    return Row(
      children: [
        Icon(
          met ? Icons.check_circle_outline_rounded : Icons.circle_outlined,
          size: AppSizes.iconSm,
          color: color,
        ),
        const SizedBox(width: AppSpacing.xs + 2),
        Expanded(
          child: Text(
            label,
            style: context.text.bodySmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}
