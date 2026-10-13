import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/theme.dart';

/// A tappable word or two — "Switch", "How this works", "See all".
///
/// Exists because these were each a bare `GestureDetector` around 13px text:
/// a touch target about 16dp tall, on the one kind of control that sits beside a
/// heading where a thumb will land on the heading instead. This one is always at
/// least 48dp in both directions. The text stays small; the area around it is
/// what grows.
///
/// Sized by its content plus that minimum, so inside an [AppSectionHeader] it
/// makes the header row a little taller. That is the price of a target that can
/// be hit, and it is worth paying: overflowing a smaller box does not work,
/// because Flutter will not deliver a tap that lands outside its parent.
///
/// No underline. Underline was used on a single link in the app and nowhere
/// else, which made it the one thing that looked different without being
/// different. The brand colour and the trailing icon say "tappable" the way
/// every other action here does.
class AppTextLink extends StatelessWidget {
  const AppTextLink({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.semanticLabel,
    this.color,
  });

  final String label;
  final VoidCallback onTap;

  /// For a link on a coloured surface, where the brand colour would vanish —
  /// the availability card's "Refresh". Left null it is the brand's text colour.
  final Color? color;

  /// A small trailing glyph — a chevron, an unfold arrow.
  final IconData? icon;

  /// For when the visible word alone is not enough to a screen reader: "Switch"
  /// says nothing about what is being switched.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final fg = color ?? t.brand.subtleText;

    return Semantics(
      button: true,
      label: semanticLabel ?? label,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: AppRadius.smAll,
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: AppSizes.controlHeight,
              minHeight: AppSizes.controlHeight,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      label,
                      style: context.text.labelLarge?.copyWith(color: fg),
                    ),
                  ),
                  if (icon != null) ...[
                    const SizedBox(width: 2),
                    Icon(icon, size: AppSizes.iconSm, color: fg),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
