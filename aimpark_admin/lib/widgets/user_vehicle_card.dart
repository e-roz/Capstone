import 'package:flutter/material.dart';

import '../models/registration_detail.dart';
import '../theme/theme.dart';
import 'ui/ui.dart';

/// One vehicle on a user's page.
///
/// The plate is the biggest thing on the card because it is what a guard and an
/// admin look a vehicle up by. What the vehicle *is* (car, motorcycle, e-bike)
/// and which bays it parks in are two different questions, so they are two
/// different fields: an e-bike is an e-bike, and "car bay" only says it is too
/// big for the motorcycle ones.
class UserVehicleCard extends StatelessWidget {
  const UserVehicleCard({
    super.key,
    required this.vehicle,
    this.index = 0,
    this.count = 1,
  });

  final VehicleInfo vehicle;
  final int index;
  final int count;

  /// EB0007 as people write it: EB-0007.
  static String plateText(VehicleInfo v) {
    final plate = v.plateNumber;
    if (plate == null || plate.isEmpty) return '—';
    return v.isEBike && plate.startsWith('EB') && plate.length > 2
        ? 'EB-${plate.substring(2)}'
        : plate;
  }

  /// The stored vehicle type is the bay type the allocator matches on.
  static String parkingSpaceType(String? stored) => switch (stored) {
        'Motorcycle' => 'Motorcycle bay',
        'Car' => 'Car bay',
        _ => '—',
      };

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    final isEBike = vehicle.isEBike;
    final kind = isEBike ? 'E-bike' : (vehicle.vehicleType ?? '—');
    final isMotorcycleBay = vehicle.vehicleType == 'Motorcycle';

    final kindIcon = isEBike
        ? Icons.pedal_bike_outlined
        : isMotorcycleBay
            ? Icons.two_wheeler_outlined
            : Icons.directions_car_outlined;

    final tone = isEBike ? t.status.accent : t.status.neutral;

    return AppCard(
      selected: isEBike,
      accentColor: t.status.accent.fg,
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(kindIcon,
                  size: AppSizes.iconMd,
                  color: isEBike ? t.status.accent.fg : t.text.secondary),
              const SizedBox(width: AppSpacing.x2),
              Text(
                count > 1 ? 'Vehicle ${index + 1} of $count' : 'Vehicle',
                style: text.titleMedium,
              ),
              const Spacer(),
              StatusPill(
                label: kind,
                intent: isEBike ? StatusIntent.accent : StatusIntent.neutral,
                showDot: false,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x4),
          Wrap(
            spacing: AppSpacing.x8,
            runSpacing: AppSpacing.x4,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              _Labelled(
                label: isEBike ? 'Temporary plate' : 'Plate number',
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.x4, vertical: AppSpacing.x2),
                  decoration: BoxDecoration(
                    color: tone.bg,
                    border: Border.all(color: tone.fg, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    plateText(vehicle),
                    style: text.headlineSmall?.copyWith(
                      fontFamily: 'IBM Plex Mono',
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2,
                      color: tone.fg,
                    ),
                  ),
                ),
              ),
              _Labelled(
                label: 'Parking space type',
                child: StatusPill(
                  label: parkingSpaceType(vehicle.vehicleType),
                  intent: StatusIntent.info,
                  icon: isMotorcycleBay
                      ? Icons.two_wheeler_outlined
                      : Icons.directions_car_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x4),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.x4),
          AppFieldGrid(
            fields: [
              AppField(label: 'Vehicle type', value: kind),
              if (isEBike) AppField(label: 'Brand', value: vehicle.brand ?? '—'),
              AppField(label: 'Colour', value: vehicle.color ?? '—'),
              if (vehicle.distinguishingMarks case final marks?)
                AppField(label: 'Marks', value: marks),
            ],
          ),
        ],
      ),
    );
  }
}

class _Labelled extends StatelessWidget {
  const _Labelled({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: t.text.tertiary)),
        const SizedBox(height: AppSpacing.x1),
        child,
      ],
    );
  }
}
