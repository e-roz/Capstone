import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_badge.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../notifications/presentation/providers/push_registration_provider.dart';
import '../../data/models/my_profile.dart';
import '../providers/account_provider.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  Future<void> _logout(WidgetRef ref, BuildContext context) async {
    final repo = ref.read(authRepositoryProvider);

    // Drop this device's push registration first — the endpoint is authenticated,
    // so it has to happen while the token is still valid.
    await ref.read(pushRegistrationProvider.notifier).unregisterOnLogout();

    try {
      await repo.logout();
    } catch (_) {
      // Clear local session even if the server call fails.
    }
    await repo.clearToken();
    await repo.clearSessionToken();
    if (context.mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileNotifierProvider);
    final accessStatusAsync = ref.watch(accessStatusProvider);

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: SafeArea(
        child: profileAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: TextButton(
              onPressed: () => ref.read(profileNotifierProvider.notifier).refresh(),
              child: const Text('Retry'),
            ),
          ),
          data: (profile) {
            return RefreshIndicator(
              onRefresh: () => ref.read(profileNotifierProvider.notifier).refresh(),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xl,
                ),
                children: [
                  Text('Profile', style: AppTextStyles.h2),
                  const SizedBox(height: AppSpacing.lg),
                  _ProfileCard(profile: profile),
                  const SizedBox(height: AppSpacing.md),
                  accessStatusAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (error, _) => const SizedBox.shrink(),
                    data: (status) => _AccessStatusCard(status: status),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text('Account', style: AppTextStyles.h3),
                  const SizedBox(height: AppSpacing.sm),
                  _MenuTile(
                    icon: Icons.edit_rounded,
                    label: 'Edit Profile',
                    onTap: () => context.push('/home/user/profile/edit'),
                  ),
                  _MenuTile(
                    icon: Icons.lock_rounded,
                    label: 'Change Password',
                    onTap: () => context.push('/home/user/profile/change-password'),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text('My Activity', style: AppTextStyles.h3),
                  const SizedBox(height: AppSpacing.sm),
                  _MenuTile(
                    icon: Icons.gavel_rounded,
                    label: 'My Violations',
                    onTap: () => context.push('/home/user/violations'),
                  ),
                  _MenuTile(
                    icon: Icons.payments_rounded,
                    label: 'My Payments',
                    onTap: () => context.push('/home/user/payments'),
                  ),
                  _MenuTile(
                    icon: Icons.report_rounded,
                    label: 'My Incident Reports',
                    onTap: () => context.push('/home/user/incidents'),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _MenuTile(
                    icon: Icons.logout_rounded,
                    label: 'Log Out',
                    onTap: () => _logout(ref, context),
                    tone: AppColors.errorDefault,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.profile});
  final MyProfile profile;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          AppAvatar(name: profile.fullName, size: 56),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(profile.fullName, style: AppTextStyles.h3),
                const SizedBox(height: 2),
                Text(profile.email, style: AppTextStyles.bodySmall),
                const SizedBox(height: 4),
                AppBadge(label: profile.role, tone: AppBadgeTone.accent),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AccessStatusCard extends StatelessWidget {
  const _AccessStatusCard({required this.status});
  final AccessStatus status;

  AppBadgeTone get _tone {
    switch (status.rfidStatus.toLowerCase()) {
      case 'active':
        return AppBadgeTone.success;
      case 'suspended':
        return AppBadgeTone.error;
      default:
        return AppBadgeTone.brand;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Icon(
            status.rfidStatus.toLowerCase() == 'active'
                ? Icons.verified_user_rounded
                : Icons.gpp_bad_rounded,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'RFID Access',
                  style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700),
                ),
                if (status.rfidTagId != null)
                  Text('Tag ${status.rfidTagId}', style: AppTextStyles.bodySmall),
              ],
            ),
          ),
          AppBadge(label: status.rfidStatus, tone: _tone),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.tone,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: GestureDetector(
        onTap: onTap,
        child: AppCard(
          child: Row(
            children: [
              Icon(icon, color: tone ?? AppColors.textSecondary, size: 22),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: tone,
                  ),
                ),
              ),
              if (tone == null)
                const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
