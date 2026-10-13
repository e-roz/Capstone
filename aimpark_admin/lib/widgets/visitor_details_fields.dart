import 'package:flutter/material.dart';

import '../theme/theme.dart';
import 'ui/ui.dart';

/// What the guard writes down about a visitor: name, plate and purpose. Shared by the desk's "Issue a card" dialog and the form that pops
/// up when an idle visitor card is tapped at the gate, so both ask exactly
/// the same thing.
class VisitorDetailsFields extends StatelessWidget {
  const VisitorDetailsFields({
    super.key,
    required this.name,
    required this.plate,
    required this.purpose,
    this.autofocusName = false,
  });

  final TextEditingController name;
  final TextEditingController plate;
  final TextEditingController purpose;
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
