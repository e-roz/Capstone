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
import '../../../parking/presentation/widgets/availability_freshness.dart';
import '../../../payments/data/models/payment.dart';
import '../../../payments/presentation/providers/payments_provider.dart';
import '../../../violations/data/models/violation.dart';
import '../../../violations/presentation/providers/violations_provider.dart';
import '../../domain/standing.dart';

/// Home tab body inside [UserShell]. Streak/points/standing are derived
/// client-side from real parking history and violation data — there's no
/// dedicated Points/Streak entity in the backend, so these are honest
/// computations over real rows rather than a stored game-score.
///
/// The screen is arranged in three tiers. Tier 1 is the hero and any alert
/// card; tier 2 is standing and recent activity; tier 3 is the quick-action
/// row. Alert cards exist only when they are true, so an untroubled account
/// sees a short screen rather than a screen full of reassurance.
class UserDashboardScreen extends ConsumerWidget {
  const UserDashboardScreen({
    super.key,
    required this.onNavigateToParking,
    required this.onNavigateToPayments,
    required this.onNavigateToAccount,
  });

  /// Switches the parent [UserShell] to the Parking tab.
  final VoidCallback onNavigateToParking;

  /// Switches the parent [UserShell] to the Payments tab.
  final VoidCallback onNavigateToPayments;

  /// Switches the parent [UserShell] to the Account tab.
  final VoidCallback onNavigateToAccount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileNotifierProvider);
    final historyAsync = ref.watch(parkingHistoryNotifierProvider);
    final violationsAsync = ref.watch(violationsNotifierProvider);
    final paymentsAsync = ref.watch(paymentsNotifierProvider);
    // Availability is the one number people open this app for.
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
    final isFirstLoad =
        !(settled(profileAsync) &&
            settled(historyAsync) &&
            settled(violationsAsync));

    // Only when nothing at all came back. One failed provider still leaves a
    // useful screen, so it degrades rather than blocking the other two.
    final allFailed =
        !profileAsync.hasValue &&
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
    final streakDays = Standing.streakDays(history, violations);
    final points = Standing.points(history, streakDays);
    final tier = Standing.tierFor(violations);

    // A violation the user never sees is a violation they cannot appeal. It
    // used to arrive as a push and then live only in the Alerts tab and two
    // taps down inside Profile, so anyone who missed the push found out when
    // their card stopped opening the gate. It now sits on the first screen.
    final openViolations =
        (violations?.violations ?? const <ViolationSummary>[])
            .where(Standing.isOpen)
            .length;
    final unpaid = (paymentsAsync.valueOrNull?.payments ?? const <Payment>[])
        .where((p) => !p.isPaid && p.status.toLowerCase() != 'waived')
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
              const SizedBox(height: AppSpacing.md),
              const AppSkeleton(
                width: double.infinity,
                height: 232,
                radius: AppRadius.lg,
              ),
              const SizedBox(height: AppSpacing.md),
              const AppSkeleton.block(height: 96),
            ] else ...[
              _Header(
                name: profileAsync.valueOrNull?.fullName ?? 'there',
                onTapAvatar: onNavigateToAccount,
              ),
              const SizedBox(height: AppSpacing.md),
              _HeroCard(
                entry: history?.currentlyParked,
                availability: availability,
                onTap: onNavigateToParking,
                onRefresh: () =>
                    ref.refresh(parkingAvailabilityProvider.future),
              ),

              // Alerts only exist when they are true. An account with nothing
              // owed and nothing open drops straight from the hero to standing.
              if (balance > 0) ...[
                const SizedBox(height: AppSpacing.md),
                _PaymentDueCard(
                  balance: balance,
                  itemCount: unpaid.length,
                  overdueCount: overdueCount,
                  onPay: onNavigateToPayments,
                ),
              ],
              if (openViolations > 0) ...[
                const SizedBox(height: AppSpacing.md),
                _ViolationCard(
                  count: openViolations,
                  onTap: () => context.push('/home/user/violations'),
                ),
              ],

              const SizedBox(height: AppSpacing.lg),
              AppSectionHeader(
                title: 'Your standing',
                action: GestureDetector(
                  onTap: () => context.push('/home/user/standing'),
                  child: Text(
                    'How this works',
                    style: context.text.bodySmall?.copyWith(
                      color: context.tokens.brand.primary,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
              _StandingRow(tier: tier, streakDays: streakDays, points: points),

              if (recentLogs.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                const AppSectionHeader(title: 'Recent activity'),
                AppRowGroup(
                  children: [
                    for (final log in recentLogs)
                      _SessionRow(
                        entry: log,
                        onTap: () => context.push('/home/user/parking-history'),
                      ),
                  ],
                ),
              ],

              const SizedBox(height: AppSpacing.lg),
              const AppSectionHeader(title: 'Quick actions'),
              _QuickActions(
                onReport: () => context.push('/home/user/incidents/new'),
                onVehicles: () => context.push('/home/user/vehicles'),
                onSlots: () => context.push('/home/user/parking-slots'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Home reads five providers; a pull-to-refresh here should reload all of
  /// them rather than whichever one the gesture happened to land on.
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

/// Mirrors [_Header]'s layout so the row doesn't jump when the real name lands.
class _HeaderSkeleton extends StatelessWidget {
  const _HeaderSkeleton();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              AppSkeleton.line(width: 96, height: 13),
              SizedBox(height: 6),
              AppSkeleton.line(width: 148, height: 22),
            ],
          ),
        ),
        const AppSkeleton(width: 44, height: 44, radius: AppRadius.full),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.name, required this.onTapAvatar});

  final String name;
  final VoidCallback onTapAvatar;

  /// Morning / afternoon / evening, on the device clock. Not a personalisation
  /// feature — it is what makes the name underneath read as a greeting rather
  /// than as a page title.
  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  /// Just the given name. The full name pushed the avatar off a 360dp screen
  /// for anyone with three names, which in the Philippines is most people.
  String get _firstName {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'there';
    return trimmed.split(RegExp(r'\s+')).first;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_greeting, style: context.text.bodySmall),
              Text(
                _firstName,
                style: context.text.headlineMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Semantics(
          button: true,
          label: 'Account',
          child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              onTapAvatar();
            },
            customBorder: const CircleBorder(),
            child: AppAvatar(name: name, size: 44),
          ),
        ),
      ],
    );
  }
}

/// The one full-bleed brand surface on the screen: a 135° indigo-to-mint wash
/// carrying the parking state, the live slot count and the way into Parking.
///
/// Everything inside reads `brand.onSolid` rather than the ordinary text
/// tokens — on a colour-fill card those would be near-black, and unreadable.
class _HeroCard extends StatefulWidget {
  const _HeroCard({
    required this.entry,
    required this.availability,
    required this.onTap,
    required this.onRefresh,
  });

  final ParkingHistoryEntry? entry;
  final ParkingAvailability? availability;
  final VoidCallback onTap;
  final Future<void> Function() onRefresh;

  @override
  State<_HeroCard> createState() => _HeroCardState();
}

class _HeroCardState extends State<_HeroCard>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;

  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: AppMotion.slow,
  );

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_spin.isAnimating) return;
    _spin.repeat();
    try {
      await widget.onRefresh();
    } finally {
      if (mounted) {
        _spin.stop();
        _spin.reset();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final onSolid = t.brand.onSolid;
    // A single alpha ramp for everything secondary on the wash. Reading these
    // off the neutral ramp instead would put a cream tint on a blue field.
    final muted = onSolid.withValues(alpha: 0.7);
    final hairline = onSolid.withValues(alpha: 0.18);

    final isParked = widget.entry != null;
    final availability = widget.availability;

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
        scale: _isPressed ? 0.985 : 1.0,
        duration: AppMotion.press,
        curve: AppMotion.standard,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.x5),
          decoration: BoxDecoration(
            borderRadius: AppRadius.lgAll,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [t.brand.primary, t.brand.pressed, t.tertiary.pressed],
              stops: const [0.0, 0.62, 1.0],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Tag(
                    label: isParked ? 'PARKED NOW' : 'NOT PARKED',
                    onSolid: onSolid,
                  ),
                  const Spacer(),
                  Container(
                    width: 54,
                    height: 54,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: onSolid.withValues(alpha: 0.12),
                      border: Border.all(
                        color: onSolid.withValues(alpha: 0.22),
                      ),
                    ),
                    child: Image.asset(
                      'assets/images/mascot_wave.png',
                      fit: BoxFit.contain,
                      // The mascot is decoration, not information — every fact
                      // on this card is also in text beside it.
                      excludeFromSemantics: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm + 6),
              Text(
                isParked
                    ? (widget.entry!.slotCode ?? 'Parked')
                    : 'Ready to park',
                style: AppTypography.tabular(
                  context.text.displayLarge!,
                ).copyWith(color: onSolid),
              ),
              const SizedBox(height: 2),
              Text(
                isParked
                    ? Formatters.sessionRange(
                        widget.entry!.entryTime,
                        null,
                        widget.entry!.duration,
                      )
                    : 'No active session',
                style: context.text.bodyMedium?.copyWith(color: muted),
              ),
              const SizedBox(height: AppSpacing.md),
              Divider(height: 1, thickness: 1, color: hairline),
              const SizedBox(height: AppSpacing.sm + 4),
              Row(
                children: [
                  Expanded(
                    child: _AvailabilityLine(
                      availability: availability,
                      onSolid: onSolid,
                      muted: muted,
                    ),
                  ),
                  _HeroRefreshButton(spin: _spin, onTap: _refresh, fg: onSolid),
                ],
              ),
              const SizedBox(height: AppSpacing.sm + 4),
              _HeroCta(
                label: isParked ? 'View session' : 'Find a slot',
                onTap: widget.onTap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvailabilityLine extends StatelessWidget {
  const _AvailabilityLine({
    required this.availability,
    required this.onSolid,
    required this.muted,
  });

  final ParkingAvailability? availability;
  final Color onSolid;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    final a = availability;
    if (a == null) {
      return Text(
        'Checking availability…',
        style: context.text.titleMedium?.copyWith(color: muted),
      );
    }

    final freshness = AvailabilityFreshness.of(a.fetchedAt);
    // On the wash the status tints would disappear, so freshness is carried by
    // a dot in the status *solid* — the one tone in each ramp with enough
    // contrast to survive on a saturated background.
    final dot = context.tokens.status.of(freshness.intent).solid;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          a.isLotFull ? 'Lot is full' : '${a.availableSlots} slots free',
          style: AppTypography.tabular(
            context.text.titleMedium!,
          ).copyWith(color: onSolid),
        ),
        const SizedBox(height: 3),
        Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                freshness.label(a.fetchedAt),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodySmall?.copyWith(color: muted),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _HeroRefreshButton extends StatelessWidget {
  const _HeroRefreshButton({
    required this.spin,
    required this.onTap,
    required this.fg,
  });

  final AnimationController spin;
  final VoidCallback onTap;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Refresh availability',
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: fg.withValues(alpha: 0.12),
            border: Border.all(color: fg.withValues(alpha: 0.3)),
          ),
          child: RotationTransition(
            turns: spin,
            child: Icon(
              Icons.refresh_rounded,
              color: fg,
              size: AppSizes.iconMd,
            ),
          ),
        ),
      ),
    );
  }
}

/// The hero's white CTA. Not an [AppButton]: on the wash the app-wide primary
/// would be indigo on indigo.
class _HeroCta extends StatelessWidget {
  const _HeroCta({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: t.surface.card,
        borderRadius: AppRadius.fullAll,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          borderRadius: AppRadius.fullAll,
          child: SizedBox(
            height: 44,
            width: double.infinity,
            child: Center(
              child: Text(
                label,
                style: context.text.labelLarge?.copyWith(
                  color: t.brand.subtleText,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A translucent pill on the wash, carrying the parking state in words.
class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.onSolid});

  final String label;
  final Color onSolid;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: onSolid.withValues(alpha: 0.16),
        borderRadius: AppRadius.fullAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: context.tokens.tertiary.subtle,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(label, style: context.text.labelSmall?.copyWith(color: onSolid)),
        ],
      ),
    );
  }
}

/// Shown only when something is actually owed.
///
/// White with an amber edge rather than a warm gradient fill. This card carries
/// the one number on the screen a user might act on, and a tinted fill puts
/// coloured text on coloured ground exactly where legibility matters most.
class _PaymentDueCard extends StatelessWidget {
  const _PaymentDueCard({
    required this.balance,
    required this.itemCount,
    required this.overdueCount,
    required this.onPay,
  });

  final double balance;
  final int itemCount;
  final int overdueCount;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = t.status.warning;

    return AppCard(
      borderColor: c.border,
      edgeColor: c.solid,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, size: 16, color: c.fg),
              const SizedBox(width: AppSpacing.xs + 2),
              Text(
                'PAYMENT DUE',
                style: context.text.labelMedium?.copyWith(color: c.fg),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                Formatters.peso(balance),
                style: AppTypography.tabular(context.text.displayLarge!),
              ),
              const SizedBox(width: AppSpacing.xs + 4),
              Flexible(
                child: Text(
                  'across $itemCount item${itemCount == 1 ? '' : 's'}',
                  style: context.text.bodySmall,
                ),
              ),
            ],
          ),
          if (overdueCount > 0) ...[
            const SizedBox(height: 2),
            Text(
              '$overdueCount overdue',
              style: context.text.bodySmall?.copyWith(
                color: t.status.danger.fg,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm + 6),
          AppButton(label: 'Pay ${Formatters.peso(balance)}', onPressed: onPay),
        ],
      ),
    );
  }
}

/// Shown only when a violation is open. Tappable in full — the whole card is
/// the way in, so there is no small chevron to aim at.
class _ViolationCard extends StatelessWidget {
  const _ViolationCard({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = t.status.danger;

    return AppCard(
      borderColor: c.border,
      edgeColor: c.solid,
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.error_outline_rounded, size: 16, color: c.fg),
                    const SizedBox(width: AppSpacing.xs + 2),
                    Text(
                      count == 1
                          ? '1 OPEN VIOLATION'
                          : '$count OPEN VIOLATIONS',
                      style: context.text.labelMedium?.copyWith(color: c.fg),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text('Review and appeal', style: context.text.titleMedium),
                const SizedBox(height: 2),
                Text(
                  'Your access is unaffected while a violation is open.',
                  style: context.text.bodySmall,
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: t.text.secondary,
            size: AppSizes.iconLg,
          ),
        ],
      ),
    );
  }
}

class _StandingRow extends StatelessWidget {
  const _StandingRow({
    required this.tier,
    required this.streakDays,
    required this.points,
  });

  final StandingTier tier;
  final int streakDays;
  final int points;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    // Gold is the only tier that is actually good news. Silver and Bronze mean
    // something is outstanding, so they take the warning tone rather than a
    // medal colour that would read as an achievement.
    final intent = tier == StandingTier.gold
        ? StatusIntent.success
        : StatusIntent.warning;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 14,
          child: AppCard(
            padding: const EdgeInsets.all(AppSpacing.sm + 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    StatusDot(intent: intent, size: 10),
                    const SizedBox(width: AppSpacing.xs + 2),
                    Flexible(
                      child: Text(
                        '${tier.label} standing',
                        style: context.text.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.labelGap),
                Text(
                  tier.effect,
                  style: context.text.bodySmall?.copyWith(
                    color: t.text.secondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.gutter),
        Expanded(
          flex: 10,
          child: _StatCard(value: streakDays, label: 'DAY STREAK'),
        ),
        const SizedBox(width: AppSpacing.gutter),
        Expanded(
          flex: 10,
          child: _StatCard(value: points, label: 'POINTS'),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.sm + 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$value',
            style: AppTypography.tabular(context.text.headlineMedium!),
          ),
          const SizedBox(height: 2),
          Text(label, style: context.text.labelSmall),
        ],
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.entry, required this.onTap});

  final ParkingHistoryEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return AppListRow(
      leading: Container(
        width: AppSizes.rowIcon,
        height: AppSizes.rowIcon,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: t.surface.muted,
          shape: BoxShape.circle,
        ),
        child: Text(
          entry.slotCode ?? '—',
          style: context.text.bodySmall?.copyWith(
            color: t.text.secondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      title: Formatters.dateShort(entry.entryTime),
      subtitle: Formatters.sessionRange(
        entry.entryTime,
        entry.exitTime,
        entry.duration,
      ),
      trailing: entry.isOpen
          ? const AppStatusBadge(
              label: 'Parked now',
              intent: StatusIntent.success,
            )
          : null,
      onTap: onTap,
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onReport,
    required this.onVehicles,
    required this.onSlots,
  });

  final VoidCallback onReport;
  final VoidCallback onVehicles;
  final VoidCallback onSlots;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: _QuickAction(
            icon: Icons.warning_amber_rounded,
            label: 'Report',
            onTap: onReport,
          ),
        ),
        const SizedBox(width: AppSpacing.gutter),
        Expanded(
          child: _QuickAction(
            icon: Icons.directions_car_rounded,
            label: 'Vehicles',
            onTap: onVehicles,
          ),
        ),
        const SizedBox(width: AppSpacing.gutter),
        Expanded(
          child: _QuickAction(
            icon: Icons.grid_view_rounded,
            label: 'Find a slot',
            onTap: onSlots,
          ),
        ),
      ],
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
        horizontal: AppSpacing.xs + 6,
        vertical: AppSpacing.sm + 6,
      ),
      child: SizedBox(
        height: 60,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: t.brand.primary),
            const SizedBox(height: AppSpacing.xs + 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodySmall?.copyWith(
                color: t.text.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
