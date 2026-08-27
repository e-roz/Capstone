import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/widgets.dart';
import '../../data/models/vehicle.dart';
import '../providers/vehicles_provider.dart';

/// Every vehicle the gate will open for, and the way to add another.
///
/// One RFID card covers all of them, which is why this is a list rather than a
/// single vehicle on the profile: the card in someone's bag is not what the gate
/// matches on, the plate is, and a second car was previously impossible to
/// register at all.
class VehiclesScreen extends ConsumerWidget {
  const VehiclesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myVehiclesProvider);

    return AppScreen(
      title: 'My vehicles',
      body: AsyncView(
        value: async,
        onRefresh: () async => ref.invalidate(myVehiclesProvider),
        errorTitle: "Couldn't load your vehicles",
        // No `isEmpty` slot: the add button has to stay reachable with no
        // vehicles on file, and that is exactly when it matters most. The empty
        // case is a card in the list instead.
        data: (vehicles) => ListView(
          padding: kScreenListPadding,
          children: [
            if (vehicles.isEmpty)
              const AppEmptyState(
                icon: Icons.directions_car_outlined,
                title: 'No vehicles yet',
                message: 'Add a vehicle so the gate knows to open for it.',
              )
            else
              for (final vehicle in vehicles) ...[
                _VehicleCard(vehicle: vehicle),
                const SizedBox(height: AppSpacing.md),
              ],
            const SizedBox(height: AppSpacing.sm),
            // Above the button, not below it. Telling someone what a button
            // will do *after* they have read past it is telling them too late,
            // and it left the button floating in the middle of the screen with
            // a paragraph stranded underneath.
            Text(
              'You will photograph the official receipt and the plate, the '
              'same as when you registered. The plate is read from the receipt '
              'rather than typed.',
              style: context.text.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'Add a vehicle',
              icon: const Icon(Icons.add),
              onPressed: () => context.push('/home/user/vehicles/add'),
            ),
          ],
        ),
      ),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({required this.vehicle});

  final Vehicle vehicle;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final expired = vehicle.isRegistrationExpired;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                vehicle.vehicleType == 'Motorcycle'
                    ? Icons.two_wheeler_rounded
                    : Icons.directions_car_rounded,
                color: t.brand.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  vehicle.plateNumber,
                  style: context.text.headlineSmall,
                ),
              ),
              AppStatusBadge(
                label: expired ? 'Expired' : vehicle.vehicleType,
                intent: expired ? StatusIntent.danger : StatusIntent.neutral,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            vehicle.color,
            style: context.text.bodyMedium?.copyWith(color: t.text.secondary),
          ),
          if (vehicle.registrationValidThrough != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              expired
                  ? 'Registration expired ${Formatters.date(vehicle.registrationValidThrough!)}'
                  : 'Registration valid through ${Formatters.date(vehicle.registrationValidThrough!)}',
              style: context.text.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
