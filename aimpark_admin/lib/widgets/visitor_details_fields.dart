import 'package:flutter/material.dart';

import '../theme/theme.dart';
import 'ui/ui.dart';

/// What the guard writes down about a visitor: name, plate, vehicle type and
/// purpose. Shared by the desk's "Issue a card" dialog and the form that pops
/// up when an idle visitor card is tapped at the gate, so both ask exactly
/// the same thing.
class VisitorDetailsFields extends StatelessWidget {
  const VisitorDetailsFields({
    super.key,
    required this.name,
    required this.plate,
    required this.purpose,
    required this.vehicleType,
    required this.onVehicleTypeChanged,
    this.autofocusName = false,
  });

  final TextEditingController name;
  final TextEditingController plate;
  final TextEditingController purpose;
  final String vehicleType;
  final ValueChanged<String> onVehicleTypeChanged;
  final bool autofocusName;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextFormField(
          controller: name,
          autofocus: autofocusName,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            label: AppFieldLabel('Visitor name', isRequired: true),
          ),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'The name is required' : null,
        ),
        const SizedBox(height: AppSpacing.x3),
        TextFormField(
          controller: plate,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            label: AppFieldLabel('Plate number', isRequired: true),
            helperText: 'What is on the car. This is what the gate check '
                'will compare against.',
          ),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'The plate is required' : null,
        ),
        const SizedBox(height: AppSpacing.x3),
        DropdownButtonFormField<String>(
          initialValue: vehicleType,
          decoration: const InputDecoration(
            label: AppFieldLabel('Vehicle type', isRequired: true),
            helperText: 'Decides which bays they can be given.',
          ),
          items: const [
            DropdownMenuItem(value: 'Car', child: Text('Car')),
            DropdownMenuItem(value: 'Motorcycle', child: Text('Motorcycle')),
          ],
          onChanged: (v) => onVehicleTypeChanged(v!),
        ),
        const SizedBox(height: AppSpacing.x3),
        TextFormField(
          controller: purpose,
          decoration: const InputDecoration(
            label: AppFieldLabel('Purpose of visit'),
            helperText: 'Who or what they are here for.',
          ),
        ),
      ],
    );
  }
}
