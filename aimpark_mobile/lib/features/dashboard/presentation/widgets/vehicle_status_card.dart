import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../parking/data/models/parking_history_entry.dart';
import '../../../parking/presentation/providers/parking_history_provider.dart';
import '../../../vehicles/data/models/vehicle.dart';
import '../../../vehicles/presentation/providers/vehicles_provider.dart';
import '../../domain/vehicle_status.dart';

part 'vehicle_status_card.g.dart';

/// Which vehicle the card shows. There's no "primary vehicle" concept on the
/// account (see vehicle_status.dart), so this is a local, session-scoped
/// convenience — it resets on logout along with everything else Home reads,
/// and [VehicleStatusResolver.pickVehicle] already supplies a sensible
/// default (whichever car was driven most recently) when nothing's selected.
@riverpod
class SelectedVehicleId extends _$SelectedVehicleId {
  @override
  String? build() => null;

  void select(String id) => state = id;
}

/// Home screen card showing one vehicle's current parking status — plate,
/// "Parked now"/"Not parked", slot and duration when parked. A user with
/// more than one vehicle can switch which one it shows via the header's
/// "Switch" action.
class VehicleStatusCard extends ConsumerWidget {
  const VehicleStatusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehiclesAsync = ref.watch(myVehiclesProvider);
    // Degrades by disappearing rather than showing an error card — Home
    // already treats each section this way when its own data fails but the
    // rest of the screen still has something to show.
    if (vehiclesAsync.hasError) return const SizedBox.shrink();

    final vehicles = vehiclesAsync.valueOrNull ?? const <Vehicle>[];
    final selectedId = ref.watch(selectedVehicleIdProvider);
    final recentLogs = ref.watch(parkingHistoryNotifierProvider).valueOrNull?.logs ??
        const <ParkingHistoryEntry>[];
    final vehicle = VehicleStatusResolver.pickVehicle(vehicles, selectedId, recentLogs);

    if (vehicle == null) {
      return _NoVehicleRow(
        onTap: () => context.push('/home/user/vehicles/add'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: 'Your vehicle',
          action: vehicles.length > 1
              ? _SwitchAction(
                  onTap: () => _showSwitcher(context, ref, vehicles, vehicle.id),
                )
              : null,
        ),
        _VehicleRow(vehicle: vehicle),
      ],
    );
  }

  void _showSwitcher(
    BuildContext context,
    WidgetRef ref,
    List<Vehicle> vehicles,
    String selectedId,
  ) {
    final currentlyParkedVehicleId =
        ref.read(parkingHistoryNotifierProvider).valueOrNull?.currentlyParked?.vehicleId;

    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: AppRowGroup(
            children: [
              for (final vehicle in vehicles)
                AppListRow(
                  dense: true,
                  icon: vehicle.vehicleType == 'Motorcycle'
                      ? Icons.two_wheeler_rounded
                      : Icons.directions_car_rounded,
                  title: vehicle.plateNumber,
                  subtitle: '${vehicle.color} ${vehicle.vehicleType.toLowerCase()}',
                  showChevron: false,
                  trailing: vehicle.id == currentlyParkedVehicleId
                      ? const AppStatusBadge(
                          label: 'Parked now',
                          intent: StatusIntent.success,
                        )
                      : vehicle.id == selectedId
                          ? Icon(
                              Icons.check_rounded,
                              color: sheetContext.tokens.brand.primary,
                            )
                          : null,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    Navigator.of(sheetContext).pop();
                    ref.read(selectedVehicleIdProvider.notifier).select(vehicle.id);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwitchAction extends StatelessWidget {
  const _SwitchAction({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Switch',
            style: context.text.bodySmall?.copyWith(
              color: t.brand.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 2),
          Icon(Icons.unfold_more_rounded, size: AppSizes.iconSm, color: t.brand.primary),
        ],
      ),
    );
  }
}

class _NoVehicleRow extends StatelessWidget {
  const _NoVehicleRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppSectionHeader(title: 'Your vehicle'),
        AppListRow(
          icon: Icons.directions_car_rounded,
          title: 'Add your vehicle',
          subtitle: 'Register a vehicle to see its parking status here.',
          onTap: onTap,
        ),
      ],
    );
  }
}

/// The one-vehicle row, watching that vehicle's own latest-session lookup to
/// decide which of [VehicleStatus]'s states to show.
class _VehicleRow extends ConsumerWidget {
  const _VehicleRow({required this.vehicle});

  final Vehicle vehicle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehiclesCount = ref.watch(myVehiclesProvider).valueOrNull?.length ?? 1;
    final accountOpenSession =
        ref.watch(parkingHistoryNotifierProvider).valueOrNull?.currentlyParked;
    final latestAsync = ref.watch(vehicleLatestSessionProvider(vehicle.id));

    final icon = vehicle.vehicleType == 'Motorcycle'
        ? Icons.two_wheeler_rounded
        : Icons.directions_car_rounded;
    final note = '${vehicle.color} ${vehicle.vehicleType.toLowerCase()}';

    if (latestAsync.isLoading && !latestAsync.hasValue) {
      return AppListRow(
        icon: icon,
        title: vehicle.plateNumber,
        subtitle: 'Checking…',
        note: Text(note, style: context.text.bodySmall),
        onTap: () => _openHistory(context),
      );
    }

    if (latestAsync.hasError) {
      return AppListRow(
        icon: icon,
        title: vehicle.plateNumber,
        subtitle: 'Status unavailable',
        note: Text(note, style: context.text.bodySmall),
        onTap: () => _openHistory(context),
      );
    }

    final status = VehicleStatusResolver.resolve(
      vehicle: vehicle,
      vehicleCount: vehiclesCount,
      accountOpenSession: accountOpenSession,
      latestForVehicle: latestAsync.valueOrNull,
    );

    return switch (status) {
      VehicleParked(entry: final entry) => AppListRow(
          icon: icon,
          title: vehicle.plateNumber,
          subtitle: '${entry.slotCode ?? 'No slot'} · '
              '${Formatters.sessionRange(entry.entryTime, null, entry.duration)}',
          note: Text(note, style: context.text.bodySmall),
          trailing: const AppStatusBadge(
            label: 'Parked now',
            intent: StatusIntent.success,
          ),
          onTap: () => _openHistory(context),
        ),
      VehicleUnconfirmed(entry: final entry) => AppListRow(
          icon: icon,
          title: vehicle.plateNumber,
          subtitle: 'Card inside · '
              '${Formatters.sessionRange(entry.entryTime, null, entry.duration)}',
          note: Text(
            "Camera didn't confirm which vehicle",
            style: context.text.bodySmall,
          ),
          trailing: const AppStatusBadge(
            label: 'Card in use',
            intent: StatusIntent.info,
          ),
          onTap: () => context.push('/home/user/parking-history'),
        ),
      VehicleAway(lastSeen: final lastSeen) => AppListRow(
          icon: icon,
          title: vehicle.plateNumber,
          subtitle: 'Last seen ${Formatters.relativeTime(lastSeen)}',
          note: Text(note, style: context.text.bodySmall),
          trailing: const AppStatusBadge(
            label: 'Not parked',
            intent: StatusIntent.neutral,
          ),
          onTap: () => _openHistory(context),
        ),
      VehicleNeverSeen() => AppListRow(
          icon: icon,
          title: vehicle.plateNumber,
          subtitle: 'No visits yet',
          note: Text(note, style: context.text.bodySmall),
          trailing: const AppStatusBadge(
            label: 'Not parked',
            intent: StatusIntent.neutral,
          ),
          onTap: () => _openHistory(context),
        ),
    };
  }

  void _openHistory(BuildContext context) {
    context.push('/home/user/parking-history?vehicle=${vehicle.id}');
  }
}
