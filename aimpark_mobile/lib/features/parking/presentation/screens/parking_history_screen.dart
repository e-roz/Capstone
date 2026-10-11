import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../payments/data/models/payment.dart';
import '../../../payments/presentation/providers/payments_provider.dart';
import '../../../vehicles/data/models/vehicle.dart';
import '../../../vehicles/presentation/providers/vehicles_provider.dart';
import '../providers/parking_history_provider.dart';
import '../widgets/parking_session_row.dart';

class ParkingHistoryScreen extends ConsumerWidget {
  const ParkingHistoryScreen({super.key, this.vehicleId});

  /// When set, shows only this vehicle's sessions (see the Home screen's
  /// vehicle card) rather than every session on the account.
  final String? vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filtered = vehicleId != null;
    final value = filtered
        ? ref.watch(vehicleHistoryProvider(vehicleId!))
        : ref.watch(parkingHistoryNotifierProvider);

    Future<void> refresh() => filtered
        ? ref.refresh(vehicleHistoryProvider(vehicleId!).future)
        : ref.read(parkingHistoryNotifierProvider.notifier).refresh();

    final allVehicles = ref.watch(myVehiclesProvider).valueOrNull ?? const <Vehicle>[];

    // The bills already on hand, so each visit can show what it cost.
    final billsById = {
      for (final p in ref.watch(paymentsNotifierProvider).valueOrNull?.payments ??
          const <Payment>[])
        p.paymentId: p,
    };

    String? plate;
    if (filtered) {
      final vehicles = allVehicles;
      for (final vehicle in vehicles) {
        if (vehicle.id == vehicleId) {
          plate = vehicle.plateNumber;
          break;
        }
      }
    }

    return AppScreen(
      body: AsyncView(
        value: value,
        onRefresh: refresh,
        errorTitle: "Couldn't load your history",
        loading: const Padding(
          padding: kScreenListPadding,
          child: AppRowSkeleton(),
        ),
        isEmpty: (result) => result.logs.isEmpty,
        empty: AppEmptyState(
          icon: Icons.local_parking_rounded,
          title: 'No parking history yet',
          message: filtered
              ? 'No visits recorded for this vehicle yet.'
              : 'Your entries and exits will show up here.',
        ),
        data: (result) => ListView(
          padding: kScreenListPadding,
          children: [
            AppScreenTitle(
              title: 'History',
              subtitle: filtered ? (plate ?? 'One vehicle') : null,
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            ),
            AppRowGroup(
              children: [
                for (final log in result.logs)
                  ParkingSessionRow(
                    entry: log,
                    payment: billsById[log.paymentId],
                    plate: ParkingSessionRow.plateFor(log, allVehicles),
                    onTap: log.paymentId == null
                        ? null
                        : () => context.push(
                              '/home/user/payments/${log.paymentId}',
                            ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
