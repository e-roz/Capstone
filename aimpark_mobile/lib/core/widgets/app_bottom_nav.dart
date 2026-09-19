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

/// Bottom nav as a dark capsule with a rounded bump rising above the bar at
/// each icon — a fixed-size shape, not one derived from screen width, so it
/// stays the same size on every phone rather than inflating on a wide one.
///
/// [AppNavItem.label] still drives each item's [Semantics] announcement —
/// there is no visible caption under the icon, by design.
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

  /// The capsule's own height, excluding the bumps. Fixed regardless of how
  /// wide the bar ends up — only the *gaps* between icons grow on a wider
  /// phone, never the icons themselves.
  static const double _coreHeight = 60;

  /// Radius of each bump, centred on the capsule's top edge so half pokes
  /// above it. Also fixed.
  static const double _bumpRadius = 27;

  static const double _iconSize = 22;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final totalHeight = _coreHeight + _bumpRadius;

    return ColoredBox(
      // The canvas colour, not the card colour: it has to match whatever the
      // active screen is drawn on so the capsule reads as floating above it.
      color: t.surface.canvas,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: SizedBox(
            height: totalHeight,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final slot = width / items.length;

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CustomPaint(
                      size: Size(width, totalHeight),
                      painter: _NavBlobPainter(
                        itemCount: items.length,
                        color: t.surface.inverse,
                        coreHeight: _coreHeight,
                        bumpRadius: _bumpRadius,
                      ),
                    ),
                    Row(
                      children: List.generate(items.length, (i) {
                        final selected = i == currentIndex;
                        final item = items[i];
                        final fg =
                            selected ? t.brand.primary : t.text.onDarkMuted;

                        return SizedBox(
                          width: slot,
                          height: totalHeight,
                          child: Semantics(
                            button: true,
                            selected: selected,
                            label: item.badgeCount > 0
                                ? '${item.label}, ${item.badgeCount} unread'
                                : item.label,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                // Skipped when the tab is already active — a
                                // haptic that fires on a tap that changes
                                // nothing trains the user to distrust it.
                                if (selected) return;
                                HapticFeedback.selectionClick();
                                onTap(i);
                              },
                              child: Align(
                                // Pulled up toward the bump's apex rather than
                                // centred in the full (bump-height-inclusive)
                                // box, so the icon actually sits inside the
                                // bump instead of in the capsule below it.
                                alignment: const Alignment(0, -0.5),
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  alignment: Alignment.center,
                                  children: [
                                    AnimatedContainer(
                                      duration: AppMotion.fast,
                                      curve: AppMotion.standard,
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: selected
                                            ? t.surface.card
                                            : Colors.transparent,
                                        shape: BoxShape.circle,
                                      ),
                                      alignment: Alignment.center,
                                      child: Icon(
                                        item.icon,
                                        color: fg,
                                        size: _iconSize,
                                      ),
                                    ),
                                    if (item.badgeCount > 0)
                                      Positioned(
                                        top: -2,
                                        right: -2,
                                        child: _Badge(count: item.badgeCount),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Draws the capsule plus one circular bump per item, unioned into a single
/// silhouette. Every dimension comes from the caller as a fixed constant —
/// this painter never derives a size from [Size.width] itself, which is the
/// mistake that made an earlier version of this bar fill the whole screen.
class _NavBlobPainter extends CustomPainter {
  const _NavBlobPainter({
    required this.itemCount,
    required this.color,
    required this.coreHeight,
    required this.bumpRadius,
  });

  final int itemCount;
  final Color color;
  final double coreHeight;
  final double bumpRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..isAntiAlias = true;

    final coreTop = size.height - coreHeight;
    var path = Path()
      ..addRRect(RRect.fromLTRBR(
        0,
        coreTop,
        size.width,
        size.height,
        Radius.circular(coreHeight / 2),
      ));

    final slot = size.width / itemCount;
    for (var i = 0; i < itemCount; i++) {
      final cx = slot * (i + 0.5);
      final bump = Path()
        ..addOval(Rect.fromCircle(center: Offset(cx, coreTop), radius: bumpRadius));
      path = Path.combine(PathOperation.union, path, bump);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _NavBlobPainter oldDelegate) {
    return oldDelegate.itemCount != itemCount ||
        oldDelegate.color != color ||
        oldDelegate.coreHeight != coreHeight ||
        oldDelegate.bumpRadius != bumpRadius;
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
        // Keeps the badge legible where it overlaps the icon beneath it. Reads
        // from the nav's own inverse surface rather than a fixed white, or the
        // ring becomes a bright halo in dark mode.
        border: Border.all(color: t.surface.inverse, width: 1.5),
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
