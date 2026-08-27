import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../account/presentation/providers/account_provider.dart';
import '../../../parking/data/models/parking_history_entry.dart';
import '../../../parking/data/models/parking_slot.dart';
import '../../../parking/presentation/providers/parking_history_provider.dart';
import '../../../payments/data/models/payment.dart';
import '../../../payments/presentation/providers/payments_provider.dart';
import '../../../violations/data/models/violation.dart';
import '../../../violations/presentation/providers/violations_provider.dart';

/// Home tab body inside [UserShell]. Streak/points/standing are derived
/// client-side from real parking history and violation data — there's no
/// dedicated Points/Streak entity in the backend, so these are honest
/// computations over real rows rather than a stored game-score.
class UserDashboardScreen extends ConsumerWidget {
  const UserDashboardScreen({super.key, required this.onNavigateToHistory});

  /// Switches the parent [UserShell] to the History tab.
  final VoidCallback onNavigateToHistory;

  /// Whether a violation still counts against the user.
  ///
  /// `Overturned` is what a *won appeal* leaves behind, and `Dismissed` is an
  /// admin dropping the violation outright. Both mean the user did nothing
  /// wrong, so neither may cost them anything.
  ///
  /// Only `Dismissed` was excluded before. A user who appealed and won watched
  /// their standing stay at Bronze and their streak stay broken, which made
  /// winning the appeal look like losing it — and is exactly the complaint
  /// testers raised.
  static bool _countsAgainstUser(ViolationSummary v) {
    final status = v.status.toLowerCase();
    return status != 'dismissed' && status != 'overturned';
  }

  /// Whether a violation is still open — issued, or under appeal — and so is
  /// something the user has to do something about.
  ///
  /// `Upheld` is closed: the appeal was heard and lost, and there is nothing
  /// left to act on but the fee, which the balance covers separately.
  static bool _isOpen(ViolationSummary v) {
    final status = v.status.toLowerCase();
    return status == 'issued' || status == 'appealed';
  }

  /// Consecutive-day streak, counting back from today, of days with a
  /// parking log and no violation issued that day.
  int _computeStreak(
    ParkingHistoryResult? history,
    ViolationListResult? violations,
  ) {
    if (history == null) return 0;
    final violationDays = (violations?.violations ?? const <ViolationSummary>[])
        .where(_countsAgainstUser)
        .map((v) =>
            DateTime(v.createdAt.year, v.createdAt.month, v.createdAt.day))
        .toSet();
    final parkedDays = history.logs
        .map((l) =>
            DateTime(l.entryTime.year, l.entryTime.month, l.entryTime.day))
        .toSet();

    var streak = 0;
    var cursor = DateTime.now();
    cursor = DateTime(cursor.year, cursor.month, cursor.day);
    while (parkedDays.contains(cursor) && !violationDays.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  /// +10 per logged parking session, +50 per full week of streak.
  int _computePoints(ParkingHistoryResult? history, int streakDays) {
    if (history == null) return 0;
    return history.totalCount * 10 + (streakDays ~/ 7) * 50;
  }

  ({double level, String tier}) _computeStanding(
    ViolationListResult? violations,
  ) {
    final count = (violations?.violations ?? const <ViolationSummary>[])
        .where(_countsAgainstUser)
        .length;
    if (count == 0) return (level: 1.0, tier: 'Gold');
    if (count == 1) return (level: 0.65, tier: 'Silver');
    return (level: 0.3, tier: 'Bronze');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileNotifierProvider);
    final historyAsync = ref.watch(parkingHistoryNotifierProvider);
    final violationsAsync = ref.watch(violationsNotifierProvider);
    final paymentsAsync = ref.watch(paymentsNotifierProvider);
    // Availability is the one number people open this app for, and the card was
    // spending its whole surface telling them to tap to go and find it.
    final availability = ref.watch(parkingAvailabilityProvider).valueOrNull;

    // Home draws on three providers at once, so it needs its own answer to
    // "has anything arrived yet" rather than the single-provider AsyncView the
    // other screens use. Reading `.valueOrNull` alone — which is what this did
    // — meant the first frame after login rendered a fully populated screen out
    // of three nulls: a greeting to "there", a 0-day streak, 0 points, "Not
    // Parked", and a Gold standing tier nobody had earned. All of it then
    // rearranged itself a moment later. `hasValue || hasError` rather than
    // `!isLoading` so a pull-to-refresh keeps showing the data underneath
    // instead of flashing back to skeletons.
    bool settled(AsyncValue<Object?> value) => value.hasValue || value.hasError;
    final isFirstLoad = !(settled(profileAsync) &&
        settled(historyAsync) &&
        settled(violationsAsync));

    // Only when nothing at all came back. One failed provider still leaves a
    // useful screen, so it degrades rather than blocking the other two.
    final allFailed = !profileAsync.hasValue &&
        !historyAsync.hasValue &&
        !violationsAsync.hasValue &&
        (profileAsync.hasError ||
            historyAsync.hasError ||
            violationsAsync.hasError);

    if (allFailed) {
      return AppScreen.tab(
        body: RefreshIndicator(
          onRefresh: () => _refresh(ref),
          child: RefreshableCenter(
            child: AppErrorState(
              title: "Couldn't load your dashboard",
              onRetry: () => _refresh(ref),
            ),
          ),
        ),
      );
    }

    final history = historyAsync.valueOrNull;
    final violations = violationsAsync.valueOrNull;
    final streakDays = _computeStreak(history, violations);
    final points = _computePoints(history, streakDays);
    final standing = _computeStanding(violations);

    // A violation the user never sees is a violation they cannot appeal. It
    // used to arrive as a push and then live only in the Alerts tab and two
    // taps down inside Profile, so anyone who missed the push found out when
    // their card stopped opening the gate. It now sits on the first screen.
    final openViolations = (violations?.violations ?? const <ViolationSummary>[])
        .where(_isOpen)
        .length;
    final unpaid = (paymentsAsync.valueOrNull?.payments ?? const <Payment>[])
        .where((p) => p.status.toLowerCase() == 'pending')
        .toList();
    final balance = unpaid.fold<double>(0, (sum, p) => sum + p.amountDue);
    final overdueCount = unpaid.where((p) => p.isOverdue).length;

    final recentLogs =
        history?.logs.take(3).toList() ?? const <ParkingHistoryEntry>[];

    return AppScreen.tab(
      body: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: ListView(
          padding: kScreenListPadding,
          children: [
            if (isFirstLoad) ...[
              const _HeaderSkeleton(),
              const SizedBox(height: AppSpacing.lg),
              const AppSkeleton.block(height: 92),
              const SizedBox(height: AppSpacing.md),
              const AppSkeleton.block(height: 72),
            ] else ...[
              _Header(
                name: profileAsync.valueOrNull?.fullName ?? 'there',
                streakDays: streakDays,
                points: points,
              ),
              const SizedBox(height: AppSpacing.lg),
              _ParkingStatusCard(
                entry: history?.currentlyParked,
                availability: availability,
                onTap: () => context.push('/home/user/parking-slots'),
              ),
              const SizedBox(height: AppSpacing.md),
              AppCard(
                child: GoodStandingMeter(
                  level: standing.level,
                  tierLabel: standing.tier,
                ),
              ),
              if (openViolations > 0 || balance > 0) ...[
                const SizedBox(height: AppSpacing.lg),
                const AppSectionHeader(title: 'Needs your attention'),
                if (openViolations > 0)
                  AppListRow(
                    icon: Icons.gavel_rounded,
                    intent: StatusIntent.warning,
                    title: openViolations == 1
                        ? '1 open violation'
                        : '$openViolations open violations',
                    subtitle: 'Tap to read it or file an appeal.',
                    onTap: () => context.push('/home/user/violations'),
                  ),
                if (openViolations > 0 && balance > 0) const AppRowGap(),
                if (balance > 0)
                  AppListRow(
                    icon: Icons.payments_rounded,
                    intent: overdueCount > 0
                        ? StatusIntent.danger
                        : StatusIntent.warning,
                    title: '${Formatters.peso(balance)} unpaid',
                    subtitle: overdueCount > 0
                        ? '$overdueCount overdue'
                        : '${unpaid.length} pending payment(s)',
                    onTap: () => context.push('/home/user/payments'),
                  ),
              ],
            ],
            const SizedBox(height: AppSpacing.lg),

            // Quick Actions carry no data, so they stay live during the first
            // load — there is no reason to make someone wait to report an
            // incident just because their streak hasn't arrived.
            //
            // Six tiles rather than the two buttons that were here. Vehicles,
            // violations and payments were reachable only by going to Profile
            // and scrolling, which is why a screen with half the app on it
            // still looked like it did nothing. A tile is also honest about
            // being a shortcut, where the two buttons read as *the* actions of
            // the screen — and one of them was labelled "Scan History", which
            // sounded like it wanted the camera.
            const AppSectionHeader(title: 'Quick Actions'),
            _QuickActions(
              actions: [
                (
                  icon: Icons.local_parking_rounded,
                  label: 'Find a slot',
                  onTap: () => context.push('/home/user/parking-slots'),
                ),
                (
                  icon: Icons.history_rounded,
                  label: 'History',
                  onTap: onNavigateToHistory,
                ),
                (
                  icon: Icons.directions_car_rounded,
                  label: 'Vehicles',
                  onTap: () => context.push('/home/user/vehicles'),
                ),
                (
                  icon: Icons.gavel_rounded,
                  label: 'Violations',
                  onTap: () => context.push('/home/user/violations'),
                ),
                (
                  icon: Icons.payments_rounded,
                  label: 'Payments',
                  onTap: () => context.push('/home/user/payments'),
                ),
                (
                  icon: Icons.report_rounded,
                  label: 'Report',
                  onTap: () => context.push('/home/user/incidents/new'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            const AppSectionHeader(title: 'Recent Activity'),
            if (isFirstLoad)
              const AppRowSkeleton(count: 3)
            else if (recentLogs.isEmpty)
              // The same empty state every other list uses. A bare line of grey
              // text was the one place in the app where "nothing here" was not
              // drawn as anything.
              const AppEmptyState(
                icon: Icons.local_parking_rounded,
                title: 'No parking yet',
                message: 'Your entries and exits will show up here.',
              )
            else
              for (final log in recentLogs) ...[
                AppListRow(
                  icon: log.isOpen
                      ? Icons.login_rounded
                      : Icons.logout_rounded,
                  title: log.isOpen
                      ? 'Entered ${log.slotCode ?? 'a slot'}'
                      : 'Exited ${log.slotCode ?? 'a slot'}',
                  subtitle: Formatters.relativeDay(log.entryTime),
                  dense: true,
                  trailing: Text(
                    '+10 pts',
                    style: context.text.labelMedium?.copyWith(
                      color: context.tokens.status.success.fg,
                    ),
                  ),
                  // Opens the fee for this session. Null while the session is
                  // still open, since no payment exists until the vehicle exits.
                  onTap: log.paymentId == null
                      ? null
                      : () =>
                          context.push('/home/user/payments/${log.paymentId}'),
                ),
                if (log != recentLogs.last) const AppRowGap(),
              ],
          ],
        ),
      ),
    );
  }

  /// Home reads three providers; a pull-to-refresh here should reload all of
  /// them, not just one, or the card and the meter disagree with each other.
  Future<void> _refresh(WidgetRef ref) async {
    await Future.wait([
      ref.read(profileNotifierProvider.notifier).refresh(),
      ref.read(parkingHistoryNotifierProvider.notifier).refresh(),
      ref.read(violationsNotifierProvider.notifier).refresh(),
      ref.read(paymentsNotifierProvider.notifier).refresh(),
      ref.refresh(parkingAvailabilityProvider.future),
    ]);
  }
}

/// Mirrors [_Header]'s layout so the row doesn't jump when the real name,
/// streak and points land.
class _HeaderSkeleton extends StatelessWidget {
  const _HeaderSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        AppSkeleton(width: 44, height: 44, radius: AppRadius.full),
        SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppSkeleton.line(width: 88, height: 11),
              SizedBox(height: 6),
              AppSkeleton.line(width: 150, height: 18),
            ],
          ),
        ),
        AppSkeleton(width: 52, height: 30, radius: AppRadius.full),
        SizedBox(width: AppSpacing.sm),
        AppSkeleton(width: 52, height: 30, radius: AppRadius.full),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.name,
    required this.streakDays,
    required this.points,
  });

  final String name;
  final int streakDays;
  final int points;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AppAvatar(name: name),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Welcome back', style: context.text.bodySmall),
              Text(
                name,
                style: context.text.headlineMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        // Hidden at zero rather than shown as "0". Two chips reading nought is
        // a greeting that tells a new user they have achieved nothing, and it
        // was the first thing on the screen.
        if (streakDays > 0) ...[
          StreakBadge(days: streakDays),
          const SizedBox(width: AppSpacing.sm),
        ],
        if (points > 0) PointsCounter(points: points),
      ],
    );
  }
}

/// The one full-bleed brand surface on the screen. Everything inside it reads
/// from `brand.onSolid` rather than the ordinary text tokens — on an orange
/// card those would be near-black in light mode and near-white in dark, and
/// only one of those is readable.
class _ParkingStatusCard extends StatelessWidget {
  const _ParkingStatusCard({
    required this.entry,
    required this.availability,
    required this.onTap,
  });

  final ParkingHistoryEntry? entry;

  /// Null until the slot counts arrive, or if that request failed. The card
  /// falls back to its old prompt rather than showing a wrong number.
  final ParkingAvailability? availability;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final isParked = entry != null;
    final free = availability?.availableSlots;

    return AppCard(
      onTap: onTap,
      color: t.brand.primary,
      borderColor: t.brand.pressed,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Not "Not Parked". This is the loudest surface on the screen,
              // and it was spending that on a fact the user already knew. When
              // they are not parked, the thing they came to find out is how
              // many slots are free.
              Text(
                isParked
                    ? 'Currently Parked'
                    : free == null
                        ? 'Parking'
                        : free == 0
                            ? 'Lot is full'
                            : free == 1
                                ? '1 slot free'
                                : '$free slots free',
                style: context.text.labelLarge
                    ?.copyWith(color: t.brand.onSolid),
              ),
              if (entry?.slotCode != null)
                AppStatusBadge(
                  label: entry!.slotCode!,
                  intent: StatusIntent.success,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            isParked
                ? Formatters.sessionRange(
                    entry!.entryTime,
                    null,
                    entry!.duration,
                  )
                : availability == null
                    ? 'Tap to check live availability'
                    : 'of ${availability!.totalSlots} · tap to find yours',
            style: context.text.bodyMedium
                ?.copyWith(color: t.text.onDarkMuted),
          ),
        ],
      ),
    );
  }
}

/// The shortcut grid under "Quick Actions".
///
/// Three to a row on any phone width, wrapping as many rows as it needs. A
/// [GridView] would need its own scroll physics disabled and a fixed aspect
/// ratio guessed; [Wrap] over a computed tile width does the same job and lets
/// a long label wrap instead of clipping.
class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.actions});

  final List<({IconData icon, String label, VoidCallback onTap})> actions;

  @override
  Widget build(BuildContext context) {
    const perRow = 3;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth -
                AppSpacing.controlGap * (perRow - 1)) /
            perRow;

        return Wrap(
          spacing: AppSpacing.controlGap,
          runSpacing: AppSpacing.controlGap,
          children: [
            for (final action in actions)
              SizedBox(
                width: width,
                child: _QuickAction(
                  icon: action.icon,
                  label: action.label,
                  onTap: action.onTap,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.md,
        horizontal: AppSpacing.sm,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppSizes.iconLg, color: t.brand.primary),
          const SizedBox(height: AppSpacing.sm),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.text.labelMedium,
          ),
        ],
      ),
    );
  }
}
