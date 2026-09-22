import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/utils/app_flushbar.dart';
import '../../../../core/widgets/widgets.dart';
import '../../data/models/parking_slot.dart';
import '../providers/parking_history_provider.dart';

/// The slots on show, grouped by gate and in gate order.
///
/// Built once per load. The grid used to call `slots.where((s) => s.gate ==
/// gate).elementAt(index)` inside its `itemBuilder` and `.where(...).length`
/// for its `itemCount`, which is a full scan of every slot in the facility for
/// every tile it drew — quadratic, on the one screen a user opens while sitting
/// at the gate waiting to get in.
Map<int, List<ParkingSlot>> _byGate(List<ParkingSlot> slots) {
  final grouped = <int, List<ParkingSlot>>{};
  for (final slot in slots) {
    grouped.putIfAbsent(slot.gate, () => []).add(slot);
  }
  return Map.fromEntries(
    grouped.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
  );
}

/// Which vehicles the grid is showing.
enum _SlotFilter { all, car, motorcycle }

/// How a single slot reads on the map.
///
/// Deliberately not [StatusIntents.slot]. That maps `occupied` to the brand
/// tone, which was fine while nothing else on the grid was branded — but the
/// map now has to say *which slot is yours*, and there is only one brand
/// colour. Yours takes it; taken drops back to a muted well.
enum _SlotState {
  free,
  taken,
  outOfService,
  yours;

  static _SlotState of(ParkingSlot slot, String? myCode) {
    if (myCode != null && slot.slotCode == myCode) return yours;
    return switch (slot.status.toLowerCase()) {
      'available' => free,
      'outofservice' || 'out of service' => outOfService,
      _ => taken,
    };
  }

  String get label => switch (this) {
    _SlotState.free => 'Free',
    _SlotState.taken => 'Taken',
    _SlotState.outOfService => 'Out of service',
    _SlotState.yours => 'Yours',
  };
}

/// The fill, border and ink for one slot state. One function so the legend and
/// the grid cannot drift apart — they were two separate colour decisions
/// before, and had already disagreed about green.
({Color bg, Color border, Color fg}) _slotColors(
  BuildContext context,
  _SlotState state,
) {
  final t = context.tokens;
  return switch (state) {
    // Mint rather than success green: a free slot is not a verdict about the
    // user, it is a place. Green here read as "you did something right".
    _SlotState.free => (
      bg: t.surface.card,
      border: t.tertiary.primary,
      fg: t.text.primary,
    ),
    _SlotState.taken => (
      bg: t.surface.muted,
      border: t.border.strong,
      fg: t.text.disabled,
    ),
    _SlotState.outOfService => (
      bg: t.surface.muted,
      border: t.border.normal,
      fg: t.text.disabled,
    ),
    _SlotState.yours => (
      bg: t.brand.primary,
      border: t.brand.primary,
      fg: t.brand.onSolid,
    ),
  };
}

class ParkingSlotsScreen extends ConsumerStatefulWidget {
  const ParkingSlotsScreen({super.key});

  @override
  ConsumerState<ParkingSlotsScreen> createState() => _ParkingSlotsScreenState();
}

class _ParkingSlotsScreenState extends ConsumerState<ParkingSlotsScreen> {
  SlotRecommendation? _recommendation;
  bool _isFinding = false;
  _SlotFilter _filter = _SlotFilter.all;

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

  bool _matchesFilter(ParkingSlot slot) {
    final isMotorcycle = (slot.vehicleType ?? '').toLowerCase().contains(
      'motor',
    );
    return switch (_filter) {
      _SlotFilter.all => true,
      _SlotFilter.car => !isMotorcycle,
      _SlotFilter.motorcycle => isMotorcycle,
    };
  }

  @override
  Widget build(BuildContext context) {
    // Which slot is the user's own, so the map can say so. Null when they are
    // not parked, which is the common case on this screen.
    final myCode = ref
        .watch(parkingHistoryNotifierProvider)
        .valueOrNull
        ?.currentlyParked
        ?.slotCode;

    return AppScreen(
      body: AsyncView(
        value: ref.watch(parkingAvailabilityProvider),
        onRefresh: () {
          ref.invalidate(parkingAvailabilityProvider);
          return ref.read(parkingAvailabilityProvider.future);
        },
        errorTitle: "Couldn't load slot availability",
        data: (availability) {
          final gates = _byGate(
            availability.slots.where(_matchesFilter).toList(),
          );

          return ListView(
            padding: kScreenListPadding,
            children: [
              const AppScreenTitle(title: 'Select a slot'),
              AppChipGroup<_SlotFilter>(
                label: 'Show',
                value: _filter,
                options: const {
                  _SlotFilter.all: 'All',
                  _SlotFilter.car: 'Cars',
                  _SlotFilter.motorcycle: 'Motorcycles',
                },
                onChanged: (f) => setState(() => _filter = f),
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'Find me a slot',
                icon: const Icon(Icons.explore_rounded),
                isLoading: _isFinding,
                onPressed: _isFinding ? null : _findSlot,
              ),
              if (_recommendation != null) ...[
                const SizedBox(height: AppSpacing.md),
                _RecommendationCard(recommendation: _recommendation!),
              ],
              const SizedBox(height: AppSpacing.lg),
              _Legend(showYours: myCode != null),
              const SizedBox(height: AppSpacing.md),
              if (gates.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  child: Text(
                    'No slots match this filter.',
                    textAlign: TextAlign.center,
                    style: context.text.bodyMedium,
                  ),
                )
              else
                for (final entry in gates.entries) ...[
                  AppSectionHeader(title: 'Gate ${entry.key}'),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: entry.value.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: AppSpacing.gutter,
                      mainAxisSpacing: AppSpacing.gutter,
                      // Slightly wider than tall: a code and a type tag stacked
                      // in a square left the tag clipped at 360dp.
                      childAspectRatio: 1.15,
                    ),
                    itemBuilder: (context, index) => _SlotTile(
                      slot: entry.value[index],
                      state: _SlotState.of(entry.value[index], myCode),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
              const SizedBox(height: AppSpacing.sm),
              // Said plainly, because the grid looks exactly like a seat picker
              // and a seat picker holds your seat. This one does not — the
              // reservation feature is still deferred, and a user who thinks
              // otherwise finds out at the gate.
              Text(
                'Browsing slots does not hold one for you. Entry is confirmed '
                'by your RFID card at the gate.',
                style: context.text.bodySmall,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SlotTile extends StatelessWidget {
  const _SlotTile({required this.slot, required this.state});

  final ParkingSlot slot;
  final _SlotState state;

  /// `CAR` / `MC`, matching the codes painted on the bays themselves.
  String get _typeTag {
    final type = (slot.vehicleType ?? '').toLowerCase();
    if (type.isEmpty) return '';
    return type.contains('motor') ? 'MC' : 'CAR';
  }

  @override
  Widget build(BuildContext context) {
    final c = _slotColors(context, state);
    final tag = _typeTag;

    return Semantics(
      label:
          '${slot.slotCode}, ${state.label}'
          '${tag.isEmpty ? '' : ', ${tag == 'MC' ? 'motorcycle' : 'car'}'}',
      child: Container(
        decoration: BoxDecoration(
          color: c.bg,
          borderRadius: AppRadius.smAll,
          border: Border.all(color: c.border, width: 1.5),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              slot.slotCode,
              style: context.text.titleSmall?.copyWith(color: c.fg),
            ),
            if (tag.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                tag,
                style: context.text.labelSmall?.copyWith(
                  color: c.fg.withValues(alpha: 0.8),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.showYours});

  /// Only listed when one of the slots on screen actually is theirs. A key to a
  /// colour that appears nowhere on the map is noise.
  final bool showYours;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.xs,
      children: [
        const _LegendItem(state: _SlotState.free),
        const _LegendItem(state: _SlotState.taken),
        const _LegendItem(state: _SlotState.outOfService),
        if (showYours) const _LegendItem(state: _SlotState.yours),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.state});

  final _SlotState state;

  @override
  Widget build(BuildContext context) {
    final c = _slotColors(context, state);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // A swatch of the real tile rather than a dot: the states differ by
        // fill *and* border, and a dot can only show one of them.
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: c.bg,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: c.border, width: 1.5),
          ),
        ),
        const SizedBox(width: 6),
        Text(state.label, style: context.text.labelSmall),
      ],
    );
  }
}

/// What `POST /api/parking/recommend` came back with.
class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({required this.recommendation});

  final SlotRecommendation recommendation;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final assigned = recommendation.isAssigned;
    final c = assigned ? t.status.success : t.status.warning;

    return AppCard(
      color: c.bg,
      borderColor: c.border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            assigned ? 'SUGGESTED SLOT' : 'NO SLOT AVAILABLE',
            style: context.text.labelMedium?.copyWith(color: c.fg),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (assigned) ...[
            Text(
              '${recommendation.slotCode} · Gate ${recommendation.gate}',
              style: context.text.headlineMedium,
            ),
            const SizedBox(height: 2),
            Text(
              'Head for this one. It is not held for you — the gate still '
              'decides when your card is read.',
              style: context.text.bodySmall,
            ),
          ] else ...[
            Text(
              recommendation.reason ?? 'Nothing is free right now.',
              style: context.text.bodyMedium,
            ),
            if (recommendation.alternatives.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Try instead: '
                '${recommendation.alternatives.map((a) => a.slotCode).join(', ')}',
                style: context.text.bodySmall,
              ),
            ],
          ],
        ],
      ),
    );
  }
}
