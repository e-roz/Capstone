import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/theme.dart';

/// AimPark surface card — flat fill with a soft border rather than a heavy
/// shadow, matching Duolingo's mostly-flat card treatment.
///
/// That choice pays off in dark mode, where a shadow is close to invisible and
/// a border is the only thing that can separate two dark surfaces.
///
/// Pass [onTap] to make the card tappable. Doing it here rather than wrapping
/// the card in a bare `GestureDetector` is what gives the press its feel:
/// eleven tiles across the app were tappable with no ripple, no motion and no
/// haptic, so the app's most-used surfaces felt dead under the thumb while
/// [AppButton] right beside them had a full tactile press.
///
/// The press is a scale-down rather than [AppButton]'s two-layer offset,
/// because cards size themselves to their content and translating one would
/// shift the rows beneath it. A transform costs no layout.
class AppCard extends StatefulWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.cardPadding),
    this.color,
    this.borderColor,
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;

  /// Defaults to `t.surface.card`. Pass a token — usually `t.brand.primary` or
  /// a status `bg` — for a card that carries its own meaning, and remember that
  /// its contents then need the matching foreground token.
  final Color? color;

  /// Defaults to `t.border.normal`. Pass a status `border` to outline a card
  /// whose *state* is the point, such as the plate verdict on the registration
  /// confirmation screen.
  final Color? borderColor;

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
    final t = context.tokens;
    final base = widget.color ?? t.surface.card;

    final surface = AnimatedContainer(
      duration: AppMotion.press,
      curve: AppMotion.standard,
      padding: widget.padding,
      decoration: BoxDecoration(
        color: base,
        borderRadius: AppRadius.mdAll,
        border: Border.all(
          // The border darkens under the thumb so the press still registers on
          // coloured cards, where a scale alone is easy to miss.
          color: _isPressed
              ? t.border.strong
              : (widget.borderColor ?? t.border.normal),
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
        duration: AppMotion.press,
        curve: AppMotion.standard,
        child: surface,
      ),
    );
  }
}
