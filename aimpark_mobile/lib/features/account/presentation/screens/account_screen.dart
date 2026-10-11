import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/update/update_provider.dart';
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
import '../widgets/access_status_card.dart';

/// The colour a row's icon tile is drawn in. One colour per *topic*, so the
/// screen can be scanned by colour as well as by word: parking and vehicles are
/// blue, money is green, a violation is red, an incident report is amber, and
/// your own account is the brand colour. Green is the money colour rather than
/// the "paid" colour only because the app's mint is distinct from its success
/// green, which keeps a Paid badge from looking like a navigation row.
enum _Topic { brand, parking, money, danger, warning, neutral }

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
    // Counts on the rows, so the two things a user can actually owe are visible
    // without opening either screen. Both degrade to no badge if the list has
    // not arrived — a profile must still render when a side request fails.
    final openViolations =
        (ref.watch(violationsNotifierProvider).valueOrNull?.violations ??
                const <ViolationSummary>[])
            .where((v) => v.isOpen)
            .length;

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

    final themeMode = ref.watch(appThemeModeProvider);
    final version = ref.watch(appPackageInfoProvider).valueOrNull?.version;

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

            // The same card Home shows. It used to vanish when the lookup
            // failed, on the theory that it was a secondary detail — but it is
            // the one status here with a consequence at the gate, and a missing
            // card reads as "nothing to report".
            const Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.gutter),
              child: AccessStatusCard(),
            ),

            // Activity before the account settings: the two things a user can
            // owe — an open violation and an unpaid fee — are the reason they
            // opened this screen. Notifications leads because it is an inbox and
            // the only row that is routinely non-empty.
            const SizedBox(height: AppSpacing.md),
            const AppSectionHeader(title: 'Activity'),
            AppRowGroup(
              children: [
                _TopicRow(
                  topic: _Topic.brand,
                  icon: Icons.notifications_none_rounded,
                  title: 'Notifications',
                  badge: unreadCount == 0
                      ? null
                      : AppStatusBadge(
                          label: '$unreadCount new',
                          intent: StatusIntent.brand,
                        ),
                  onTap: () => context.push('/home/user/notifications'),
                ),
                _TopicRow(
                  topic: _Topic.danger,
                  icon: Icons.gavel_rounded,
                  title: 'Violations',
                  badge: openViolations == 0
                      ? null
                      : AppStatusBadge(
                          label: '$openViolations open',
                          intent: StatusIntent.danger,
                        ),
                  onTap: () => context.push('/home/user/violations'),
                ),
                _TopicRow(
                  topic: _Topic.warning,
                  icon: Icons.report_problem_outlined,
                  title: 'Incident reports',
                  onTap: () => context.push('/home/user/incidents'),
                ),
                _TopicRow(
                  topic: _Topic.parking,
                  icon: Icons.history_rounded,
                  title: 'Parking history',
                  onTap: () => context.push('/home/user/parking-history'),
                ),
                _TopicRow(
                  topic: _Topic.money,
                  icon: Icons.credit_card_rounded,
                  title: 'Payments',
                  badge: balance <= 0
                      ? null
                      : AppStatusBadge(
                          label: '${Formatters.peso(balance)} due',
                          intent: StatusIntent.warning,
                        ),
                  onTap: () => context.push('/home/user/payments'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            const AppSectionHeader(title: 'My account'),
            AppRowGroup(
              children: [
                _TopicRow(
                  topic: _Topic.brand,
                  icon: Icons.person_outline_rounded,
                  title: 'Profile and password',
                  onTap: () => context.push('/home/user/profile/edit'),
                ),
                _TopicRow(
                  topic: _Topic.parking,
                  icon: Icons.directions_car_outlined,
                  title: 'My vehicles',
                  onTap: () => context.push('/home/user/vehicles'),
                ),
                _TopicRow(
                  topic: _Topic.neutral,
                  icon: Icons.help_outline_rounded,
                  title: 'Help and support',
                  onTap: () => context.push('/home/user/support'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            const AppSectionHeader(title: 'Appearance'),
            AppChoiceTiles<ThemeMode>(
              columns: 3,
              options: {for (final m in ThemeMode.values) m: m.label},
              icons: {for (final m in ThemeMode.values) m: m.icon},
              value: themeMode,
              onChanged: (m) =>
                  ref.read(appThemeModeProvider.notifier).set(m),
            ),
            const SizedBox(height: AppSpacing.lg),

            AppButton(
              label: 'Sign out',
              style: AppButtonStyle.ghost,
              onPressed: () => _logout(ref, context),
            ),
            if (version != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'AimPark v$version',
                textAlign: TextAlign.center,
                style: context.text.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A navigation row with a tinted icon tile, coloured by [topic].
class _TopicRow extends StatelessWidget {
  const _TopicRow({
    required this.topic,
    required this.icon,
    required this.title,
    required this.onTap,
    this.badge,
  });

  final _Topic topic;
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    final (bg, fg) = switch (topic) {
      _Topic.brand => (t.brand.subtle, t.brand.subtleText),
      _Topic.parking => (t.accent.subtle, t.accent.subtleText),
      _Topic.money => (t.tertiary.subtle, t.tertiary.subtleText),
      _Topic.danger => (t.status.danger.bg, t.status.danger.fg),
      _Topic.warning => (t.status.warning.bg, t.status.warning.fg),
      _Topic.neutral => (t.surface.muted, t.text.secondary),
    };

    return AppListRow(
      title: title,
      leading: Container(
        width: AppSizes.rowIcon,
        height: AppSizes.rowIcon,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Icon(icon, size: AppSizes.iconMd, color: fg),
      ),
      trailing: badge,
      onTap: onTap,
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
                // Name and email only. A "User" chip used to sit here, but every
                // account has the same role, so it said nothing.
                Text(
                  profile.email,
                  style: context.text.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
