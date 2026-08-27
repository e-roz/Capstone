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

/// Bottom nav with a rounded pill highlight behind the active item, in the
/// same flat/bold register as the rest of the AimPark component set.
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

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.surface.card,
        border: Border(
          top: BorderSide(color: t.border.normal, width: 1.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.sm,
            horizontal: AppSpacing.sm,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (i) {
              final selected = i == currentIndex;
              final item = items[i];
              final fg = selected ? t.brand.subtleText : t.text.secondary;

              return Semantics(
                button: true,
                selected: selected,
                label: item.badgeCount > 0
                    ? '${item.label}, ${item.badgeCount} unread'
                    : item.label,
                child: GestureDetector(
                  onTap: () {
                    // Skipped when the tab is already active — a haptic that
                    // fires on a tap that changes nothing trains the user to
                    // distrust it.
                    if (selected) return;
                    HapticFeedback.selectionClick();
                    onTap(i);
                  },
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: AppMotion.fast,
                    curve: AppMotion.standard,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: selected ? t.brand.subtle : Colors.transparent,
                      borderRadius: AppRadius.mdAll,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Icon(item.icon, color: fg, size: AppSizes.iconLg),
                            if (item.badgeCount > 0)
                              Positioned(
                                top: -4,
                                right: -6,
                                child: _Badge(count: item.badgeCount),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.label,
                          style: context.text.labelSmall?.copyWith(color: fg),
                        ),
                      ],
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
      constraints: const BoxConstraints(minWidth: 16),
      decoration: BoxDecoration(
        color: t.status.danger.solid,
        borderRadius: AppRadius.fullAll,
        // Keeps the badge legible where it overlaps the icon beneath it. Reads
        // from the nav's own surface rather than a fixed white, or the ring
        // becomes a bright halo in dark mode.
        border: Border.all(color: t.surface.card, width: 1.5),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        textAlign: TextAlign.center,
        style: context.text.labelSmall?.copyWith(
          color: t.text.onDark,
          fontSize: 9,
          height: 1.2,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
