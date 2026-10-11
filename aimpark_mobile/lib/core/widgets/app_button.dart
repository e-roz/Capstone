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

  /// The same warning as [danger], without the weight: a white pill with a red
  /// outline and red label. For a destructive action that sits *beside* the
  /// screen's main one — "Withdraw" under "Edit" — where a solid red button
  /// would out-shout the thing the person came to do.
  dangerGhost,

  /// The primary action on a surface that is already the brand colour — the
  /// availability card on Home. A white pill with brand text, where the ordinary
  /// primary would be indigo on indigo. It was a private one-off widget in the
  /// Home screen before it was a style.
  inverse,
}

/// AimPark's button: a flat, fully-rounded pill that scales down slightly
/// under the thumb, matching the reference's clean CTA style — no drawn depth,
/// no offset shadow layer, just fill, motion and a haptic tick.
///
/// Sized by its label, never clipped by it: the pill is *at least* the 48dp
/// control height, and grows (and wraps its label to a second line) when the
/// system text size is turned up. A fixed height used to cut the label off at
/// large text sizes, on the one control a person cannot afford to misread.
///
/// Reachable without a touchscreen — it takes focus, shows a ring when it has
/// it, and activates on Enter or Space — and it does not animate for someone who
/// has asked their phone not to.
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
  bool _isFocused = false;

  bool get _isDisabled => widget.onPressed == null || widget.isLoading;

  void _activate() {
    if (_isDisabled) return;
    HapticFeedback.lightImpact();
    widget.onPressed!();
  }

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
      AppButtonStyle.dangerGhost => (
          fill: _isPressed ? t.status.danger.bg : t.surface.card,
          text: t.status.danger.fg,
          border: t.status.danger.solid,
        ),
      AppButtonStyle.inverse => (
          fill: _isPressed ? t.surface.pressed : t.surface.card,
          text: t.brand.subtleText,
          border: null,
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final colors = _colorsFor(t);

    // Honours the phone's "remove animations" setting. The press scale and the
    // colour fade are decoration; skipping them loses nothing.
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final pressDuration = reduceMotion ? Duration.zero : AppMotion.press;
    final fadeDuration = reduceMotion ? Duration.zero : AppMotion.fast;

    return Semantics(
      button: true,
      enabled: !_isDisabled,
      label: widget.isLoading ? '${widget.label}, loading' : widget.label,
      excludeSemantics: true,
      onTap: _isDisabled ? null : _activate,
      child: FocusableActionDetector(
        enabled: !_isDisabled,
        onShowFocusHighlight: (focused) => setState(() => _isFocused = focused),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _activate();
              return null;
            },
          ),
        },
        child: GestureDetector(
          onTapDown:
              _isDisabled ? null : (_) => setState(() => _isPressed = true),
          onTapUp:
              _isDisabled ? null : (_) => setState(() => _isPressed = false),
          onTapCancel:
              _isDisabled ? null : () => setState(() => _isPressed = false),
          onTap: _isDisabled ? null : _activate,
          child: AnimatedScale(
            scale: _isPressed ? 0.985 : 1.0,
            duration: pressDuration,
            curve: AppMotion.standard,
            child: AnimatedContainer(
              duration: fadeDuration,
              curve: AppMotion.standard,
              constraints: const BoxConstraints(
                minHeight: AppSizes.controlHeight,
              ),
              decoration: BoxDecoration(
                color: colors.fill,
                borderRadius: AppRadius.fullAll,
                border: colors.border != null
                    ? Border.all(color: colors.border!)
                    : null,
                // The focus ring sits outside the pill, so it never changes the
                // button's size. Only ever shown for keyboard or switch focus,
                // not for a finger.
                boxShadow: _isFocused
                    ? [
                        BoxShadow(
                          color: t.border.focus.withValues(alpha: 0.35),
                          spreadRadius: 3,
                        ),
                      ]
                    : null,
              ),
              // heightFactor: 1 is what keeps the pill the height of its label. A
              // plain Center grows to fill whatever height it is offered, and a
              // button pinned in a bottom bar is offered the whole screen — it
              // turned "Submit Report" into a button the size of the page. The
              // 48dp floor comes from the constraints above; this only stops the
              // growth, and the width still fills the row as before.
              child: Center(
                heightFactor: 1,
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
                          vertical: AppSpacing.sm + 2,
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
                                // Two lines before an ellipsis: at a large text
                                // size a long label such as "Review and pay"
                                // wraps rather than being cut off.
                                maxLines: 2,
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                                style: context.text.labelLarge?.copyWith(
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
      ),
    );
  }
}
