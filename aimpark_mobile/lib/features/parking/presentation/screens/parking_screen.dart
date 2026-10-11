import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/utils/app_flushbar.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/widgets.dart';
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
    final current = ref
        .watch(parkingHistoryNotifierProvider)
        .valueOrNull
        ?.currentlyParked;
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
              _CurrentSessionCard(entry: current, availability: availability),
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
            ParkingMap(
              availability: availability,
              myCode: current?.slotCode,
              suggestedCode: suggested,
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
  const _CurrentSessionCard({required this.entry, required this.availability});

  final ParkingHistoryEntry entry;
  final ParkingAvailability availability;

  /// The gate lives on the *slot*, not on the history entry, so a session's
  /// gate has to be looked up by slot code. Null when the code matches nothing
  /// currently returned — the line then drops the gate rather than guessing.
  int? get _gate {
    final code = entry.slotCode;
    if (code == null) return null;
    for (final slot in availability.slots) {
      if (slot.slotCode == code) return slot.gate;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final gate = _gate;
    final title = [
      entry.slotCode ?? 'Unassigned slot',
      if (gate != null) 'Gate $gate',
    ].join(' · ');

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
          Text(title, style: context.text.headlineMedium),
          const SizedBox(height: 2),
          Text(
            Formatters.sessionRange(entry.entryTime, null, entry.duration),
            style: AppTypography.tabular(
              context.text.bodyMedium!,
            ).copyWith(color: t.text.secondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          // No running fee estimate here, on purpose. Nothing in the app knows
          // the lot's rate — ratePerHourApplied only exists on a payment, which
          // is created at exit — so any figure here would be the app inventing
          // a number the server has not agreed to.
          Text(
            'The amount is calculated at exit from the gate reading.',
            style: context.text.bodySmall,
          ),
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
