import 'package:flutter/material.dart';

import '../../theme/theme.dart';

/// An input label that says whether the field has to be filled in.
///
/// Every dialog in the panel previously left this to the validator: you found
/// out a field was required by pressing Save and being told off. Marking it up
/// front is the difference between a form that guides you and one that catches
/// you out — and it was the single most repeated note in tester feedback, on
/// Policy Rules, Notifications and Add Slot alike.
///
/// Use it through [InputDecoration.label] rather than `labelText`:
///
/// ```dart
/// TextFormField(
///   decoration: const InputDecoration(label: AppFieldLabel('Title', isRequired: true)),
/// )
/// ```
///
/// The asterisk is the convention people already read as "required", and it is
/// backed by [AppRequiredNote] at the top of the form so it is never the only
/// explanation. Colour alone is not carrying the meaning, so this stays legible
/// to anyone who cannot separate the red.
class AppFieldLabel extends StatelessWidget {
  const AppFieldLabel(this.text, {super.key, this.isRequired = false});

  final String text;
  final bool isRequired;

  @override
  Widget build(BuildContext context) {
    if (!isRequired) return Text(text);

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: text),
          TextSpan(
            text: ' *',
            style: TextStyle(color: context.tokens.status.danger.fg),
          ),
        ],
      ),
    );
  }
}

/// The legend that explains the asterisks. Put it at the top of any form that
/// uses [AppFieldLabel], so the marker is defined before it is used.
class AppRequiredNote extends StatelessWidget {
  const AppRequiredNote({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.x3),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '*',
                style: TextStyle(color: t.status.danger.fg),
              ),
              const TextSpan(text: ' Required field'),
            ],
          ),
          style: text.labelSmall?.copyWith(color: t.text.secondary),
        ),
      ),
    );
  }
}
