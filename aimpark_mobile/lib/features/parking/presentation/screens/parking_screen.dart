import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/utils/app_flushbar.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../dashboard/presentation/widgets/home_attention_cards.dart';
import '../../../vehicles/data/models/vehicle.dart';
import '../../../vehicles/presentation/providers/vehicles_provider.dart';
import '../../data/models/parking_history_entry.dart';
import '../../data/models/parking_slot.dart';
import '../providers/parking_history_provider.dart';
import '../widgets/availability_freshness.dart';
import '../widgets/availability_hero.dart';
import '../widgets/parking_map.dart';

/// The Parking tab: how full the lot is, where you are in it, and the lot itself.
///
/// Three things in one screen, in the order a driver needs them. First the same
/// availability card Home shows — whether there is room, and for what. Then, if
/// you are parked, your current session. Then the live map of every bay, with a
/// "Find me a slot" button above it that marks a suggested bay on the map.
///
/// The map used to be a second screen behind a "Browse slots" button, and that
/// button was hidden when the lot was full — so the one time a driver most
/// wanted to look at the lot, there was nothing to look at. It is on the tab now,
/// always.
///
/// Reached two ways: as the bottom-nav tab, and pushed from a notification that
/// is about the lot ([ParkingScreen.pushed]), which needs a way back.
class ParkingScreen extends ConsumerStatefulWidget {
  const ParkingScreen({super.key}) : _inline = true;

  /// The same screen opened on top of whatever the user was doing — from a push
  /// notification — with a title bar and a back arrow.
  const ParkingScreen.pushed({super.key}) : _inline = false;

  final bool _inline;

  @override
  ConsumerState<ParkingScreen> createState() => _ParkingScreenState();
}

class _ParkingScreenState extends ConsumerState<ParkingScreen> {
  SlotRecommendation? _recommendation;
  bool _isFinding = false;

  Future<void> _refresh() async {
    ref.invalidate(parkingAvailabilityNotifierProvider);
    await Future.wait([
      ref.read(parkingAvailabilityNotifierProvider.future),
      ref.read(parkingHistoryNotifierProvider.notifier).refresh(),
    ]);
  }

  /// Tells the server the driver parked in [slot] for [session]. Returns whether
  /// it worked, so the sheet knows to close; a refusal is shown here, in the
  /// server's own words (for example, someone else already confirmed that bay).
  Future<bool> _confirmSlot(
    ParkingHistoryEntry session,
    ParkingSlot slot,
  ) async {
    try {
      await ref
          .read(parkingRepositoryProvider)
          .confirmSlot(logId: session.logId, slotId: slot.slotId);
      // Invalidate rather than refresh(): refresh() puts the history into a
      // loading state, which blinks the whole screen for a one-field change.
      ref.invalidate(parkingHistoryNotifierProvider);
      ref.invalidate(parkingAvailabilityNotifierProvider);
      if (mounted) {
        showAppMessage(context, '${slot.slotCode} confirmed as your bay.');
      }
      return true;
    } catch (e) {
      if (mounted) showApiError(context, e);
      return false;
    }
  }

  Future<void> _findSlot() async {
    setState(() => _isFinding = true);
    try {
      final result = await ref.read(parkingRepositoryProvider).recommend();
      if (mounted) setState(() => _recommendation = result);
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _isFinding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final availabilityAsync = ref.watch(parkingAvailabilityNotifierProvider);
    final history = ref.watch(parkingHistoryNotifierProvider).valueOrNull;
    final current = history?.currentlyParked;
    // The session a tap on the map is about: the one the driver is in, or one
    // from earlier today that they have not said a bay for.
    final confirmTarget = current ?? history?.awaitingSlotConfirmation();
    final vehicles =
        ref.watch(myVehiclesProvider).valueOrNull ?? const <Vehicle>[];

    final userHasCar = vehicles.any((v) => !v.isMotorcycle);
    final userHasMotorcycle = vehicles.any((v) => v.isMotorcycle);

    final body = AsyncView(
      value: availabilityAsync,
      onRefresh: _refresh,
      errorTitle: "Couldn't load availability",
      loading: Padding(
        padding: kScreenListPadding,
        child: _AvailabilitySkeleton(showTitle: widget._inline),
      ),
      data: (availability) {
        // Only one kind of vehicle on the account, and none of its bays free:
        // the button would send them looking for a bay they cannot use.
        final onlyCar = userHasCar && !userHasMotorcycle;
        final onlyMoto = userHasMotorcycle && !userHasCar;
        final nothingForMe =
            availability.availableSlots <= 0 ||
            (onlyCar && availability.freeCars == 0) ||
            (onlyMoto && availability.freeMotorcycles == 0);

        // Someone already parked has no use for a free bay, and a paused feed
        // cannot suggest one.
        final canFind =
            current == null && !availability.isPaused && !nothingForMe;

        final suggested = _recommendation?.isAssigned == true
            ? _recommendation!.slotCode
            : null;

        return ListView(
          padding: kScreenListPadding,
          children: [
            if (widget._inline) const AppScreenTitle(title: 'Parking'),
            AvailabilityHero(
              availability: availability,
              userHasCar: userHasCar,
              userHasMotorcycle: userHasMotorcycle,
              onRefresh: _refresh,
            ),
            // No separate "live updates are paused" note here: the availability
            // card above already says so, in the same words, and a second box
            // repeating it only pushed the map further down.
            if (current != null) ...[
              const SizedBox(height: AppSpacing.md),
              // Tapped out with a fee to pay: the gate is shut until it is paid.
              current.waitingToLeave
                  ? PayToLeaveCard(session: current)
                  : _CurrentSessionCard(entry: current),
            ],
            if (canFind) ...[
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'Find me a slot',
                icon: const Icon(Icons.explore_rounded),
                isLoading: _isFinding,
                onPressed: _isFinding ? null : _findSlot,
              ),
            ],
            if (_recommendation != null) ...[
              const SizedBox(height: AppSpacing.md),
              _RecommendationCard(recommendation: _recommendation!),
            ],
            const SizedBox(height: AppSpacing.lg),
            const AppSectionHeader(
              title: 'Live map',
              subtitle:
                  'Tap a bay for details. It updates by itself every few '
                  'seconds.',
            ),
            if (confirmTarget != null && !confirmTarget.slotConfirmed) ...[
              AppNotice(
                intent: StatusIntent.info,
                message: confirmTarget.isOpen
                    ? 'Tap the bay you parked in and confirm it, so the guards '
                          'know it was you. Leaving without confirming counts '
                          'against you.'
                    : 'You left earlier today. Tap the bay you used and confirm '
                          'it — this is open until midnight, after which it '
                          'counts as unconfirmed.',
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            ParkingMap(
              availability: availability,
              suggestedCode: suggested,
              confirmedCode: confirmTarget != null && confirmTarget.slotConfirmed
                  ? confirmTarget.slotCode
                  : null,
              // A confirm is final, so once given the map is only for looking.
              onConfirmSlot:
                  confirmTarget == null || confirmTarget.slotConfirmed
                  ? null
                  : (slot) => _confirmSlot(confirmTarget, slot),
              userHasCar: userHasCar,
              userHasMotorcycle: userHasMotorcycle,
            ),
            const SizedBox(height: AppSpacing.lg),
            // Said plainly, because the map looks exactly like a seat picker and
            // a seat picker holds your seat. This one does not — reservations
            // are not built, and a driver who thinks otherwise finds out at the
            // gate.
            Text(
              'Looking at a bay does not hold it for you. Entry is confirmed by '
              'your RFID card at the gate.',
              style: context.text.bodySmall,
            ),
          ],
        );
      },
    );

    return widget._inline
        ? AppScreen.tab(body: body)
        : AppScreen(title: 'Parking', body: body);
  }
}

class _CurrentSessionCard extends StatelessWidget {
  const _CurrentSessionCard({required this.entry});

  final ParkingHistoryEntry entry;

  /// The bay is named only once the driver has confirmed it. Until then
  /// [ParkingHistoryEntry.slotCode] is just the gate's suggestion, and the lot
  /// cannot tell whose car is in which bay.
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return AppCard(
      borderColor: t.tertiary.primary,
      edgeColor: t.tertiary.primary,
      padding: const EdgeInsets.all(AppSpacing.md + 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: t.tertiary.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.xs + 2),
              Text(
                'YOU ARE PARKED',
                style: context.text.labelMedium?.copyWith(
                  color: t.tertiary.subtleText,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            Formatters.sessionRange(entry.entryTime, null, entry.duration),
            style: AppTypography.tabular(context.text.headlineMedium!),
          ),
          const SizedBox(height: AppSpacing.sm),
          // No running fee estimate here, on purpose. Nothing in the app knows
          // the lot's rate — ratePerHourApplied only exists on a payment, which
          // is created at exit — so any figure here would be the app inventing
          // a number the server has not agreed to.
          Text(
            'You pay when you leave. Tap your card at the gate and the fee '
            'shows here.',
            style: context.text.bodySmall,
          ),
          if (entry.slotConfirmed && entry.slotCode != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Your bay: ${entry.slotCode}',
              style: context.text.titleSmall,
            ),
          ],
        ],
      ),
    );
  }
}

/// What `POST /api/parking/recommend` came back with. The suggested bay is also
/// ringed on the map below, so this card is the sentence and the map is the
/// picture.
class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({required this.recommendation});

  final SlotRecommendation recommendation;

  @override
  Widget build(BuildContext context) {
    final assigned = recommendation.isAssigned;

    return AppAlertCard(
      intent: assigned ? StatusIntent.success : StatusIntent.warning,
      eyebrow: assigned ? 'Suggested slot' : 'No slot available',
      icon: assigned ? Icons.near_me_rounded : null,
      title: assigned
          ? '${recommendation.slotCode} · Gate ${recommendation.gate}'
          : (recommendation.reason ?? 'Nothing is free right now.'),
      message: assigned
          ? 'Head for the bay ringed on the map. It is not held for you — the '
                'gate still decides when your card is read.'
          : (recommendation.alternatives.isEmpty
                ? null
                : 'Try instead: '
                      '${recommendation.alternatives.map((a) => a.slotCode).join(', ')}'),
    );
  }
}

class _AvailabilitySkeleton extends StatelessWidget {
  const _AvailabilitySkeleton({required this.showTitle});

  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTitle) const AppScreenTitle(title: 'Parking'),
        const AppSkeleton(
          width: double.infinity,
          height: 232,
          radius: AppRadius.lg,
        ),
        const SizedBox(height: AppSpacing.md),
        const AppSkeleton.block(height: 120),
      ],
    );
  }
}
