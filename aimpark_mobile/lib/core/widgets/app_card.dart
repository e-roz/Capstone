import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// AimPark surface card — flat fill with a soft border rather than a heavy
/// shadow, matching Duolingo's mostly-flat card treatment.
///
/// Pass [onTap] to make the card tappable. Doing it here rather than wrapping
/// the card in a bare `GestureDetector` is what gives the press its feel: eleven
/// tiles across the app were tappable with no ripple, no motion and no haptic,
/// so the app's most-used surfaces felt dead under the thumb while [AppButton]
/// right beside them had a full tactile press.
///
/// The press is a scale-down rather than [AppButton]'s two-layer offset, because
/// cards size themselves to their content and translating one would shift the
/// rows beneath it. A transform costs no layout.
class AppCard extends StatefulWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.color = AppColors.bgSurface,
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color color;

  /// Null leaves the card inert — no press effect, no haptic, no hit testing.
  final VoidCallback? onTap;

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _isPressed = false;

  void _setPressed(bool value) {
    if (_isPressed != value) setState(() => _isPressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final surface = AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOut,
      padding: widget.padding,
      decoration: BoxDecoration(
        color: widget.color,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          // The border darkens under the thumb so the press still registers on
          // coloured cards, where a scale alone is easy to miss.
          color: _isPressed ? AppColors.textDisabled : AppColors.borderDefault,
          width: 1.5,
        ),
      ),
      child: widget.child,
    );

    if (widget.onTap == null) return surface;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap!();
      },
      child: AnimatedScale(
        scale: _isPressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: surface,
      ),
    );
  }
}
