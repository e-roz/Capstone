import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/theme.dart';

/// A single choice from a short list, drawn as a grid of equal tiles.
///
/// For a choice where each option is a *thing* with a look of its own — the kind
/// of incident, say — rather than the one-word filters [AppChipGroup] is for.
/// Equal tiles sit on a grid, so the edges line up, where a row of pills of
/// different lengths leaves a ragged right-hand side.
///
/// Each option can carry an icon and a hue ([intents]). Unchosen, the icon wears
/// its colour on a soft disc; chosen, the whole tile takes the tint, gets a
/// heavier edge in that hue and a tick — unmistakable at a glance, where a tint
/// alone read as "slightly emphasised" rather than "picked".
///
/// [options] maps the value that is *sent* to the label that is *shown*, as in
/// [AppChipGroup], so the two cannot drift apart.
class AppChoiceTiles<T> extends StatelessWidget {
  const AppChoiceTiles({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.icons = const {},
    this.intents = const {},
    this.columns = 2,
    this.enabled = true,
    this.errorText,
  });

  final Map<T, String> options;
  final T? value;

  /// Null disables the whole grid.
  final ValueChanged<T>? onChanged;

  final Map<T, IconData> icons;

  /// The hue of each option. One missing from the map is neutral grey.
  final Map<T, StatusIntent> intents;

  final int columns;
  final bool enabled;

  /// Shown under the grid, with an icon, when nothing has been chosen and it
  /// has to be.
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final live = enabled && onChanged != null;
    final hasError = errorText != null && errorText!.isNotEmpty;
    final entries = options.entries.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var start = 0; start < entries.length; start += columns) ...[
          if (start > 0) const SizedBox(height: AppSpacing.sm),
          // IntrinsicHeight so the tiles in a row are as tall as the tallest —
          // a label that wraps at a large text size must not leave its neighbour
          // short.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < columns; i++) ...[
                  if (i > 0) const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: start + i < entries.length
                        ? _Tile(
                            label: entries[start + i].value,
                            icon: icons[entries[start + i].key],
                            intent: intents[entries[start + i].key] ??
                                StatusIntent.neutral,
                            selected: value == entries[start + i].key,
                            onTap: live
                                ? () => onChanged!(entries[start + i].key)
                                : null,
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ),
        ],
        if (hasError) ...[
          const SizedBox(height: AppSpacing.xs + 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(
                  Icons.error_outline_rounded,
                  size: AppSizes.iconSm,
                  color: t.status.danger.fg,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  errorText!,
                  style: context.text.labelSmall
                      ?.copyWith(color: t.status.danger.fg),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.label,
    required this.icon,
    required this.intent,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData? icon;
  final StatusIntent intent;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = t.status.of(intent);
    final enabled = onTap != null;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled
            ? () {
                HapticFeedback.selectionClick();
                onTap!();
              }
            : null,
        child: AnimatedContainer(
          duration: reduceMotion ? Duration.zero : AppMotion.fast,
          curve: AppMotion.standard,
          constraints: const BoxConstraints(minHeight: 60),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm + 4,
            vertical: AppSpacing.sm + 2,
          ),
          decoration: BoxDecoration(
            color: selected ? c.bg : t.surface.card,
            borderRadius: AppRadius.mdAll,
            border: Border.all(
              color: !enabled
                  ? t.border.subtle
                  : selected
                      ? c.solid
                      : t.border.control,
              // Heavier when chosen, so the choice reads without relying on the
              // colour. Half a point of difference, which is not enough to move
              // anything beside it.
              width: selected ? 2 : 1.5,
            ),
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    // On a chosen tile the disc goes white so it stands out from
                    // the tint behind it.
                    color: selected ? t.surface.card : c.bg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: AppSizes.iconMd, color: c.fg),
                ),
                const SizedBox(width: AppSpacing.sm + 2),
              ],
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelLarge?.copyWith(
                    color: enabled ? t.text.primary : t.text.disabled,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 4),
                Icon(Icons.check_circle_rounded, size: AppSizes.iconMd, color: c.solid),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
