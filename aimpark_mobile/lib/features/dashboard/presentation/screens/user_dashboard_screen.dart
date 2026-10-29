import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../account/presentation/providers/account_provider.dart';
import '../../../account/presentation/widgets/access_status_card.dart';
import '../../../notifications/presentation/providers/notifications_provider.dart';
import '../../../parking/data/models/parking_history_entry.dart';
import '../../../parking/data/models/parking_slot.dart';
import '../../../parking/presentation/providers/parking_history_provider.dart';
import '../../../parking/presentation/widgets/availability_hero.dart';
import '../../../parking/presentation/widgets/parking_session_row.dart';
import '../../../parking/presentation/widgets/pay_ahead_action.dart';
import '../../../payments/data/models/payment.dart';
import '../../../payments/presentation/providers/payments_provider.dart';
import '../../../vehicles/data/models/vehicle.dart';
import '../../../vehicles/presentation/providers/vehicles_provider.dart';
import '../../../violations/data/models/violation.dart';
import '../../../violations/presentation/providers/violations_provider.dart';
import '../../../renewals/presentation/widgets/expiry_banner.dart';
import '../widgets/home_attention_cards.dart';
import '../widgets/home_header.dart';
import '../widgets/vehicle_status_card.dart';

/// Home tab body inside [UserShell].
///
/// Built to answer, in order: *can I park, and is my card going to work, and do
/// I owe anything or need to act?* Nothing here is computed into a score — what
/// it shows is what the server said, or a plain sum of it.
///
/// Top to bottom:
///
/// 1. The header, with the notifications bell.
/// 2. The RFID card — **first, but only when it is restricted.** A suspended,
///    scheduled or revoked card is the one fact that stops someone at the gate,
///    so it goes above everything. When the card is fine it sits lower down and
///    takes up no attention.
/// 3. Availability, by total and by vehicle type.
/// 4. What needs attention: money owed, then open violations. These exist only
///    when they are true, so an untroubled account sees a short screen.
/// 5. The RFID card, when it is fine.
/// 6. The vehicle.
/// 7. Quick actions.
/// 8. Recent activity.
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
    final vehiclesAsync = ref.watch(myVehiclesProvider);
    final availabilityAsync = ref.watch(parkingAvailabilityNotifierProvider);
    final access = ref.watch(accessStatusProvider).valueOrNull;
    final unreadCount =
        ref.watch(notificationsNotifierProvider).valueOrNull?.unreadCount ?? 0;

    // Home draws on several providers at once, so it needs its own answer to
    // "has anything arrived yet" rather than the single-provider AsyncView the
    // other screens use. Reading `.valueOrNull` alone rendered a fully populated
    // screen out of nulls on the first frame after login — a greeting to
    // "there", "Not parked" — and then rearranged itself a moment later.
    // `hasValue || hasError` rather than `!isLoading` so a pull-to-refresh keeps
    // showing the data underneath instead of flashing back to skeletons.
    bool settled(AsyncValue<Object?> value) => value.hasValue || value.hasError;
    final isFirstLoad =
        !(settled(profileAsync) &&
            settled(historyAsync) &&
            settled(violationsAsync) &&
            settled(vehiclesAsync));

    // Only when nothing at all came back. One failed provider still leaves a
    // useful screen, so it degrades rather than blocking the rest.
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
    final vehicles = vehiclesAsync.valueOrNull ?? const <Vehicle>[];

    // A violation the user never sees is a violation they cannot appeal.
    final allViolations =
        violationsAsync.valueOrNull?.violations ?? const <ViolationSummary>[];
    final openViolations = allViolations.where((v) => v.isOpen).toList();

    // At the exit with a fee to pay: asked for on its own card, so it is not
    // listed a second time as an ordinary bill.
    final waitingToLeave = history?.waitingToLeave;

    // Still parked: the bill for this stay, if they asked to pay ahead, is
    // offered on the card that asked for it, not as a debt.
    final parked = history?.currentlyParked;

    final unpaid = (paymentsAsync.valueOrNull?.payments ?? const <Payment>[])
        .where((p) => !p.isPaid && p.status.toLowerCase() != 'waived')
        .where((p) => p.paymentId != parked?.paymentId)
        .toList();

    final recentLogs =
        history?.logs.take(3).toList() ?? const <ParkingHistoryEntry>[];

    // Inside or just left, and no bay said yet. Nothing to ask if they never
    // came in today.
    final awaitingSlot = history?.awaitingSlotConfirmation();

    // The bills already loaded, keyed so each session can show what it cost.
    final billsById = {
      for (final p in paymentsAsync.valueOrNull?.payments ?? const <Payment>[])
        p.paymentId: p,
    };

    final accessRestricted =
        access != null && AccessCardView.from(access).state.isRestricted;

    const gap = SizedBox(height: AppSpacing.md);

    return AppScreen.tab(
      body: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: ListView(
          padding: kScreenListPadding,
          children: [
            if (isFirstLoad) ...[
              const HomeHeaderSkeleton(),
              gap,
              const AppSkeleton(
                width: double.infinity,
                height: 232,
                radius: AppRadius.lg,
              ),
              gap,
              const AppSkeleton.block(height: 88),
              gap,
              const AppSkeleton.block(height: 72),
            ] else ...[
              HomeHeader(
                name: profileAsync.valueOrNull?.fullName ?? 'there',
                unreadCount: unreadCount,
                onBell: () => context.push('/home/user/notifications'),
                onAvatar: onNavigateToAccount,
              ),
              gap,

              // The card that decides whether the gate opens goes first when it
              // is in trouble.
              if (accessRestricted) ...[
                AccessStatusCard(onGoToPayments: onNavigateToPayments),
                gap,
              ],

              // A licence or registration close to running out, or a renewal
              // waiting on an admin. Draws nothing when there is nothing to say.
              const ExpiryBanner(),

              if (waitingToLeave != null) ...[
                PayToLeaveCard(session: waitingToLeave),
                gap,
              ],

              _hero(context, ref, availabilityAsync, vehicles),

              // Parked and not yet at the gate: they can pay from here and
              // drive straight out.
              if (parked != null && waitingToLeave == null) ...[
                gap,
                AppAlertCard(
                  intent: parked.isPaidToLeave()
                      ? StatusIntent.success
                      : StatusIntent.info,
                  eyebrow: 'You are parked',
                  icon: Icons.local_parking_rounded,
                  child: PayAheadAction(session: parked),
                ),
              ],

              if (awaitingSlot != null && waitingToLeave == null) ...[
                gap,
                ConfirmSlotCard(session: awaitingSlot),
              ],

              if (unpaid.isNotEmpty) ...[
                gap,
                PaymentDueCard(
                  unpaid: unpaid,
                  violations: allViolations,
                  onReviewAll: onNavigateToPayments,
                  entryBlocked: access?.isEntryBlockedByBalance ?? false,
                ),
              ],
              if (openViolations.isNotEmpty) ...[
                gap,
                OpenViolationsCard(open: openViolations),
              ],

              // Always shown: a clean record is worth saying, and the count is
              // what tells a user how close they are to losing the card. Held back
              // until violations have loaded so it never claims "none" by default.
              if (violationsAsync.hasValue) ...[
                gap,
                ViolationStrikesCard(violations: allViolations),
              ],

              if (!accessRestricted) ...[
                gap,
                AccessStatusCard(onGoToPayments: onNavigateToPayments),
              ],

              gap,
              const VehicleStatusCard(),

              // Above the shortcuts: where the car has been, and what each visit
              // cost, is something people check; the shortcuts are things they
              // do now and then.
              if (recentLogs.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                AppSectionHeader(
                  title: 'Recent parking',
                  action: AppTextLink(
                    label: 'See all',
                    semanticLabel: 'See all parking history',
                    onTap: () => context.push('/home/user/parking-history'),
                  ),
                ),
                AppRowGroup(
                  children: [
                    for (final log in recentLogs)
                      ParkingSessionRow(
                        entry: log,
                        payment: billsById[log.paymentId],
                        plate: ParkingSessionRow.plateFor(log, vehicles),
                        onTap: log.paymentId == null
                            ? null
                            : () => context.push(
                                '/home/user/payments/${log.paymentId}',
                              ),
                      ),
                  ],
                ),
              ],

              const SizedBox(height: AppSpacing.lg),
              const AppSectionHeader(title: 'Quick actions'),
              _QuickActions(
                onReport: () => context.push('/home/user/incidents/new'),
                onVehicles: () => context.push('/home/user/vehicles'),
                onViolations: () => context.push('/home/user/violations'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// The availability card, or what stands in for it.
  ///
  /// A failed first load is an error with a way to retry, not a card reading "—"
  /// and "Checking…" forever, which is what an unanswered request looked like
  /// before. Once a count has arrived it is kept on screen through any later
  /// failed poll; the freshness line is what says it has aged.
  Widget _hero(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<ParkingAvailability> availabilityAsync,
    List<Vehicle> vehicles,
  ) {
    final availability = availabilityAsync.valueOrNull;

    if (availability != null) {
      return AvailabilityHero(
        availability: availability,
        userHasCar: vehicles.any((v) => !v.isMotorcycle),
        userHasMotorcycle: vehicles.any((v) => v.isMotorcycle),
        onOpenParking: onNavigateToParking,
        onSelectSlot: onNavigateToParking,
        onRefresh: () =>
            ref.refresh(parkingAvailabilityNotifierProvider.future),
      );
    }

    if (availabilityAsync.hasError) {
      return AppAlertCard(
        intent: StatusIntent.warning,
        eyebrow: 'Availability',
        title: "Couldn't load availability",
        message: 'Check your connection and try again.',
        action: AppButton(
          label: 'Try again',
          style: AppButtonStyle.ghost,
          onPressed: () =>
              ref.refresh(parkingAvailabilityNotifierProvider.future),
        ),
      );
    }

    return const AppSkeleton(
      width: double.infinity,
      height: 232,
      radius: AppRadius.lg,
    );
  }

  /// Home reads several providers; a pull-to-refresh here should reload all of
  /// them rather than whichever one the gesture happened to land on.
  Future<void> _refresh(WidgetRef ref) async {
    await Future.wait([
      ref.read(profileNotifierProvider.notifier).refresh(),
      ref.read(parkingHistoryNotifierProvider.notifier).refresh(),
      ref.read(violationsNotifierProvider.notifier).refresh(),
      ref.read(paymentsNotifierProvider.notifier).refresh(),
      ref.refresh(parkingAvailabilityNotifierProvider.future),
      ref.refresh(myVehiclesProvider.future),
      ref.refresh(accessStatusProvider.future),
    ]);
    // Invalidating rather than refreshing: the family has one entry per
    // vehicle, and refresh() only targets a single one. invalidate() clears
    // all of them, so whichever vehicle the card is showing re-fetches too.
    ref.invalidate(vehicleLatestSessionProvider);
    ref.invalidate(notificationsNotifierProvider);
  }
}

/// The three things a driver does that are not on a tab: report something, look
/// after their vehicles, and check their violations.
///
/// What is *not* here is deliberate. Picking a slot is the availability card's
/// button, parking history is the "See all" link on Recent parking, and
/// notifications are the bell — each already one tap away from where the person
/// is looking. Violations earned its place because it was reachable only through
/// Account, and an appeal has a deadline.
class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onReport,
    required this.onVehicles,
    required this.onViolations,
  });

  final VoidCallback onReport;
  final VoidCallback onVehicles;
  final VoidCallback onViolations;

  @override
  Widget build(BuildContext context) {
    // IntrinsicHeight is not optional here. A Row that stretches its children
    // needs a finite height to stretch to, and inside a scrolling list it is
    // handed an infinite one: the layout asserts in debug and, in a release or
    // web build, the children are skipped and nothing is drawn at all. The tiles
    // simply were not there — and the old standing row beside them was missing
    // for the same reason.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: AppActionTile(
              icon: Icons.flag_rounded,
              label: 'Report incident',
              intent: StatusIntent.warning,
              onTap: onReport,
            ),
          ),
          const SizedBox(width: AppSpacing.gutter),
          Expanded(
            child: AppActionTile(
              icon: Icons.directions_car_rounded,
              label: 'My vehicles',
              intent: StatusIntent.brand,
              onTap: onVehicles,
            ),
          ),
          const SizedBox(width: AppSpacing.gutter),
          Expanded(
            child: AppActionTile(
              icon: Icons.gavel_rounded,
              label: 'Violations',
              intent: StatusIntent.info,
              onTap: onViolations,
            ),
          ),
        ],
      ),
    );
  }
}
