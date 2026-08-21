import 'package:flutter/material.dart';

/// LAYER 1 — Primitives.
///
/// Raw colour ramps with no meaning attached. A primitive says *what a colour
/// is*, never *what it is for*, which is why nothing outside [AppTokens] may
/// import this file: the moment a screen reaches for `AppPalette.red500` it has
/// hardcoded a decision that dark mode and future rebrands can no longer reach.
///
/// Ramps follow the conventional 50–900 lightness scale, so "600 is the solid
/// one, 100 is the tint, 700 is the text on the tint" holds for every hue and
/// you never have to eyeball a pairing.
class AppPalette {
  AppPalette._();

  // ── Brand ─────────────────────────────────────────────────────────────────
  // Anchored on the indigo-800 the panel already shipped with, so the rebrand
  // reads as a refinement of AimPark rather than a different product.
  static const brand50 = Color(0xFFEFF6FF);
  static const brand100 = Color(0xFFDBEAFE);
  static const brand200 = Color(0xFFBFDBFE);
  static const brand300 = Color(0xFF93C5FD);
  static const brand400 = Color(0xFF60A5FA);
  static const brand500 = Color(0xFF3B82F6);
  static const brand600 = Color(0xFF2563EB);
  static const brand700 = Color(0xFF1D4ED8);
  static const brand800 = Color(0xFF1E40AF);
  static const brand900 = Color(0xFF1E3A8A);
  static const brand950 = Color(0xFF172554);

  // ── Neutral ───────────────────────────────────────────────────────────────
  // Slate rather than pure grey: the faint blue cast keeps the neutrals from
  // looking dirty next to the brand blue.
  static const neutral0 = Color(0xFFFFFFFF);
  static const neutral50 = Color(0xFFF8FAFC);
  static const neutral100 = Color(0xFFF1F5F9);
  static const neutral200 = Color(0xFFE2E8F0);
  static const neutral300 = Color(0xFFCBD5E1);
  static const neutral400 = Color(0xFF94A3B8);
  static const neutral500 = Color(0xFF64748B);
  static const neutral600 = Color(0xFF475569);
  static const neutral700 = Color(0xFF334155);
  static const neutral800 = Color(0xFF1E293B);
  static const neutral900 = Color(0xFF0F172A);
  static const neutral950 = Color(0xFF020617);

  // ── Success ───────────────────────────────────────────────────────────────
  static const green50 = Color(0xFFECFDF5);
  static const green100 = Color(0xFFD1FAE5);
  static const green200 = Color(0xFFA7F3D0);
  static const green400 = Color(0xFF34D399);
  static const green500 = Color(0xFF10B981);
  static const green600 = Color(0xFF059669);
  static const green700 = Color(0xFF047857);
  static const green900 = Color(0xFF064E3B);

  // ── Danger ────────────────────────────────────────────────────────────────
  static const red50 = Color(0xFFFEF2F2);
  static const red100 = Color(0xFFFEE2E2);
  static const red200 = Color(0xFFFECACA);
  static const red400 = Color(0xFFF87171);
  static const red500 = Color(0xFFEF4444);
  static const red600 = Color(0xFFDC2626);
  static const red700 = Color(0xFFB91C1C);
  static const red900 = Color(0xFF7F1D1D);

  // ── Warning ───────────────────────────────────────────────────────────────
  static const amber50 = Color(0xFFFFFBEB);
  static const amber100 = Color(0xFFFEF3C7);
  static const amber200 = Color(0xFFFDE68A);
  static const amber400 = Color(0xFFFBBF24);
  static const amber500 = Color(0xFFF59E0B);
  static const amber600 = Color(0xFFD97706);
  static const amber700 = Color(0xFFB45309);
  static const amber900 = Color(0xFF78350F);

  // ── Info ──────────────────────────────────────────────────────────────────
  static const sky50 = Color(0xFFF0F9FF);
  static const sky100 = Color(0xFFE0F2FE);
  static const sky200 = Color(0xFFBAE6FD);
  static const sky400 = Color(0xFF38BDF8);
  static const sky500 = Color(0xFF0EA5E9);
  static const sky600 = Color(0xFF0284C7);
  static const sky700 = Color(0xFF0369A1);
  static const sky900 = Color(0xFF0C4A6E);

  // ── Accent ────────────────────────────────────────────────────────────────
  // Violet earns its place as the categorical-chart partner to brand blue and
  // as the "in progress" tone; it is deliberately not a second brand colour.
  static const violet100 = Color(0xFFEDE9FE);
  static const violet400 = Color(0xFFA78BFA);
  static const violet500 = Color(0xFF8B5CF6);
  static const violet600 = Color(0xFF7C3AED);
  static const violet700 = Color(0xFF6D28D9);

  static const teal500 = Color(0xFF14B8A6);
  static const teal600 = Color(0xFF0D9488);
}
