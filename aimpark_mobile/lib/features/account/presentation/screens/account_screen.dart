import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../notifications/presentation/providers/push_registration_provider.dart';
import '../../../payments/data/models/payment.dart';
import '../../../payments/presentation/providers/payments_provider.dart';
import '../../../violations/data/models/violation.dart';
import '../../../violations/presentation/providers/violations_provider.dart';
import '../../data/models/my_profile.dart';
import '../providers/account_provider.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  Future<void> _logout(WidgetRef ref, BuildContext context) async {
    final confirmed = await confirmAction(
      context,
      title: 'Log out?',
      message:
          "You'll need to sign in again to check your parking activity.",
      confirmLabel: 'Log Out',
    );
    if (!confirmed || !context.mounted) return;

    final repo = ref.read(authRepositoryProvider);

    // Drop this device's push registration first — the endpoint is
    // authenticated, so it has to happen while the token is still valid.
    await ref.read(pushRegistrationProvider.notifier).unregisterOnLogout();

    try {
      await repo.logout();
    } catch (_) {
      // Clear the local session even if the server call fails.
    }
    await repo.clearToken();
    await repo.clearSessionToken();
    if (context.mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accessStatusAsync = ref.watch(accessStatusProvider);

    // Counts on the rows, so the two things a user can actually owe are visible
    // without opening either screen. Both degrade to no badge if the list has
    // not arrived — a profile must still render when a side request fails.
    final openViolations =
        (ref.watch(violationsNotifierProvider).valueOrNull?.violations ??
                const <ViolationSummary>[])
            .where((v) {
      final status = v.status.toLowerCase();
      return status == 'issued' || status == 'appealed';
    }).length;

    final balance =
        (ref.watch(paymentsNotifierProvider).valueOrNull?.payments ??
                const <Payment>[])
            .where((p) => !p.isPaid && p.status.toLowerCase() != 'waived')
            .fold<double>(0, (sum, p) => sum + p.amountDue);

    return AppScreen.tab(
      body: AsyncView(
        value: ref.watch(profileNotifierProvider),
        onRefresh: () => ref.read(profileNotifierProvider.notifier).refresh(),
        errorTitle: "Couldn't load your profile",
        data: (profile) => ListView(
          padding: kScreenListPadding,
          children: [
            const AppSectionHeader(
              title: 'Profile',
              padding: EdgeInsets.only(bottom: AppSpacing.lg),
            ),
            _ProfileCard(profile: profile),
            const SizedBox(height: AppSpacing.gutter),

            // Degrades to nothing rather than to an error: the RFID card is a
            // secondary detail, and a failed lookup should not put a red block
            // in the middle of a profile that loaded perfectly well.
            accessStatusAsync.maybeWhen(
              data: (status) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.gutter),
                child: _AccessStatusCard(status: status),
              ),
              orElse: () => const SizedBox.shrink(),
            ),

            const SizedBox(height: AppSpacing.md),
            const AppSectionHeader(title: 'Account'),
            AppListRow(
              icon: Icons.edit_rounded,
              title: 'Edit Profile',
              onTap: () => context.push('/home/user/profile/edit'),
            ),
            const AppRowGap(),
            AppListRow(
              icon: Icons.lock_rounded,
              title: 'Change Password',
              onTap: () => context.push('/home/user/profile/change-password'),
            ),
            const AppRowGap(),
            AppListRow(
              icon: Icons.directions_car_rounded,
              title: 'My Vehicles',
              onTap: () => context.push('/home/user/vehicles'),
            ),
            const SizedBox(height: AppSpacing.lg),

            const AppSectionHeader(title: 'My Activity'),
            AppListRow(
              icon: Icons.gavel_rounded,
              title: 'My Violations',
              trailing: openViolations == 0
                  ? null
                  : AppStatusBadge(
                      label: '$openViolations open',
                      intent: StatusIntent.warning,
                    ),
              onTap: () => context.push('/home/user/violations'),
            ),
            const AppRowGap(),
            AppListRow(
              icon: Icons.payments_rounded,
              title: 'My Payments',
              trailing: balance <= 0
                  ? null
                  : AppStatusBadge(
                      label: '${Formatters.peso(balance)} due',
                      intent: StatusIntent.warning,
                    ),
              onTap: () => context.push('/home/user/payments'),
            ),
            const AppRowGap(),
            AppListRow(
              icon: Icons.report_rounded,
              title: 'My Incident Reports',
              onTap: () => context.push('/home/user/incidents'),
            ),
            const SizedBox(height: AppSpacing.lg),

            const AppSectionHeader(title: 'Appearance'),
            const _AppearancePicker(),
            const SizedBox(height: AppSpacing.lg),

            AppListRow(
              icon: Icons.logout_rounded,
              title: 'Log Out',
              tone: context.tokens.status.danger.fg,
              onTap: () => _logout(ref, context),
            ),
          ],
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
                Text(profile.fullName, style: context.text.headlineSmall),
                const SizedBox(height: 2),
                Text(profile.email, style: context.text.bodySmall),
                const SizedBox(height: AppSpacing.xs),
                // Brand rather than info. The role is not a status and carries
                // no warning, and `info` is blue — which made this chip the one
                // blue thing on a screen whose accent is orange, and drew the
                // eye to the least consequential fact on it.
                AppStatusBadge(
                  label: profile.role,
                  intent: StatusIntent.brand,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Whether the card in the user's hand will actually open the gate. Given its
/// own card because it is the one thing on this screen with a consequence.
class _AccessStatusCard extends StatelessWidget {
  const _AccessStatusCard({required this.status});

  final AccessStatus status;

  @override
  Widget build(BuildContext context) {
    // A scheduled suspension reads as "Suspended" from the status alone, but
    // the card still opens the gate and the user can still appeal. Showing that
    // as a flat red "Suspended" would tell them the fight is already lost.
    final pending = status.hasPendingSuspension;

    final intent = pending
        ? StatusIntent.warning
        : StatusIntents.rfid(status.rfidStatus);
    final isActive = intent == StatusIntent.success;

    return AppListRow(
      icon: isActive
          ? Icons.verified_user_rounded
          : pending
              ? Icons.timer_outlined
              : Icons.gpp_bad_rounded,
      intent: intent,
      title: 'RFID Access',
      subtitle: pending
          ? 'Still works until ${Formatters.date(status.suspensionStartsAt!)}. '
              'Appeal your violation before then.'
          : status.rfidTagId == null
              ? null
              : 'Tag ${status.rfidTagId}',
      trailing: AppStatusBadge(
        label: pending ? 'Suspending soon' : status.rfidStatus,
        intent: intent,
      ),
      showChevron: false,
    );
  }
}

/// System / Light / Dark, as a segmented row.
///
/// A three-way choice rather than a switch, because "follow my phone" is a
/// distinct answer from "always light" and a two-state toggle cannot express
/// it — which is how apps end up ignoring a system-wide dark preference the
/// user already set.
class _AppearancePicker extends ConsumerWidget {
  const _AppearancePicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(appThemeModeProvider);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: [
          for (final mode in ThemeMode.values)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: _AppearanceOption(
                  mode: mode,
                  selected: mode == current,
                  onTap: () =>
                      ref.read(appThemeModeProvider.notifier).set(mode),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AppearanceOption extends StatelessWidget {
  const _AppearanceOption({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final ThemeMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final fg = selected ? t.brand.subtleText : t.text.secondary;

    return Semantics(
      button: true,
      selected: selected,
      label: mode.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.standard,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: selected ? t.brand.subtle : Colors.transparent,
            borderRadius: AppRadius.smAll,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(mode.icon, color: fg, size: AppSizes.iconMd),
              const SizedBox(height: 2),
              Text(
                mode.label,
                style: context.text.labelSmall?.copyWith(color: fg),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
