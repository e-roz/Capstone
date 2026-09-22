import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
///
/// Visually this screen deliberately breaks from the rest of the app's flat,
/// bordered-card system: gradient hero card, soft tinted stat cards, a mascot
/// illustration. That is scoped to Home on purpose — every other screen keeps
/// the app-wide token system unchanged.
class UserDashboardScreen extends ConsumerWidget {
  const UserDashboardScreen({
    super.key,
    required this.onNavigateToHistory,
    required this.onNavigateToAlerts,
    this.unreadCount = 0,
  });

  /// Switches the parent [UserShell] to the History tab.
  final VoidCallback onNavigateToHistory;

  /// Switches the parent [UserShell] to the Alerts tab.
  final VoidCallback onNavigateToAlerts;

  /// Drives the header bell's unread dot. Computed once in [UserShell] from
  /// the same provider the Alerts tab reads, so the two never disagree.
  final int unreadCount;

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

  /// Whether a violation should still be holding the standing meter down.
  ///
  /// Narrower than [_countsAgainstUser] by one case: a fine that has been paid
  /// is done with, and leaving it counted meant settling up changed nothing the
  /// user could see — the meter sat on Silver with no way back to Gold.
  ///
  /// The streak deliberately keeps using the wider test. Standing is a running
  /// account that paying squares; the streak is a record of which days went
  /// wrong, and paying afterwards does not make the day go right.
  static bool _countsAgainstStanding(ViolationSummary v) =>
      _countsAgainstUser(v) && !v.isSettled;

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
        .where(_countsAgainstStanding)
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
        .where((p) => !p.isPaid && p.status.toLowerCase() != 'waived')
        .toList();
    final balance = unpaid.fold<double>(0, (sum, p) => sum + p.amountDue);
    final overdueCount = unpaid.where((p) => p.isOverdue).length;
    // The one to name on the dashboard card — "you parked at B-14, here's
    // what that costs" is a claim a bare total can't make on its own.
    final mostRecentUnpaid = unpaid.isEmpty
        ? null
        : (List<Payment>.from(unpaid)
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt)))
            .first;

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
              const AppSkeleton.block(height: 152),
              const SizedBox(height: AppSpacing.md),
              const AppSkeleton.block(height: 116),
            ] else ...[
              _Header(
                name: profileAsync.valueOrNull?.fullName ?? 'there',
                unreadCount: unreadCount,
                onNavigateToAlerts: onNavigateToAlerts,
              ),
              const SizedBox(height: AppSpacing.lg),
              _ParkingHeroCard(
                entry: history?.currentlyParked,
                availability: availability,
                onTap: () => context.push('/home/user/parking-slots'),
              ),
              // A second hero card, only when money is actually owed — this is
              // the thing testers wanted answered the moment the app opens
              // ("did my last session cost me anything"), not three taps into
              // Payments. It replaces what used to be a quiet list row here.
              if (balance > 0) ...[
                const SizedBox(height: AppSpacing.lg),
                _PaymentDueCard(
                  balance: balance,
                  overdueCount: overdueCount,
                  pendingCount: unpaid.length,
                  mostRecent: mostRecentUnpaid,
                  onTap: () => context.push('/home/user/payments'),
                  onPayNow: () => context.push('/home/user/payments/checkout'),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              const AppSectionHeader(title: 'Your week at a glance'),
              _WeekAtAGlance(
                standing: standing,
                streakDays: streakDays,
                points: points,
              ),
              if (openViolations > 0) ...[
                const SizedBox(height: AppSpacing.lg),
                const AppSectionHeader(title: 'Needs your attention'),
                AppCard(
                  onTap: () => context.push('/home/user/violations'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.gavel_rounded,
                            color: context.tokens.status.warning.fg,
                            size: AppSizes.iconMd,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              openViolations == 1
                                  ? '1 open violation'
                                  : '$openViolations open violations',
                              style: context.text.bodyMedium,
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: context.tokens.text.secondary,
                            size: AppSizes.iconMd,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Review and file an appeal if needed.',
                        style: context.text.bodySmall?.copyWith(
                          color: context.tokens.text.secondary,
                        ),
                      ),
                    ],
                  ),
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

/// Mirrors [_Header]'s layout so the row doesn't jump when the real name and
/// avatar land.
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
        AppSkeleton(width: 44, height: 44, radius: AppRadius.full),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.name,
    required this.unreadCount,
    required this.onNavigateToAlerts,
  });

  final String name;
  final int unreadCount;
  final VoidCallback onNavigateToAlerts;

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
        const SizedBox(width: AppSpacing.sm),
        _RoundIconButton(
          icon: Icons.notifications_rounded,
          showDot: unreadCount > 0,
          onTap: onNavigateToAlerts,
        ),
      ],
    );
  }
}

/// A tinted circular icon button, used for the header's bell — the reference's
/// icon-button treatment, in place of the app-wide flat [AppButton].
class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.onTap,
    this.showDot = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: t.brand.subtle, shape: BoxShape.circle),
            child: Icon(icon, color: t.brand.subtleText, size: AppSizes.iconMd),
          ),
          if (showDot)
            Positioned(
              top: 1,
              right: 1,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: t.status.danger.solid,
                  shape: BoxShape.circle,
                  border: Border.all(color: t.surface.canvas, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The hero card — the one full-bleed brand surface on the screen, restyled
/// after the soft-gradient reference: rounded 28, indigo-to-mint gradient, a
/// tag pill, the brand mascot, and a circular arrow CTA in place of the
/// app-wide flat [AppCard]/[AppButton] pairing.
///
/// Everything inside reads from `brand.onSolid` rather than the ordinary text
/// tokens — on a colour-fill card those would be near-black in light mode and
/// near-white in dark, and only one of those is readable.
class _ParkingHeroCard extends StatefulWidget {
  const _ParkingHeroCard({
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
  State<_ParkingHeroCard> createState() => _ParkingHeroCardState();
}

class _ParkingHeroCardState extends State<_ParkingHeroCard> {
  bool _isPressed = false;
  bool _isRefreshing = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final isParked = widget.entry != null;
    final free = widget.availability?.availableSlots;
    final updatedAt = widget.availability?.fetchedAt;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _isPressed ? 0.98 : 1.0,
        duration: AppMotion.press,
        curve: AppMotion.standard,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [t.brand.primary, t.tertiary.primary],
              ),
            ),
            child: Stack(
              children: [
                // The mascot bleeds off the bottom-right corner, matching the
                // reference's hero card illustration treatment.
                Positioned(
                  right: -16,
                  bottom: -18,
                  child: Opacity(
                    opacity: 0.95,
                    child: Image.asset(
                      'assets/images/mascot_wave.png',
                      height: 132,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _Tag(label: isParked ? 'Live' : 'Parking'),
                          if (widget.entry?.slotCode != null)
                            AppStatusBadge(
                              label: widget.entry!.slotCode!,
                              intent: StatusIntent.success,
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        isParked
                            ? 'Currently Parked'
                            : free == null
                                ? 'Checking availability…'
                                : free == 0
                                    ? 'Lot is full'
                                    : free == 1
                                        ? '1 slot free'
                                        : '$free slots free',
                        style: context.text.headlineLarge
                            ?.copyWith(color: t.brand.onSolid, fontSize: 25),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              isParked
                                  ? Formatters.sessionRange(
                                      widget.entry!.entryTime,
                                      null,
                                      widget.entry!.duration,
                                    )
                                  : widget.availability == null
                                      ? 'Tap to check live availability'
                                      : 'of ${widget.availability!.totalSlots} · tap to find yours',
                              style: context.text.bodyMedium
                                  ?.copyWith(color: t.text.onDarkMuted),
                            ),
                          ),
                          if (!isParked && updatedAt != null)
                            Padding(
                              padding: const EdgeInsets.only(left: AppSpacing.sm),
                              child: _RefreshButton(
                                isRefreshing: _isRefreshing,
                                timestamp: updatedAt,
                                onTap: () async {
                                  setState(() => _isRefreshing = true);
                                  await Future.delayed(const Duration(seconds: 1));
                                  setState(() => _isRefreshing = false);
                                },
                              ),
                            ),
                        ],
                      ),
                      // Show freshness timestamp below the main text
                      if (!isParked && updatedAt != null)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.xs),
                          child: Text(
                            'Updated ${_getRelativeTime(updatedAt)}',
                            style: context.text.labelSmall?.copyWith(
                              color: t.text.onDarkMuted,
                            ),
                          ),
                        ),
                      const SizedBox(height: AppSpacing.md),
                      _ArrowButton(background: t.brand.onSolid, iconColor: t.brand.primary),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Format time as "30s ago", "2m ago", etc.
  String _getRelativeTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inSeconds < 60) {
      return '${diff.inSeconds}s ago';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }
}

/// A small solid pill, matching the reference's "Self Care"-style corner tag.
class _Tag extends StatelessWidget {
  const _Tag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 6),
      decoration: BoxDecoration(color: t.brand.onSolid, borderRadius: AppRadius.fullAll),
      child: Text(
        label,
        style: context.text.labelSmall?.copyWith(color: t.brand.primary, letterSpacing: 0.3),
      ),
    );
  }
}

/// The hero card's circular CTA, matching the reference's arrow-in-a-circle
/// button in place of the app-wide [AppButton].
class _ArrowButton extends StatelessWidget {
  const _ArrowButton({required this.background, required this.iconColor});

  final Color background;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: Icon(Icons.arrow_forward_rounded, color: iconColor, size: 20),
    );
  }
}

/// A small refresh button on the parking hero card showing freshness timestamp
/// and allowing manual refresh of availability data.
class _RefreshButton extends StatelessWidget {
  const _RefreshButton({
    required this.isRefreshing,
    required this.timestamp,
    required this.onTap,
  });

  final bool isRefreshing;
  final DateTime timestamp;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isRefreshing ? null : onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: context.tokens.brand.onSolid.withValues(alpha: 0.2),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: isRefreshing
              ? SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(
                      context.tokens.brand.onSolid,
                    ),
                  ),
                )
              : Icon(
                  Icons.refresh_rounded,
                  size: 14,
                  color: context.tokens.brand.onSolid,
                ),
        ),
      ),
    );
  }
}

/// A second hero card, shown only when something is actually owed. Warm
/// (amber to coral) rather than the parking card's cool indigo-to-mint, so
/// the two read as "all clear" and "needs attention" at a glance without
/// either having to say so directly.
///
/// This is not a stored account balance — AimPark doesn't hold money — it's
/// the live sum of unpaid [Payment] rows, the same number Payments itself
/// shows. Naming the most recent one ("from your session at B-14") is what
/// makes it read as an answer to "did that trip just now cost me anything"
/// rather than an unexplained total.
class _PaymentDueCard extends StatefulWidget {
  const _PaymentDueCard({
    required this.balance,
    required this.overdueCount,
    required this.pendingCount,
    required this.mostRecent,
    required this.onTap,
    required this.onPayNow,
  });

  final double balance;
  final int overdueCount;
  final int pendingCount;

  /// The most recently created unpaid payment, if any — used only to name a
  /// session or say "violation fee"; the headline amount is always the full
  /// [balance], never just this one payment's.
  final Payment? mostRecent;

  final VoidCallback onTap;
  final VoidCallback onPayNow;

  @override
  State<_PaymentDueCard> createState() => _PaymentDueCardState();
}

class _PaymentDueCardState extends State<_PaymentDueCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final overdue = widget.overdueCount > 0;
    final recent = widget.mostRecent;
    // The API serializes the enum name verbatim ("ParkingFee",
    // "ViolationPenalty"), not a friendlier label — matched against the full
    // name here rather than payments_list_screen.dart's `== 'violation'`,
    // which never matches it.
    final isViolationFee = recent?.source.toLowerCase() == 'violationpenalty';

    final subtitle = overdue
        ? (widget.overdueCount == 1
            ? '1 overdue · tap to settle up'
            : '${widget.overdueCount} overdue · tap to settle up')
        : (recent?.slotCode != null && !isViolationFee)
            ? 'From your session at ${recent!.slotCode} · ${Formatters.relativeDay(recent.createdAt)}'
            : (widget.pendingCount == 1
                ? '1 pending payment'
                : '${widget.pendingCount} pending payments');

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _isPressed ? 0.98 : 1.0,
        duration: AppMotion.press,
        curve: AppMotion.standard,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [t.status.warning.solid, t.status.danger.solid],
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -16,
                  bottom: -18,
                  child: Opacity(
                    opacity: 0.95,
                    child: Image.asset(
                      'assets/images/mascot_wave.png',
                      height: 120,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Tag(label: overdue ? 'Overdue' : 'Payment due'),
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        '₱${(widget.balance).toStringAsFixed(0)} to settle',
                        style: context.text.headlineLarge
                            ?.copyWith(color: t.text.onDark, fontSize: 25),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        subtitle,
                        style: context.text.bodyMedium
                            ?.copyWith(color: t.text.onDarkMuted),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppButton(
                        label: 'Pay Now',
                        style: AppButtonStyle.primary,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          widget.onPayNow();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Your week at a glance": a big illustrated standing card beside two
/// tinted ring-stat cards, replacing the plain [GoodStandingMeter] card the
/// rest of the app still uses on its own.
class _WeekAtAGlance extends StatelessWidget {
  const _WeekAtAGlance({
    required this.standing,
    required this.streakDays,
    required this.points,
  });

  final ({double level, String tier}) standing;
  final int streakDays;
  final int points;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 5, child: _StandingCard(standing: standing)),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            flex: 4,
            child: Column(
              children: [
                Expanded(
                  child: _RingStatCard(
                    icon: Icons.local_fire_department_rounded,
                    label: 'Streak',
                    value: streakDays == 1 ? '1 day' : '$streakDays days',
                    ratio: (streakDays / 7).clamp(0.0, 1.0),
                    accent: context.tokens.tertiary,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Expanded(
                  child: _RingStatCard(
                    icon: Icons.star_rounded,
                    label: 'Points',
                    value: '$points',
                    ratio: (points / 300).clamp(0.0, 1.0),
                    accent: context.tokens.brand,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StandingCard extends StatelessWidget {
  const _StandingCard({required this.standing});

  final ({double level, String tier}) standing;

  StatusIntent get _intent => switch (standing.tier) {
        'Gold' => StatusIntent.success,
        'Silver' => StatusIntent.info,
        _ => StatusIntent.warning,
      };

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final status = t.status.of(_intent);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [t.tertiary.subtle, t.surface.card],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text('Good Standing', style: context.text.labelSmall),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => _showStandingHelp(context),
                      child: Text(
                        '?',
                        style: context.text.labelSmall?.copyWith(
                          color: context.tokens.brand.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              AppStatusBadge(label: standing.tier.toUpperCase(), intent: _intent),
            ],
          ),
          const Spacer(),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 60,
                height: 60,
                child: CircularProgressIndicator(
                  value: standing.level,
                  strokeWidth: 6,
                  backgroundColor: t.surface.muted,
                  valueColor: AlwaysStoppedAnimation(status.solid),
                ),
              ),
              Icon(Icons.shield_rounded, color: status.solid, size: 24),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(standing.tier, style: context.text.headlineSmall),
        ],
      ),
    );
  }

  void _showStandingHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('How Standing Works'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStandingTier('Gold', '✓', 'No violations. Full access to parking.'),
              const SizedBox(height: AppSpacing.lg),
              _buildStandingTier(
                'Silver',
                '◐',
                '1 open violation. Access monitored, may be restricted if not resolved.',
              ),
              const SizedBox(height: AppSpacing.lg),
              _buildStandingTier(
                'Bronze',
                '●',
                '2+ violations. Limited access. Possible suspension if not resolved.',
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'You earn +10 points per parking session, and +50 bonus points per full week of streak.',
                style: context.text.bodySmall,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Widget _buildStandingTier(String tier, String symbol, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(symbol, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tier,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(description, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }
}

/// One of the two small tinted cards to the standing card's right: an icon
/// ring showing progress toward a soft weekly goal, a label, and the value.
class _RingStatCard extends StatelessWidget {
  const _RingStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.ratio,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final double ratio;
  final AppAccentTokens accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: accent.subtle,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: context.text.labelSmall),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.titleMedium,
                ),
              ],
            ),
          ),
          SizedBox(
            width: 36,
            height: 36,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: ratio == 0 ? null : ratio,
                  strokeWidth: 4,
                  backgroundColor: accent.primary.withValues(alpha: 0.18),
                  valueColor: AlwaysStoppedAnimation(accent.primary),
                ),
                Icon(icon, size: 15, color: accent.primary),
              ],
            ),
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
