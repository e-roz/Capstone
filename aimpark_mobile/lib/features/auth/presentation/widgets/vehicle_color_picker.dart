import 'package:flutter/material.dart';

import '../../../../core/theme/theme.dart';

/// Swatch picker for the vehicle's colour.
///
/// The swatches are real-world paint colours, not theme tokens, and are the one
/// place in the app that legitimately holds literal `Color` values: "Red" has
/// to look red in both themes, because it describes a car in a car park rather
/// than a role in the interface. Everything *around* them — the selection ring,
/// the labels — comes from tokens as usual.
///
/// A fixed list rather than free text: that would produce "pearl white",
/// "off-white" and "White" for one vehicle, none of which help a guard pick it
/// out of a car park.
class VehicleColorPicker extends StatelessWidget {
  const VehicleColorPicker({
    super.key,
    required this.selected,
    required this.onSelected,
    this.label = 'Colour',
    this.errorText,
  });

  /// The chosen colour's name, or null before a choice is made.
  final String? selected;

  /// Null disables the picker.
  final ValueChanged<String>? onSelected;

  final String label;

  /// Shown in red beneath the swatches when the form was submitted without one.
  final String? errorText;

  /// Colours a guard could actually name at a gate.
  static const swatches = <String, Color>{
    'White': Color(0xFFFFFFFF),
    'Silver': Color(0xFFC0C0C0),
    'Grey': Color(0xFF808080),
    'Black': Color(0xFF1A1A1A),
    'Red': Color(0xFFDC2626),
    'Blue': Color(0xFF2563EB),
    'Green': Color(0xFF16A34A),
    'Yellow': Color(0xFFEAB308),
    'Orange': Color(0xFFEA580C),
    'Brown': Color(0xFF78350F),
  };

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final enabled = onSelected != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: context.text.labelSmall),
        const SizedBox(height: 6),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final entry in swatches.entries)
              _Swatch(
                name: entry.key,
                color: entry.value,
                selected: selected == entry.key,
                // Every swatch keeps a ring in its unselected state too, or
                // White and Silver vanish into the card behind them in light
                // mode and Black vanishes in dark.
                restingBorder: t.border.normal,
                selectedBorder: t.brand.primary,
                onTap: enabled ? () => onSelected!(entry.key) : null,
              ),
          ],
        ),
        if (errorText != null && errorText!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            errorText!,
            style: context.text.labelSmall?.copyWith(color: t.status.danger.fg),
          ),
        ],
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.name,
    required this.color,
    required this.selected,
    required this.restingBorder,
    required this.selectedBorder,
    required this.onTap,
  });

  final String name;
  final Color color;
  final bool selected;
  final Color restingBorder;
  final Color selectedBorder;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Semantics(
      button: true,
      selected: selected,
      label: name,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: AppMotion.fast,
              curve: AppMotion.standard,
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? selectedBorder : restingBorder,
                  width: selected ? 3 : 1.5,
                ),
              ),
              child: selected
                  ? Icon(
                      Icons.check,
                      size: AppSizes.iconMd,
                      // White and yellow need a dark tick; everything else
                      // needs a light one. Computed from the swatch rather
                      // than the theme — the swatch does not change with it.
                      color: color.computeLuminance() > 0.6
                          ? Colors.black87
                          : Colors.white,
                    )
                  : null,
            ),
            const SizedBox(height: 4),
            Text(
              name,
              style: context.text.bodySmall?.copyWith(
                color: selected ? t.text.primary : t.text.secondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
