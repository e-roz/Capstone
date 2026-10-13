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
            : t.text.primary;

    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      onTap: enabled ? onTap : null,
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
          // A floor, not a fixed height: 44dp to be hit with a thumb, and free to
          // grow when the system text is large.
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? t.brand.primary : t.surface.card,
            borderRadius: AppRadius.fullAll,
            border: Border.all(
              // An unchosen chip is a control, so its edge uses the control
              // border (3:1) rather than the card hairline it used to share.
              color: !enabled
                  ? t.border.subtle
                  : selected
                      ? t.brand.primary
                      : t.border.control,
              width: 1.5,
            ),
          ),
          // Centred with factors of 1 so the chip is exactly as wide and tall as
          // its label. A plain `alignment: center` on the container makes it
          // grow to fill whatever width it is offered, and a Wrap offers the whole
          // row — which is how every chip became a full-width bar and the group a
          // single column.
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: AppSizes.iconMd, color: fg),
                  const SizedBox(width: 8),
                ],
                // Flexible, so a long label wraps to a second line at a large
                // text size instead of running off the end of the chip.
                Flexible(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.labelLarge?.copyWith(color: fg),
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
