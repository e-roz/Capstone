import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/api_error_message.dart';
import '../../../../core/utils/app_flushbar.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../data/models/parking_slot.dart';
import '../providers/parking_history_provider.dart';

/// Distinct gates present in the current slot list, ascending.
List<int> _gatesIn(List<ParkingSlot> slots) =>
    slots.map((s) => s.gate).toSet().toList()..sort();

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
      if (mounted) showAppMessage(context, apiErrorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _isFinding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final availabilityAsync = ref.watch(parkingAvailabilityProvider);

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        backgroundColor: AppColors.bgPage,
        elevation: 0,
        title: Text('Parking Availability', style: AppTextStyles.h3),
      ),
      body: SafeArea(
        child: availabilityAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: TextButton(
              onPressed: () => ref.invalidate(parkingAvailabilityProvider),
              child: const Text('Retry'),
            ),
          ),
          data: (availability) {
            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(parkingAvailabilityProvider),
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  AppCard(
                    color: AppColors.brandDefault,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Available Now',
                              style: AppTextStyles.labelBold.copyWith(color: AppColors.textOnBrand),
                            ),
                            Text(
                              '${availability.availableSlots} of ${availability.totalSlots}',
                              style: AppTextStyles.displayHero.copyWith(
                                color: AppColors.textOnBrand,
                                fontSize: 28,
                              ),
                            ),
                          ],
                        ),
                        const Icon(Icons.local_parking_rounded,
                            color: AppColors.textOnBrand, size: 40),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: 'Find me a slot',
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
                  for (final gate in _gatesIn(availability.slots)) ...[
                    Text('Gate $gate', style: AppTextStyles.h3),
                    const SizedBox(height: AppSpacing.sm),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount:
                          availability.slots.where((s) => s.gate == gate).length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        crossAxisSpacing: AppSpacing.sm,
                        mainAxisSpacing: AppSpacing.sm,
                        childAspectRatio: 1,
                      ),
                      itemBuilder: (context, index) => _SlotTile(
                        slot: availability.slots
                            .where((s) => s.gate == gate)
                            .elementAt(index),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

({Color bg, Color fg}) _colorsFor(String status) {
  switch (status.toLowerCase()) {
    case 'available':
      return (bg: AppColors.successSubtle, fg: AppColors.successPressed);
    case 'occupied':
      return (bg: AppColors.errorSubtle, fg: AppColors.errorPressed);
    default:
      return (bg: AppColors.bgSurfaceAlt, fg: AppColors.textSecondary);
  }
}

/// The outcome of a slot request. Shows the pick *and why it was picked* —
/// an allocation that can explain itself is far easier to trust, and to defend.
class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({required this.recommendation});

  final SlotRecommendation recommendation;

  @override
  Widget build(BuildContext context) {
    if (!recommendation.isAssigned) {
      final isNoVehicle =
          recommendation.result == AllocationResult.noVehicleRegistered;
      return AppCard(
        color: AppColors.errorSubtle,
        child: Row(
          children: [
            Icon(
              isNoVehicle ? Icons.no_transfer_rounded : Icons.block_rounded,
              color: AppColors.errorPressed,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                recommendation.reason ??
                    (isNoVehicle
                        ? 'Register a vehicle before requesting a slot.'
                        : 'No slots are free for your vehicle right now.'),
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.errorPressed),
              ),
            ),
          ],
        ),
      );
    }

    return AppCard(
      color: AppColors.successSubtle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: AppColors.successPressed),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Gate ${recommendation.gate} · ${recommendation.slotCode}',
                  style: AppTextStyles.h3
                      .copyWith(color: AppColors.successPressed),
                ),
              ),
            ],
          ),
          if (recommendation.reason != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(recommendation.reason!, style: AppTextStyles.bodySmall),
          ],
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Not reserved — head over before someone else takes it.',
            style: AppTextStyles.labelSmall
                .copyWith(color: AppColors.textSecondary),
          ),
          if (recommendation.alternatives.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Also free: ${recommendation.alternatives.map((a) => a.slotCode).join(', ')}',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary),
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
    final colors = _colorsFor(slot.status);
    return Container(
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.directions_car_filled_rounded, color: colors.fg, size: 20),
          const SizedBox(height: 2),
          Text(
            slot.slotCode,
            style: AppTextStyles.labelSmall.copyWith(color: colors.fg, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        _LegendItem(label: 'Available', status: 'available'),
        SizedBox(width: AppSpacing.md),
        _LegendItem(label: 'Occupied', status: 'occupied'),
        SizedBox(width: AppSpacing.md),
        _LegendItem(label: 'Out of Service', status: 'outofservice'),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.label, required this.status});
  final String label;
  final String status;

  @override
  Widget build(BuildContext context) {
    final colors = _colorsFor(status);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: colors.fg, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: AppTextStyles.labelSmall),
      ],
    );
  }
}
