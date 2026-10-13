import 'package:flutter/material.dart';

import '../theme/theme.dart';
import 'app_card.dart';

/// A card that tells the user something needs their attention — an unpaid fee,
/// an open violation.
///
/// White fill, a status-coloured edge and outline. The colour goes to the edge
/// and the eyebrow rather than to the fill, so the one card a person most needs
/// to read is never coloured text on coloured ground. Home had two of these
/// built by hand, one a `Column` and one a `Row`, with their own icon sizes.
///
/// Three shapes from the same pieces:
///
/// * a figure and a button — [child] for the figure, [action] for the button;
/// * a whole-card link — [title] and [message] plus [onTap], which adds the
///   chevron;
/// * a plain notice — just [eyebrow] and [message].
///
/// Read as one unit by a screen reader, in the order it is drawn.
class AppAlertCard extends StatelessWidget {
  const AppAlertCard({
    super.key,
    required this.intent,
    required this.eyebrow,
    this.title,
    this.message,
    this.child,
    this.action,
    this.onTap,
    this.icon,
  });

  /// Drives the edge, the outline, the eyebrow and the default icon together, so
  /// they cannot disagree.
  final StatusIntent intent;

  /// The small tracked line at the top: "Payment due", "2 open violations".
  /// Upper-cased here so a caller passes a sentence, not a shout.
  final String eyebrow;

  /// A bold line under the eyebrow.
  final String? title;

  /// The muted line under that.
  final String? message;

  /// Anything between the text and the action — a large amount, a progress bar.
  final Widget? child;

  /// A button at the foot of the card. When present the card itself is not
  /// tappable: two ways to do the same thing on one surface is how a thumb ends
  /// up on the wrong one.
  final Widget? action;

  /// Makes the whole card a link, and adds a chevron to say so. Ignored if
  /// [action] is given.
  final VoidCallback? onTap;

  /// Overrides the intent's default icon.
  final IconData? icon;

  IconData get _icon =>
      icon ??
      switch (intent) {
        StatusIntent.success => Icons.check_circle_outline_rounded,
        StatusIntent.warning => Icons.warning_amber_rounded,
        StatusIntent.danger => Icons.error_outline_rounded,
        StatusIntent.info || StatusIntent.brand => Icons.info_outline_rounded,
        StatusIntent.neutral => Icons.help_outline_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = t.status.of(intent);
    final tappable = onTap != null && action == null;

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(_icon, size: AppSizes.iconSm, color: c.fg),
            const SizedBox(width: AppSpacing.xs + 2),
            Flexible(
              child: Text(
                eyebrow.toUpperCase(),
                style: context.text.labelMedium?.copyWith(color: c.fg),
              ),
            ),
          ],
        ),
        if (title != null) ...[
          const SizedBox(height: AppSpacing.sm - 2),
          Text(title!, style: context.text.titleMedium),
        ],
        if (message != null) ...[
          const SizedBox(height: 2),
          Text(message!, style: context.text.bodySmall),
        ],
        if (child != null) ...[
          const SizedBox(height: AppSpacing.sm),
          child!,
        ],
        if (action != null) ...[
          const SizedBox(height: AppSpacing.md),
          action!,
        ],
      ],
    );

    final card = Semantics(
      container: true,
      button: tappable,
      child: AppCard(
        borderColor: c.border,
        edgeColor: c.solid,
        onTap: tappable ? onTap : null,
        child: tappable
            ? Row(
                children: [
                  Expanded(child: body),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: t.text.secondary,
                    size: AppSizes.iconLg,
                  ),
                ],
              )
            : body,
      ),
    );

    // A card with a button in it keeps that button as its own stop for a screen
    // reader; merging would fold the button's action into the card's text.
    return action == null ? MergeSemantics(child: card) : card;
  }
}
