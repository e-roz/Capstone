import 'package:flutter/material.dart';

import '../../theme/theme.dart';

/// A read-only label/value pair — the unit every detail screen is built from.
///
/// Replaces the two separate private `_Field` classes in User Detail and
/// Registration Detail, which had drifted to different label sizes.
class AppField extends StatelessWidget {
  const AppField({
    super.key,
    required this.label,
    this.value,
    this.child,
    this.emphasis = false,
  }) : assert(value != null || child != null,
            'AppField needs either a value or a child');

  final String label;

  /// Plain text value. Use [child] instead when the value is a pill, a link or
  /// anything else that is not a string.
  final String? value;

  final Widget? child;

  /// Renders the value at title weight — for the one field on the card that
  /// matters most, such as a plate number or an amount due.
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: text.labelMedium?.copyWith(color: t.text.secondary),
        ),
        const SizedBox(height: AppSpacing.labelGap),
        child ??
            Text(
              value!.isEmpty ? '—' : value!,
              style: emphasis ? text.titleMedium : text.bodyMedium,
            ),
      ],
    );
  }
}

/// Lays [AppField]s out in a responsive grid so a detail card reflows from four
/// columns on a wide monitor down to one on a phone, without every screen
/// hand-rolling its own `Wrap` widths.
class AppFieldGrid extends StatelessWidget {
  const AppFieldGrid({
    super.key,
    required this.fields,
    this.minColumnWidth = 220,
  });

  final List<Widget> fields;
  final double minColumnWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns =
            (constraints.maxWidth / minColumnWidth).floor().clamp(1, 4);
        final spacing = AppSpacing.x4;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: AppSpacing.x5,
          children: [
            for (final field in fields) SizedBox(width: width, child: field),
          ],
        );
      },
    );
  }
}
