import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_badge.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/good_standing_meter.dart';
import '../../../../core/widgets/points_counter.dart';
import '../../../../core/widgets/streak_badge.dart';
import '../../../account/presentation/providers/account_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
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

  Future<void> _logout(WidgetRef ref, BuildContext context) async {
    final repo = ref.read(authRepositoryProvider);
    try {
      await repo.logout();
    } catch (_) {
      // Clear local session even if the server call fails.
    }
    await repo.clearToken();
    await repo.clearSessionToken();
    if (context.mounted) context.go('/login');
  }

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

    final history = historyAsync.valueOrNull;
    final violations = violationsAsync.valueOrNull;
    final streakDays = _computeStreak(history, violations);
    final points = _computePoints(history, streakDays);
    final standing = _computeStanding(violations);
    final recentLogs = history?.logs.take(3).toList() ?? const <ParkingHistoryEntry>[];

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xl,
          ),
          children: [
            _Header(
              onLogout: () => _logout(ref, context),
              name: profileAsync.valueOrNull?.fullName ?? 'there',
              streakDays: streakDays,
              points: points,
            ),
            const SizedBox(height: AppSpacing.lg),
            _ParkingStatusCard(entry: history?.currentlyParked),
            const SizedBox(height: AppSpacing.md),
            AppCard(child: GoodStandingMeter(level: standing.level, tierLabel: standing.tier)),
            const SizedBox(height: AppSpacing.lg),
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
            if (recentLogs.isEmpty)
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
                  subtitle: _relativeDay(log.entryTime),
                  points: '+10',
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
          ],
        ),
      ),
    );
  }

  static String _relativeDay(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(time.year, time.month, time.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return '${time.month}/${time.day}/${time.year}';
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.onLogout,
    required this.name,
    required this.streakDays,
    required this.points,
  });

  final VoidCallback onLogout;
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
        IconButton(
          onPressed: onLogout,
          icon: const Icon(Icons.logout_rounded, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _ParkingStatusCard extends StatelessWidget {
  const _ParkingStatusCard({required this.entry});
  final ParkingHistoryEntry? entry;

  String _formatTime(DateTime t) {
    final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final minute = t.minute.toString().padLeft(2, '0');
    final period = t.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes % 60;
    if (hours == 0) return '${minutes}m';
    return '${hours}h ${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/home/user/parking-slots'),
      child: AppCard(
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
            if (entry != null) ...[
              Text(
                'Since ${_formatTime(entry!.entryTime)} · ${_formatDuration(entry!.duration)}',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textOnBrand.withValues(alpha: 0.85),
                ),
              ),
            ] else
              Text(
                'Tap to check live availability',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textOnBrand.withValues(alpha: 0.85),
                ),
              ),
          ],
        ),
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
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String points;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
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
                Text(title, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700)),
                Text(subtitle, style: AppTextStyles.bodySmall),
              ],
            ),
          ),
          Text(
            points,
            style: AppTextStyles.labelBold.copyWith(color: AppColors.successPressed),
          ),
        ],
      ),
    );
  }
}
