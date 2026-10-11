import 'package:flutter/material.dart';

import '../theme/theme.dart';
import 'app_card.dart';

/// A shortcut: a tinted icon over a short label, on a tappable card.
///
/// The shape of a quick-action row — three of them side by side. It was a
/// private `_QuickAction` on the Home screen with its own hand-picked padding
/// and a fixed 60dp height, which clipped the label at large text sizes.
///
/// The icon sits in a soft disc coloured by [intent], so each shortcut has a
/// colour of its own and a row of them does not read as three grey squares. The
/// colour is a hue, not a verdict: pass the intent that suits what the action
/// *is* — a report is amber, a vehicle is the brand's indigo — and keep red for
/// things that are actually wrong.
///
/// A minimum height, not a fixed one, and the label wraps to a second line
/// rather than being cut.
class AppActionTile extends StatelessWidget {
  const AppActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.intent = StatusIntent.brand,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// Colours the disc behind the icon.
  final StatusIntent intent;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = t.status.of(intent);

    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      // Needed alongside excludeSemantics: that drops the card's own tap action
      // from the tree, so without this a screen reader could read the tile and
      // not press it.
      onTap: onTap,
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: c.bg, shape: BoxShape.circle),
              child: Icon(icon, size: AppSizes.iconLg, color: c.fg),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              label,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodySmall?.copyWith(
                color: t.text.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
