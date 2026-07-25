import 'package:flutter/material.dart';

/// AimPark color tokens — mirrors the Figma "AimPark Mobile" design system
/// (Primitives + Color collections). Decorative brand hues (orange/blue/yellow)
/// are kept separate from status hues (green/red) so parking-status meaning
/// never collides with brand styling.
abstract class AppColors {
  // Orange — brand / primary actions
  static const brandDefault = Color(0xFFF97316);
  static const brandPressed = Color(0xFFEA580C);
  static const brandSubtle = Color(0xFFFFEDD5);

  // Blue — accent / secondary actions
  static const accentDefault = Color(0xFF0EA5E9);
  static const accentPressed = Color(0xFF0284C7);
  static const accentSubtle = Color(0xFFE0F2FE);

  // Yellow — tertiary / streak highlight
  static const tertiaryDefault = Color(0xFFF59E0B);
  static const tertiaryPressed = Color(0xFFD97706);
  static const tertiarySubtle = Color(0xFFFEF3C7);

  // Green — status only: success / available / good standing
  static const successDefault = Color(0xFF22C55E);
  static const successPressed = Color(0xFF16A34A);
  static const successSubtle = Color(0xFFDCFCE7);

  // Red — status only: error / violation
  static const errorDefault = Color(0xFFEF4444);
  static const errorPressed = Color(0xFFDC2626);
  static const errorSubtle = Color(0xFFFEE2E2);

  // Backgrounds
  static const bgPage = Color(0xFFFAFAFA);
  static const bgSurface = Color(0xFFFFFFFF);
  static const bgSurfaceAlt = Color(0xFFF5F5F5);

  // Text
  static const textPrimary = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF8A8A8A);
  static const textDisabled = Color(0xFFAFAFAF);
  static const textOnBrand = Color(0xFFFFFFFF);

  // Border
  static const borderDefault = Color(0xFFE5E5E5);
}
