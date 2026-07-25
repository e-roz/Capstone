import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_card.dart';
import '../../data/models/parking_slot.dart';
import '../providers/parking_history_provider.dart';

class ParkingSlotsScreen extends ConsumerWidget {
  const ParkingSlotsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                  const SizedBox(height: AppSpacing.lg),
                  const _Legend(),
                  const SizedBox(height: AppSpacing.md),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: availability.slots.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: AppSpacing.sm,
                      mainAxisSpacing: AppSpacing.sm,
                      childAspectRatio: 1,
                    ),
                    itemBuilder: (context, index) => _SlotTile(slot: availability.slots[index]),
                  ),
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
