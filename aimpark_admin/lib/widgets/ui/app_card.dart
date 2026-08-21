import 'package:flutter/material.dart';

import '../../theme/theme.dart';

/// The standard container: white surface, hairline border, 12px radius, soft
/// shadow. Everything that sits on the page canvas should be one of these.
///
/// It exists because the same `Container(decoration: BoxDecoration(...))` was
/// written out five times across Reports and the detail screens, each with
/// slightly different radius and shadow values.
class AppCard extends StatefulWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.cardPadding),
    this.onTap,
    this.selected = false,
    this.width,
    this.clip = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// When set, the card lifts and highlights on hover and becomes clickable.
  final VoidCallback? onTap;

  final bool selected;
  final double? width;
  final bool clip;

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final interactive = widget.onTap != null;
    final lifted = interactive && _hovered;

    final card = AnimatedContainer(
      duration: AppMotion.fast,
      curve: AppMotion.standard,
      width: widget.width,
      padding: widget.padding,
      decoration: BoxDecoration(
        color: lifted ? t.surface.hover : t.surface.card,
        borderRadius: AppRadii.lgAll,
        border: Border.all(
          color: widget.selected ? t.brand.primary : t.border.normal,
          width: widget.selected ? 1.5 : 1,
        ),
        boxShadow: lifted ? AppElevation.md : AppElevation.sm,
      ),
      clipBehavior: widget.clip ? Clip.antiAlias : Clip.none,
      child: widget.child,
    );

    if (!interactive) return card;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(onTap: widget.onTap, child: card),
    );
  }
}

/// An [AppCard] with a title bar — the pattern used by every detail screen for
/// grouping fields ("Account", "Vehicle", "Documents").
class AppSectionCard extends StatelessWidget {
  const AppSectionCard({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.actions = const [],
    this.icon,
    this.padding = const EdgeInsets.all(AppSpacing.cardPadding),
  });

  final String title;
  final String? subtitle;
  final Widget child;

  /// Buttons pinned to the right of the title.
  final List<Widget> actions;

  final IconData? icon;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.cardPadding,
                AppSpacing.x3, AppSpacing.x3, AppSpacing.x3),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: AppSizes.iconMd, color: t.text.secondary),
                  const SizedBox(width: AppSpacing.x2),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: text.titleMedium),
                      if (subtitle != null)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.labelGap),
                          child: Text(
                            subtitle!,
                            style: text.bodySmall
                                ?.copyWith(color: t.text.secondary),
                          ),
                        ),
                    ],
                  ),
                ),
                for (final action in actions) ...[
                  const SizedBox(width: AppSpacing.controlGap),
                  action,
                ],
              ],
            ),
          ),
          Divider(height: 1, color: t.border.subtle),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}
