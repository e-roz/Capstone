import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../notifications/presentation/providers/notifications_provider.dart';
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

    // Notifications lost its tab in the nav change, so this row is now the only
    // place inside Account that can show the count. The shell still badges the
    // Account tab itself, which is what keeps unread alerts visible from the
    // other three tabs.
    final unreadCount =
        ref.watch(notificationsNotifierProvider).valueOrNull?.unreadCount ?? 0;

    return AppScreen.tab(
      body: AsyncView(
        value: ref.watch(profileNotifierProvider),
        onRefresh: () => ref.read(profileNotifierProvider.notifier).refresh(),
        errorTitle: "Couldn't load your profile",
        data: (profile) => ListView(
          padding: kScreenListPadding,
          children: [
            const AppScreenTitle(
              title: 'Account',
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

            // Activity before Settings: the two things a user can owe — an open
            // violation and an unpaid fee — are the reason they opened this
            // screen. Editing a profile is not.
            const SizedBox(height: AppSpacing.md),
            const AppSectionHeader(title: 'Activity'),
            AppRowGroup(
              children: [
                AppListRow(
                  title: 'Violations',
                  trailing: openViolations == 0
                      ? null
                      : AppStatusBadge(
                          label: '$openViolations open',
                          intent: StatusIntent.danger,
                        ),
                  onTap: () => context.push('/home/user/violations'),
                ),
                AppListRow(
                  title: 'Parking history',
                  onTap: () => context.push('/home/user/parking-history'),
                ),
                AppListRow(
                  title: 'Payments',
                  trailing: balance <= 0
                      ? null
                      : AppStatusBadge(
                          label: '${Formatters.peso(balance)} due',
                          intent: StatusIntent.warning,
                        ),
                  onTap: () => context.push('/home/user/payments'),
                ),
                AppListRow(
                  title: 'Incident reports',
                  onTap: () => context.push('/home/user/incidents'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            const AppSectionHeader(title: 'Settings'),
            AppRowGroup(
              children: [
                AppListRow(
                  title: 'Edit profile',
                  onTap: () => context.push('/home/user/profile/edit'),
                ),
                AppListRow(
                  title: 'Change password',
                  onTap: () => context.push('/home/user/profile/change-password'),
                ),
                AppListRow(
                  title: 'My vehicles',
                  onTap: () => context.push('/home/user/vehicles'),
                ),
                AppListRow(
                  title: 'How standing works',
                  onTap: () => context.push('/home/user/standing'),
                ),
                AppListRow(
                  title: 'Help & support',
                  onTap: () => context.push('/home/user/support'),
                ),
                AppListRow(
                  title: 'Notifications',
                  trailing: unreadCount == 0
                      ? null
                      : AppStatusBadge(
                          label: '$unreadCount new',
                          intent: StatusIntent.brand,
                        ),
                  onTap: () => context.push('/home/user/notifications'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            AppButton(
              label: 'Sign out',
              style: AppButtonStyle.ghost,
              onPressed: () => _logout(ref, context),
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

