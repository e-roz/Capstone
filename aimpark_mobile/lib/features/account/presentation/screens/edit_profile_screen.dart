import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/utils/app_flushbar.dart';
import '../../../../core/widgets/widgets.dart';
import '../../data/models/my_profile.dart';
import '../providers/account_provider.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _fullName = TextEditingController();
  final _phone = TextEditingController();
  bool _isLoading = false;

  /// The form is seeded once, from whichever frame the profile first arrives
  /// in. Seeding on every build would overwrite what the user is typing the
  /// moment anything else invalidated the provider.
  bool _seeded = false;

  @override
  void dispose() {
    _fullName.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _seed(MyProfile profile) {
    if (_seeded) return;
    _seeded = true;
    _fullName.text = profile.fullName;
    _phone.text = profile.phoneNumber ?? '';
  }

  Future<void> _save() async {
    final fullName = _fullName.text.trim();
    if (fullName.isEmpty) {
      showAppMessage(context, 'Full name cannot be empty.', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final phone = _phone.text.trim();
      await ref.read(accountRepositoryProvider).updateProfile(
            fullName: fullName,
            phoneNumber: phone.isEmpty ? null : phone,
          );
      await ref.read(profileNotifierProvider.notifier).refresh();
      if (mounted) {
        showAppMessage(context, 'Profile updated.');
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
      title: 'Edit Profile',
      body: AsyncView(
        value: ref.watch(profileNotifierProvider),
        onRefresh: () => ref.read(profileNotifierProvider.notifier).refresh(),
        // Previously a bare centred `Text('Failed to load profile.')` with no
        // way to try again — the one screen in the app whose failure was a
        // dead end.
        errorTitle: "Couldn't load your profile",
        data: (profile) {
          _seed(profile);

          return ListView(
            padding: kScreenListPadding,
            children: [
              AppTextField(
                label: 'Full Name',
                controller: _fullName,
                enabled: !_isLoading,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'Phone Number',
                controller: _phone,
                enabled: !_isLoading,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.telephoneNumber],
                helperText: 'Optional. Used only if we need to reach you about '
                    'your vehicle.',
                onSubmitted: (_) => _isLoading ? null : _save(),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: 'Save Changes',
                isLoading: _isLoading,
                onPressed: _isLoading ? null : _save,
              ),
            ],
          );
        },
      ),
    );
  }
}
