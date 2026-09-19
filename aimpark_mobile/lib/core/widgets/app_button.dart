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

/// AimPark's button: a flat, fully-rounded pill that scales down slightly
/// under the thumb, matching the reference's clean CTA style — no drawn depth,
/// no offset shadow layer, just fill, motion and a haptic tick.
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

  ({Color fill, Color text, Color? border}) _colorsFor(AppTokens t) {
    if (_isDisabled) {
      return (fill: t.surface.muted, text: t.text.disabled, border: null);
    }

    return switch (widget.style) {
      AppButtonStyle.primary => (
          fill: _isPressed ? t.brand.pressed : t.brand.primary,
          text: t.brand.onSolid,
          border: null,
        ),
      AppButtonStyle.secondary => (
          fill: _isPressed ? t.accent.pressed : t.accent.primary,
          text: t.accent.onSolid,
          border: null,
        ),
      AppButtonStyle.tertiary => (
          fill: _isPressed ? t.tertiary.pressed : t.tertiary.primary,
          text: t.tertiary.onSolid,
          border: null,
        ),
      // No fill: a ghost button sitting next to a primary one should read as
      // the quieter of the two.
      AppButtonStyle.ghost => (
          fill: _isPressed ? t.surface.pressed : t.surface.card,
          text: t.text.primary,
          border: t.border.normal,
        ),
      AppButtonStyle.danger => (
          fill: _isPressed ? t.status.danger.fg : t.status.danger.solid,
          text: t.text.onDark,
          border: null,
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = _colorsFor(context.tokens);
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
        child: AnimatedScale(
          scale: _isPressed ? 0.97 : 1.0,
          duration: AppMotion.press,
          curve: AppMotion.standard,
          child: AnimatedContainer(
            duration: AppMotion.fast,
            curve: AppMotion.standard,
            height: height,
            decoration: BoxDecoration(
              color: colors.fill,
              borderRadius: AppRadius.fullAll,
              border: colors.border != null
                  ? Border.all(color: colors.border!, width: 1.5)
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
                        horizontal: AppSpacing.lg,
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
      ),
    );
  }
}
