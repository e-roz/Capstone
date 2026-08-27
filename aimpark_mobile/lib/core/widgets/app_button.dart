import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/theme.dart';

/// Which role a button plays. Chosen by *meaning*, never by which colour looks
/// better on the screen you happen to be building.
enum AppButtonStyle {
  /// The one action the screen exists for.
  primary,

  /// A real alternative to the primary action, not a lesser one.
  secondary,

  /// A rewarding or celebratory action.
  tertiary,

  /// Cancel, dismiss, "not now", and retry.
  ghost,

  /// Deleting or discarding something the user cannot get back.
  danger,
}

/// AimPark button using the Duolingo-style two-layer pressed effect: a solid
/// "shadow" layer sits behind the fill layer, offset down. On press, the fill
/// layer collapses onto the shadow layer, reading as physically pushed.
///
/// The press is what makes the app feel like a phone app rather than a form,
/// so it survives dark mode intact — the two layers come from
/// `t.<accent>.primary` and `t.<accent>.pressed`, which stay a matched pair in
/// both themes.
class AppButton extends StatefulWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.style = AppButtonStyle.primary,
    this.icon,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonStyle style;
  final Widget? icon;

  /// Swaps the label for a spinner and blocks the tap. Use this rather than
  /// setting [onPressed] to null during a request — a button that greys out
  /// looks like it has become unavailable, where a spinner says "working".
  final bool isLoading;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _isPressed = false;

  bool get _isDisabled => widget.onPressed == null || widget.isLoading;

  ({Color fill, Color? shadow, Color text, Color? border}) _colorsFor(
    AppTokens t,
  ) {
    if (_isDisabled) {
      return (
        fill: t.surface.muted,
        shadow: null,
        text: t.text.disabled,
        border: null,
      );
    }

    return switch (widget.style) {
      AppButtonStyle.primary => (
          fill: t.brand.primary,
          shadow: t.brand.pressed,
          text: t.brand.onSolid,
          border: null,
        ),
      AppButtonStyle.secondary => (
          fill: t.accent.primary,
          shadow: t.accent.pressed,
          text: t.accent.onSolid,
          border: null,
        ),
      AppButtonStyle.tertiary => (
          fill: t.tertiary.primary,
          shadow: t.tertiary.pressed,
          text: t.tertiary.onSolid,
          border: null,
        ),
      // No shadow layer: a ghost button sitting next to a primary one should
      // read as the quieter of the two, and giving it the same tactile depth
      // makes them compete.
      AppButtonStyle.ghost => (
          fill: t.surface.card,
          shadow: null,
          text: t.text.primary,
          border: t.border.normal,
        ),
      AppButtonStyle.danger => (
          fill: t.status.danger.solid,
          shadow: t.status.danger.fg,
          text: t.text.onDark,
          border: null,
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = _colorsFor(context.tokens);
    final hasShadow = colors.shadow != null;
    const height = AppSizes.controlHeight;

    return Semantics(
      button: true,
      enabled: !_isDisabled,
      label: widget.label,
      child: GestureDetector(
        onTapDown: _isDisabled ? null : (_) => setState(() => _isPressed = true),
        onTapUp: _isDisabled ? null : (_) => setState(() => _isPressed = false),
        onTapCancel:
            _isDisabled ? null : () => setState(() => _isPressed = false),
        onTap: _isDisabled
            ? null
            : () {
                HapticFeedback.lightImpact();
                widget.onPressed!();
              },
        child: SizedBox(
          height: height + kPressedShadowOffset,
          child: Stack(
            children: [
              if (hasShadow)
                Positioned(
                  left: 0,
                  right: 0,
                  top: kPressedShadowOffset,
                  height: height,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.shadow,
                      borderRadius: AppRadius.lgAll,
                    ),
                  ),
                ),
              AnimatedPositioned(
                duration: AppMotion.press,
                curve: AppMotion.standard,
                left: 0,
                right: 0,
                top: (_isPressed && hasShadow) ? kPressedShadowOffset : 0,
                height: height,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.fill,
                    borderRadius: AppRadius.lgAll,
                    border: colors.border != null
                        ? Border.all(color: colors.border!, width: 2)
                        : null,
                  ),
                  child: Center(
                    child: widget.isLoading
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation(colors.text),
                            ),
                          )
                        : Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (widget.icon != null) ...[
                                  IconTheme(
                                    data: IconThemeData(
                                      color: colors.text,
                                      size: AppSizes.iconMd,
                                    ),
                                    child: widget.icon!,
                                  ),
                                  const SizedBox(width: AppSpacing.xs + 2),
                                ],
                                Flexible(
                                  child: Text(
                                    widget.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: context.text.labelLarge?.copyWith(
                                      fontSize: 16,
                                      color: colors.text,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
