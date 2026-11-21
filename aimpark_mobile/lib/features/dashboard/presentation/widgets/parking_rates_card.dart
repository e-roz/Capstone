import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../payments/data/models/parking_rate.dart';
import '../../../payments/presentation/providers/payments_provider.dart';
import '../../../vehicles/data/models/vehicle.dart';

/// What parking costs, per vehicle type, so a driver knows before coming in.
///
/// The driver's own vehicle type is marked. A rate that changed in the last
/// week says so, since the notice about it may have been missed.
///
/// Draws nothing if the rates fail to load: the price is useful to know, but
/// not worth an error card on a screen that already has several.
class ParkingRatesCard extends ConsumerWidget {
  const ParkingRatesCard({super.key, required this.vehicles});

  final List<Vehicle> vehicles;

  static const _recent = Duration(days: 7);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ratesAsync = ref.watch(parkingRatesProvider);

    return ratesAsync.when(
      loading: () => const AppSkeleton.block(height: 120),
      error: (_, _) => const SizedBox.shrink(),
      data: (rates) {
        if (rates.isEmpty) return const SizedBox.shrink();

        final hasCar = vehicles.any((v) => !v.isMotorcycle);
        final hasMotorcycle = vehicles.any((v) => v.isMotorcycle);
        final now = DateTime.now();

        return AppFactsCard(
          title: 'Parking rates',
          facts: [
            for (final rate in rates)
              AppFact(
                rate.vehicleType,
                '${Formatters.peso(rate.ratePerHour)} first hour, then '
                '${Formatters.peso(rate.ratePerHour / 60)} a minute',
                intent: _isMine(rate, hasCar, hasMotorcycle)
                    ? StatusIntent.brand
                    : null,
                note: _note(rate, hasCar, hasMotorcycle, now),
              ),
          ],
        );
      },
    );
  }

  static bool _isMine(ParkingRate rate, bool hasCar, bool hasMotorcycle) =>
      rate.isMotorcycle ? hasMotorcycle : hasCar;

  static String _note(
    ParkingRate rate,
    bool hasCar,
    bool hasMotorcycle,
    DateTime now,
  ) {
    final parts = <String>[
      if (_isMine(rate, hasCar, hasMotorcycle)) 'Your vehicle',
      if (now.difference(rate.updatedAt) < _recent)
        'Changed ${Formatters.relativeTime(rate.updatedAt.toLocal()).toLowerCase()}',
    ];
    return parts.join(' · ');
  }
}
