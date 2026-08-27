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

class ParkingSlotsScreen extends ConsumerStatefulWidget {
  const ParkingSlotsScreen({super.key});

  @override
  ConsumerState<ParkingSlotsScreen> createState() => _ParkingSlotsScreenState();
}

class _ParkingSlotsScreenState extends ConsumerState<ParkingSlotsScreen> {
  SlotRecommendation? _recommendation;
  bool _isFinding = false;

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
    return AppScreen(
      title: 'Parking Availability',
      body: AsyncView(
        value: ref.watch(parkingAvailabilityProvider),
        onRefresh: () {
          ref.invalidate(parkingAvailabilityProvider);
          return ref.read(parkingAvailabilityProvider.future);
        },
        errorTitle: "Couldn't load slot availability",
        data: (availability) {
          final gates = _byGate(availability.slots);

          return ListView(
            padding: kScreenListPadding,
            children: [
              _AvailabilityCard(
                available: availability.availableSlots,
                total: availability.totalSlots,
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
              const _Legend(),
              const SizedBox(height: AppSpacing.md),
              for (final entry in gates.entries) ...[
                AppSectionHeader(title: 'Gate ${entry.key}'),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: entry.value.length,
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: AppSpacing.sm,
                    mainAxisSpacing: AppSpacing.sm,
                    childAspectRatio: 1,
                  ),
                  itemBuilder: (context, index) =>
                      _SlotTile(slot: entry.value[index]),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _AvailabilityCard extends StatelessWidget {
  const _AvailabilityCard({required this.available, required this.total});

  final int available;
  final int total;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return AppCard(
      color: t.brand.primary,
      borderColor: t.brand.pressed,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Available Now',
                style:
                    context.text.labelLarge?.copyWith(color: t.brand.onSolid),
              ),
              Text(
                '$available of $total',
                style: AppTypography.tabular(
                  context.text.displayLarge!.copyWith(
                    color: t.brand.onSolid,
                    fontSize: 28,
                  ),
                ),
              ),
            ],
          ),
          Icon(
            Icons.local_parking_rounded,
            color: t.brand.onSolid,
            size: 40,
          ),
        ],
      ),
    );
  }
}

/// The outcome of a slot request. Shows the pick *and why it was picked* — an
/// allocation that can explain itself is far easier to trust, and to defend.
class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({required this.recommendation});

  final SlotRecommendation recommendation;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    if (!recommendation.isAssigned) {
      final isNoVehicle =
          recommendation.result == AllocationResult.noVehicleRegistered;
      final c = t.status.danger;

      return AppCard(
        color: c.bg,
        borderColor: c.border,
        child: Row(
          children: [
            Icon(
              isNoVehicle ? Icons.no_transfer_rounded : Icons.block_rounded,
              color: c.fg,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                recommendation.reason ??
                    (isNoVehicle
                        ? 'Register a vehicle before requesting a slot.'
                        : 'No slots are free for your vehicle right now.'),
                style: context.text.bodyMedium?.copyWith(color: c.fg),
              ),
            ),
          ],
        ),
      );
    }

    final c = t.status.success;

    return AppCard(
      color: c.bg,
      borderColor: c.border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle_rounded, color: c.fg),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Gate ${recommendation.gate} · ${recommendation.slotCode}',
                  style: context.text.headlineSmall?.copyWith(color: c.fg),
                ),
              ),
            ],
          ),
          if (recommendation.reason != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              recommendation.reason!,
              style: context.text.bodySmall?.copyWith(color: t.text.primary),
            ),
          ],
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Not reserved — head over before someone else takes it.',
            style: context.text.labelSmall,
          ),
          if (recommendation.alternatives.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Also free: '
              '${recommendation.alternatives.map((a) => a.slotCode).join(', ')}',
              style: context.text.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _SlotTile extends StatelessWidget {
  const _SlotTile({required this.slot});

  final ParkingSlot slot;

  @override
  Widget build(BuildContext context) {
    final c = context.tokens.status.of(StatusIntents.slot(slot.status));

    return Semantics(
      label: '${slot.slotCode}, ${slot.status}',
      child: Container(
        decoration: BoxDecoration(
          color: c.bg,
          borderRadius: AppRadius.smAll,
          border: Border.all(color: c.border),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.directions_car_filled_rounded,
              color: c.fg,
              size: AppSizes.iconMd,
            ),
            const SizedBox(height: 2),
            Text(
              slot.slotCode,
              style: context.text.labelSmall?.copyWith(color: c.fg),
            ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.xs,
      children: const [
        _LegendItem(label: 'Available', status: 'Available'),
        _LegendItem(label: 'Occupied', status: 'Occupied'),
        _LegendItem(label: 'Out of Service', status: 'OutOfService'),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.label, required this.status});

  final String label;

  /// The raw API status, so the legend and the grid cannot disagree — both go
  /// through [StatusIntents.slot].
  final String status;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        StatusDot(intent: StatusIntents.slot(status)),
        const SizedBox(width: AppSpacing.xs),
        Text(label, style: context.text.labelSmall),
      ],
    );
  }
}
