import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/theme.dart';

/// Single-choice chip used for short option sets (e.g. vehicle type) instead
/// of a native dropdown — more touch-friendly and visually matching the rest
/// of the flat/bold AimPark component set.
class SelectableChip extends StatelessWidget {
  const SelectableChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;

  /// Null disables the chip. Callers used to pass an empty closure while a
  /// form was submitting, which left the chip looking live and silently eating
  /// the tap.
  final VoidCallback? onTap;

  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final enabled = onTap != null;

    // A selected chip is filled solid, not tinted. The tinted version read as
    // "slightly emphasised" rather than "chosen", which matters most on the
    // slot-filter row, where the whole point is knowing which filter is on.
    final fg = !enabled
        ? t.text.disabled
        : selected
            ? t.brand.onSolid
            : t.text.secondary;

    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      child: GestureDetector(
        onTap: enabled
            ? () {
                HapticFeedback.selectionClick();
                onTap!();
              }
            : null,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.standard,
          height: 36,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: selected ? t.brand.primary : t.surface.card,
            borderRadius: AppRadius.fullAll,
            border: Border.all(
              color: !enabled
                  ? t.border.subtle
                  : selected
                      ? t.brand.primary
                      : t.border.normal,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: AppSizes.iconSm, color: fg),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: context.text.labelMedium?.copyWith(color: fg),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A labelled group of [SelectableChip]s where exactly one is chosen.
///
/// Three screens built this by hand — incident category, vehicle type, and the
/// affiliation picker — each pairing a `Text` label with its own `Wrap` and its
/// own idea of the gap between them.
///
/// [options] maps the value that gets *sent* to the label that gets *shown*.
/// Keeping both in one map is deliberate: sending the human label instead of
/// the API's enum name is what made every incident category except "Other"
/// fail server-side validation.
class AppChipGroup<T> extends StatelessWidget {
  const AppChipGroup({
    super.key,
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
    this.icons = const {},
    this.enabled = true,
    this.errorText,
  });

  final String label;

  /// Value to display label.
  final Map<T, String> options;

  final T? value;

  /// Null disables the whole group.
  final ValueChanged<T>? onChanged;

  /// Optional leading icon per value.
  final Map<T, IconData> icons;

  final bool enabled;

  /// Shown in red beneath the chips, matching a text field's error line.
  ///
  /// A group with nothing chosen is as unanswered as an empty field, and it
  /// used to be the only unanswered thing on a form that could not say so where
  /// the user was looking.
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final live = enabled && onChanged != null;
    final hasError = errorText != null && errorText!.isNotEmpty;

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
            for (final entry in options.entries)
              SelectableChip(
                label: entry.value,
                icon: icons[entry.key],
                selected: value == entry.key,
                onTap: live ? () => onChanged!(entry.key) : null,
              ),
          ],
        ),
        if (hasError) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            errorText!,
            style: context.text.labelSmall
                ?.copyWith(color: context.tokens.status.danger.fg),
          ),
        ],
      ],
    );
  }
}
