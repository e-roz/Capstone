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
            _AddVehicleButton(
              onTap: () => context.push('/home/user/vehicles/add'),
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
    final validThrough = vehicle.registrationValidThrough;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                // The plate is the headline. It is what the gate matches on and
                // what the owner recognises the row by — the vehicle type was
                // taking the badge slot to say "Car" next to a picture of a car.
                child: Text(
                  vehicle.plateNumber,
                  style: AppTypography.tabular(context.text.headlineMedium!),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              AppStatusBadge(
                label: expired ? 'Expired' : 'Active',
                intent: expired ? StatusIntent.danger : StatusIntent.success,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.labelGap),
          Text(
            '${vehicle.color} · ${vehicle.vehicleType}',
            style: context.text.bodyMedium?.copyWith(color: t.text.secondary),
          ),
          if (validThrough != null) ...[
            const SizedBox(height: 2),
            Text(
              expired
                  ? 'Registration expired ${Formatters.date(validThrough)}'
                  : 'Registration valid to ${Formatters.date(validThrough)}',
              style: context.text.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

/// The "add another" affordance, drawn as an outline waiting to be filled.
///
/// A dashed border rather than a solid one because this button is not an action
/// on the list above it — it is an empty slot in that list. A solid primary
/// button here competed with the vehicle cards for attention on a screen whose
/// whole job is showing you the vehicles.
class _AddVehicleButton extends StatelessWidget {
  const _AddVehicleButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Semantics(
      button: true,
      label: 'Register a vehicle',
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.mdAll,
        child: CustomPaint(
          painter: _DashedBorderPainter(
            color: t.border.strong,
            radius: AppRadius.md,
          ),
          child: SizedBox(
            height: AppSizes.controlHeight,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_rounded, size: 18, color: t.brand.subtleText),
                const SizedBox(width: AppSpacing.xs + 4),
                Text(
                  'Register a vehicle',
                  style: context.text.labelLarge?.copyWith(
                    color: t.brand.subtleText,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Flutter has no dashed [BorderSide], so the outline is stroked by hand.
///
/// Walks the rounded rectangle's path with a [PathMetric] and emits alternating
/// on/off segments, which keeps the dashes even around the corners — stroking
/// four straight edges separately leaves the curves either solid or bare.
class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  /// Dash and gap are fixed rather than parameters: there is one dashed outline
  /// in the app, and a second one that did not match it would be worse than
  /// either.
  static const double _dash = 6;
  static const double _gap = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..isAntiAlias = true;

    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      );

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + _dash;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0.0, metric.length)),
          paint,
        );
        distance = next + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}
