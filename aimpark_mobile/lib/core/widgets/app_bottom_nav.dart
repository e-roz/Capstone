import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/theme.dart';

class AppNavItem {
  const AppNavItem({
    required this.icon,
    required this.label,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String label;

  /// Unread items behind this tab. Zero hides the badge; anything over 99
  /// renders as "99+" so the pill cannot grow wide enough to break the row.
  final int badgeCount;
}

/// Bottom nav as a flat white bar: a hairline top border, a whisper of lift,
/// and a filled pill behind the active tab's icon.
///
/// This replaced a dark capsule with circular bumps rising out of it, drawn by
/// a `CustomPainter`. The bumps were the app's one piece of drawn chrome, and
/// they cost more than they returned: a painted silhouette cannot take a
/// [Semantics] node, cannot grow with the text scale, and had to be told its
/// own height as a pair of magic constants that no other component shared.
///
/// The pill does the same job — say which tab you are on — out of a container,
/// a radius and two tokens. It also freed the captions: the capsule had no room
/// for them, so labels existed only for screen readers. They are now on screen.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  final List<AppNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  /// Width and height of the pill behind an active icon. Wider than it is tall
  /// so it reads as a lozenge under the caption rather than a second avatar.
  static const double _pillWidth = 56;
  static const double _pillHeight = 28;

  /// Comfortably past the 48dp minimum, because the whole column — pill and
  /// caption together — is the tap target, not just the icon.
  static const double _itemHeight = 56;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.surface.card,
        border: Border(top: BorderSide(color: t.border.normal)),
        boxShadow: AppElevation.sm,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
          child: Row(
            children: List.generate(items.length, (i) {
              final selected = i == currentIndex;
              final item = items[i];
              final fg = selected ? t.brand.subtleText : t.text.secondary;

              return Expanded(
                child: Semantics(
                  button: true,
                  selected: selected,
                  label: item.badgeCount > 0
                      ? '${item.label}, ${item.badgeCount} unread'
                      : item.label,
                  child: InkWell(
                    borderRadius: AppRadius.smAll,
                    onTap: () {
                      // Skipped when the tab is already active — a haptic that
                      // fires on a tap that changes nothing trains the user to
                      // distrust it.
                      if (selected) return;
                      HapticFeedback.selectionClick();
                      onTap(i);
                    },
                    child: SizedBox(
                      height: _itemHeight,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              AnimatedContainer(
                                duration: AppMotion.fast,
                                curve: AppMotion.standard,
                                width: _pillWidth,
                                height: _pillHeight,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: selected
                                      ? t.brand.subtle
                                      : Colors.transparent,
                                  borderRadius: AppRadius.fullAll,
                                ),
                                child: Icon(
                                  item.icon,
                                  color: fg,
                                  size: AppSizes.iconMd,
                                ),
                              ),
                              if (item.badgeCount > 0)
                                PositionedDirectional(
                                  top: -4,
                                  end: 4,
                                  child: _Badge(count: item.badgeCount),
                                ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.labelGap),
                          Text(
                            item.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.labelSmall?.copyWith(
                              color: fg,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      constraints: const BoxConstraints(minWidth: 14),
      decoration: BoxDecoration(
        color: t.status.danger.solid,
        borderRadius: AppRadius.fullAll,
        // Keeps the badge legible where it overlaps the pill beneath it. Reads
        // the bar's own surface rather than a fixed white so the ring stays
        // invisible against whatever the bar is filled with.
        border: Border.all(color: t.surface.card, width: 1.5),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        textAlign: TextAlign.center,
        style: context.text.labelSmall?.copyWith(
          color: t.text.onDark,
          fontSize: 8,
          height: 1.2,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
