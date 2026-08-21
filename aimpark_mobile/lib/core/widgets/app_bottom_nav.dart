import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

class _Badge extends StatelessWidget {
  const _Badge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : '$count';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      constraints: const BoxConstraints(minWidth: 16),
      decoration: BoxDecoration(
        color: AppColors.errorDefault,
        borderRadius: BorderRadius.circular(AppRadius.full),
        // Keeps the badge legible where it overlaps the icon beneath it.
        border: Border.all(color: AppColors.bgSurface, width: 1.5),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.textOnBrand,
          fontSize: 9,
          height: 1.2,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class AppNavItem {
  const AppNavItem({required this.icon, required this.label, this.badgeCount = 0});

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
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.bgSurface,
        border: Border(top: BorderSide(color: AppColors.borderDefault, width: 1.5)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.sm),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (i) {
              final selected = i == currentIndex;
              final item = items[i];
              return GestureDetector(
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
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.brandSubtle : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(
                            item.icon,
                            color: selected
                                ? AppColors.brandPressed
                                : AppColors.textSecondary,
                            size: 24,
                          ),
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
                        style: AppTextStyles.labelSmall.copyWith(
                          color: selected ? AppColors.brandPressed : AppColors.textSecondary,
                        ),
                      ),
                    ],
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
