import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

enum AppButtonStyle { primary, secondary, tertiary, ghost }

/// AimPark button using the Duolingo-style two-layer pressed effect: a solid
/// "shadow" layer sits behind the fill layer, offset down. On press, the
/// fill layer collapses onto the shadow layer, reading as physically pushed.
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
  final bool isLoading;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _isPressed = false;

  bool get _isDisabled => widget.onPressed == null || widget.isLoading;

  ({Color fill, Color? shadow, Color text, Color? border}) _colorsFor(
      AppButtonStyle style) {
    if (_isDisabled) {
      return (
        fill: AppColors.bgSurfaceAlt,
        shadow: null,
        text: AppColors.textDisabled,
        border: null,
      );
    }
    switch (style) {
      case AppButtonStyle.primary:
        return (
          fill: AppColors.brandDefault,
          shadow: AppColors.brandPressed,
          text: AppColors.textOnBrand,
          border: null,
        );
      case AppButtonStyle.secondary:
        return (
          fill: AppColors.accentDefault,
          shadow: AppColors.accentPressed,
          text: AppColors.textOnBrand,
          border: null,
        );
      case AppButtonStyle.tertiary:
        return (
          fill: AppColors.tertiaryDefault,
          shadow: AppColors.tertiaryPressed,
          text: AppColors.textPrimary,
          border: null,
        );
      case AppButtonStyle.ghost:
        return (
          fill: AppColors.bgSurface,
          shadow: null,
          text: AppColors.textPrimary,
          border: AppColors.borderDefault,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = _colorsFor(widget.style);
    final hasShadow = colors.shadow != null;
    const height = 48.0;

    return GestureDetector(
      onTapDown: _isDisabled ? null : (_) => setState(() => _isPressed = true),
      onTapUp: _isDisabled ? null : (_) => setState(() => _isPressed = false),
      onTapCancel: _isDisabled ? null : () => setState(() => _isPressed = false),
      onTap: _isDisabled ? null : widget.onPressed,
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
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                ),
              ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 80),
              curve: Curves.easeOut,
              left: 0,
              right: 0,
              top: (_isPressed && hasShadow) ? kPressedShadowOffset : 0,
              height: height,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.fill,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
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
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(colors.text),
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.icon != null) ...[
                              IconTheme(
                                data: IconThemeData(color: colors.text, size: 20),
                                child: widget.icon!,
                              ),
                              const SizedBox(width: AppSpacing.xs),
                            ],
                            Text(
                              widget.label,
                              style: AppTextStyles.labelBold.copyWith(
                                fontSize: 16,
                                color: colors.text,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
