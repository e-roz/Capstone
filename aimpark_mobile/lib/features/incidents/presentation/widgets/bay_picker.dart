import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../parking/data/models/parking_slot.dart';
import '../../../parking/presentation/providers/parking_history_provider.dart';
import '../../../parking/presentation/widgets/parking_map.dart';

/// The bay a report is about, picked from the same lot map drivers confirm
/// their bay on.
///
/// Optional: plenty of reports are not about a bay (the gate, the exit lane),
/// and those keep the typed location. When a bay is picked, the parking office
/// sees who was parked in it around the time of the report, which is what turns
/// a report into a violation without digging through the gate logs.
class BayPickerField extends StatelessWidget {
  const BayPickerField({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final ParkingSlot? value;
  final ValueChanged<ParkingSlot?> onChanged;
  final bool enabled;

  Future<void> _pick(BuildContext context) async {
    final picked = await showModalBottomSheet<ParkingSlot>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _BayPickerSheet(),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final bay = value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Bay', style: context.text.labelLarge),
        const SizedBox(height: AppSpacing.xs),
        AppCard(
          padding: EdgeInsets.zero,
          child: AppListRow(
            icon: bay == null
                ? Icons.local_parking_rounded
                : (bay.isMotorcycle
                      ? Icons.two_wheeler_rounded
                      : Icons.directions_car_rounded),
            title: bay == null ? 'Pick a bay on the map' : 'Bay ${bay.slotCode}',
            subtitle: bay == null
                ? 'If it happened at a parking bay'
                : 'Gate ${bay.gate} · '
                      '${bay.isMotorcycle ? 'Motorcycle' : 'Car'} bay',
            onTap: enabled ? () => _pick(context) : null,
            showChevron: bay == null,
            trailing: bay == null
                ? null
                : IconButton(
                    tooltip: 'Remove bay',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: enabled ? () => onChanged(null) : null,
                  ),
          ),
        ),
      ],
    );
  }
}

class _BayPickerSheet extends ConsumerWidget {
  const _BayPickerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final availability = ref.watch(parkingAvailabilityNotifierProvider);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        children: [
          Text('Which bay?', style: context.text.headlineSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Tap the bay where it happened.',
            style: context.text.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          switch (availability) {
            AsyncData(:final value) => ParkingMap(
              availability: value,
              onPickSlot: (slot) => Navigator.of(context).pop(slot),
            ),
            AsyncError() => AppNotice(
              intent: StatusIntent.danger,
              message:
                  "Couldn't load the lot map. Close this and type the "
                  'location instead.',
            ),
            _ => const Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: Center(child: CircularProgressIndicator()),
            ),
          },
        ],
      ),
    );
  }
}
