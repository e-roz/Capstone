import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_badge.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../../../core/widgets/app_state_views.dart';
import '../../../../core/widgets/good_standing_meter.dart';
import '../../../../core/widgets/points_counter.dart';
import '../../../../core/widgets/streak_badge.dart';
import '../../../account/presentation/providers/account_provider.dart';
import '../../../parking/data/models/parking_history_entry.dart';
import '../../../parking/presentation/providers/parking_history_provider.dart';
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

  /// Consecutive-day streak, counting back from today, of days with a
  /// parking log and no violation issued that day.
  int _computeStreak(ParkingHistoryResult? history, ViolationListResult? violations) {
    if (history == null) return 0;
    final violationDays = (violations?.violations ?? const <ViolationSummary>[])
        .map((v) => DateTime(v.createdAt.year, v.createdAt.month, v.createdAt.day))
        .toSet();
    final parkedDays = history.logs
        .map((l) => DateTime(l.entryTime.year, l.entryTime.month, l.entryTime.day))
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

  ({double level, String tier}) _computeStanding(ViolationListResult? violations) {
    final count =
        (violations?.violations ?? const <ViolationSummary>[])
            .where((v) => v.status.toLowerCase() != 'dismissed')
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

    // Home draws on three providers at once, so it needs its own answer to
    // "has anything arrived yet". Reading `.valueOrNull` alone — which is what
    // this did — meant the first frame after login rendered a fully populated
    // screen out of three nulls: a greeting to "there", a 0-day streak, 0
    // points, "Not Parked", and a Gold standing tier nobody had earned. All of
    // it then rearranged itself a moment later. `hasValue || hasError` rather
    // than `!isLoading` so a pull-to-refresh keeps showing the data underneath
    // instead of flashing back to skeletons.
    bool settled(AsyncValue<Object?> value) => value.hasValue || value.hasError;
    final isFirstLoad =
        !(settled(profileAsync) && settled(historyAsync) && settled(violationsAsync));

    // Only when nothing at all came back. One failed provider still leaves a
    // useful screen, so it degrades rather than blocking the other two.
    final allFailed = !profileAsync.hasValue &&
        !historyAsync.hasValue &&
        !violationsAsync.hasValue &&
        (profileAsync.hasError || historyAsync.hasError || violationsAsync.hasError);

    if (allFailed) {
      return Scaffold(
        backgroundColor: AppColors.bgPage,
        body: SafeArea(
          child: AppErrorState(
            title: "Couldn't load your dashboard",
            onRetry: () => _refresh(ref),
          ),
        ),
      );
    }

    final history = historyAsync.valueOrNull;
    final violations = violationsAsync.valueOrNull;
    final streakDays = _computeStreak(history, violations);
    final points = _computePoints(history, streakDays);
    final standing = _computeStanding(violations);
    final recentLogs = history?.logs.take(3).toList() ?? const <ParkingHistoryEntry>[];

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _refresh(ref),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xl,
            ),
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
                  onTap: () => context.push('/home/user/parking-slots'),
                ),
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  child: GoodStandingMeter(
                    level: standing.level,
                    tierLabel: standing.tier,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              // Quick Actions carry no data, so they stay live during the first
              // load — there is no reason to make someone wait to report an
              // incident just because their streak hasn't arrived.
              Text('Quick Actions', style: AppTextStyles.h3),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: 'Scan History',
                      style: AppButtonStyle.secondary,
                      onPressed: onNavigateToHistory,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: AppButton(
                      label: 'Report Issue',
                      style: AppButtonStyle.ghost,
                      onPressed: () => context.push('/home/user/incidents/new'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Recent Activity', style: AppTextStyles.h3),
              const SizedBox(height: AppSpacing.sm),
              if (isFirstLoad)
                for (var i = 0; i < 3; i++) ...[
                  const AppSkeleton.block(height: 64),
                  const SizedBox(height: AppSpacing.sm),
                ]
              else if (recentLogs.isEmpty)
                Text(
                  'No parking activity yet.',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                )
              else
                for (final log in recentLogs) ...[
                  _ActivityTile(
                    icon: log.isOpen ? Icons.login_rounded : Icons.logout_rounded,
                    title: log.isOpen
                        ? 'Entered ${log.slotCode ?? 'a slot'}'
                        : 'Exited ${log.slotCode ?? 'a slot'}',
                    subtitle: Formatters.relativeDay(log.entryTime),
                    points: '+10 pts',
                    onTap: log.paymentId == null
                        ? null
                        : () => context.push('/home/user/payments/${log.paymentId}'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
            ],
          ),
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
              Text('Welcome back', style: AppTextStyles.bodySmall),
              Text(name, style: AppTextStyles.h2),
            ],
          ),
        ),
        StreakBadge(days: streakDays),
        const SizedBox(width: AppSpacing.sm),
        PointsCounter(points: points),
      ],
    );
  }
}

class _ParkingStatusCard extends StatelessWidget {
  const _ParkingStatusCard({required this.entry, required this.onTap});

  final ParkingHistoryEntry? entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      color: AppColors.brandDefault,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                entry != null ? 'Currently Parked' : 'Not Parked',
                style: AppTextStyles.labelBold.copyWith(color: AppColors.textOnBrand),
              ),
              if (entry?.slotCode != null)
                AppBadge(label: entry!.slotCode!, tone: AppBadgeTone.success),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            entry != null
                ? 'Since ${Formatters.time(entry!.entryTime)} · '
                    '${Formatters.duration(entry!.duration)}'
                : 'Tap to check live availability',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textOnBrand.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.points,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String points;

  /// Opens the fee for this session. Null while the session is still open,
  /// since no payment exists until the vehicle exits.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.bgSurfaceAlt,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(icon, color: AppColors.textSecondary, size: 20),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(subtitle, style: AppTextStyles.bodySmall),
              ],
            ),
          ),
          Text(
            points,
            style: AppTextStyles.labelBold.copyWith(color: AppColors.successPressed),
          ),
          if (onTap != null)
            const Padding(
              padding: EdgeInsets.only(left: AppSpacing.xs),
              child: Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
                size: 20,
              ),
            ),
        ],
      ),
    );
  }
}
