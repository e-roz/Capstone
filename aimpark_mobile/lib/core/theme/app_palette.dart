import 'package:flutter/material.dart';

/// LAYER 1 — Primitives.
///
/// Raw colour ramps with no meaning attached. A primitive says *what a colour
/// is*, never *what it is for*, which is why nothing outside [AppTokens] may
/// import this file: the moment a screen reaches for `AppPalette.orange500` it
/// has hardcoded a decision that dark mode and future rebrands can no longer
/// reach.
///
/// Ramps follow the conventional 50–950 lightness scale, so "500 is the solid
/// one, 50 is the tint, 700 is the text on the tint" holds for every hue and
/// you never have to eyeball a pairing.
///
/// This file is the mobile app's half of a shared system. `aimpark_admin` has
/// the same three layers with the same class and token names; only the hues
/// and the type differ, because the panel is a dense desk tool and this is a
/// phone app people are meant to enjoy opening. Structure is shared, face is
/// not — see `app_tokens.dart` for the vocabulary the two have in common.
class AppPalette {
  AppPalette._();

  // ── Brand — orange ────────────────────────────────────────────────────────
  // Anchored on the orange-500/600 pair the app already shipped with, so this
  // reads as the same product refined rather than a rebrand.
  static const orange50 = Color(0xFFFFF7ED);
  static const orange100 = Color(0xFFFFEDD5);
  static const orange200 = Color(0xFFFED7AA);
  static const orange300 = Color(0xFFFDBA74);
  static const orange400 = Color(0xFFFB923C);
  static const orange500 = Color(0xFFF97316);
  static const orange600 = Color(0xFFEA580C);
  static const orange700 = Color(0xFFC2410C);
  static const orange800 = Color(0xFF9A3412);
  static const orange900 = Color(0xFF7C2D12);

  // ── Neutral ───────────────────────────────────────────────────────────────
  // Warm grey, not the admin panel's blue-cast slate. Slate next to orange
  // reads as a colour clash rather than as a neutral; warm greys let the brand
  // hue sit on them without arguing.
  static const neutral0 = Color(0xFFFFFFFF);
  static const neutral50 = Color(0xFFFAFAFA);
  static const neutral100 = Color(0xFFF5F5F5);
  static const neutral200 = Color(0xFFE5E5E5);
  static const neutral300 = Color(0xFFD4D4D4);
  static const neutral400 = Color(0xFFA3A3A3);
  static const neutral500 = Color(0xFF737373);
  static const neutral600 = Color(0xFF525252);
  static const neutral700 = Color(0xFF404040);
  static const neutral800 = Color(0xFF262626);
  static const neutral900 = Color(0xFF171717);
  static const neutral950 = Color(0xFF0A0A0A);

  // ── Accent — sky ──────────────────────────────────────────────────────────
  // Secondary actions and the "informational" status tone. Shared with the
  // admin panel's `sky` ramp so an info pill means the same thing in both.
  static const sky50 = Color(0xFFF0F9FF);
  static const sky100 = Color(0xFFE0F2FE);
  static const sky200 = Color(0xFFBAE6FD);
  static const sky300 = Color(0xFF7DD3FC);
  static const sky400 = Color(0xFF38BDF8);
  static const sky500 = Color(0xFF0EA5E9);
  static const sky600 = Color(0xFF0284C7);
  static const sky700 = Color(0xFF0369A1);

  // ── Tertiary — amber ──────────────────────────────────────────────────────
  // The streak hue, and the "warning" status tone.
  static const amber50 = Color(0xFFFFFBEB);
  static const amber100 = Color(0xFFFEF3C7);
  static const amber200 = Color(0xFFFDE68A);
  static const amber300 = Color(0xFFFCD34D);
  static const amber400 = Color(0xFFFBBF24);
  static const amber500 = Color(0xFFF59E0B);
  static const amber600 = Color(0xFFD97706);
  static const amber700 = Color(0xFFB45309);

  // ── Success — green ───────────────────────────────────────────────────────
  // Tailwind `green`, not the panel's `emerald`. The brighter green is the one
  // the gamified surfaces were drawn against, and it holds up better beside
  // orange than emerald's blue lean does.
  static const green50 = Color(0xFFF0FDF4);
  static const green100 = Color(0xFFDCFCE7);
  static const green200 = Color(0xFFBBF7D0);
  static const green300 = Color(0xFF86EFAC);
  static const green400 = Color(0xFF4ADE80);
  static const green500 = Color(0xFF22C55E);
  static const green600 = Color(0xFF16A34A);
  static const green700 = Color(0xFF15803D);

  // ── Danger — red ──────────────────────────────────────────────────────────
  static const red50 = Color(0xFFFEF2F2);
  static const red100 = Color(0xFFFEE2E2);
  static const red200 = Color(0xFFFECACA);
  static const red300 = Color(0xFFFCA5A5);
  static const red400 = Color(0xFFF87171);
  static const red500 = Color(0xFFEF4444);
  static const red600 = Color(0xFFDC2626);
  static const red700 = Color(0xFFB91C1C);

  /// Full-bleed orange canvas behind the launch/splash screen. Taken verbatim
  /// from the splash comp, which sits a touch warmer than [orange500] — keep
  /// them separate so retuning the button orange never shifts the very first
  /// frame of the app (and vice versa).
  ///
  /// Fixed in both themes: it is painted before any theme exists, and it is
  /// matched by the native launch screen and the adaptive icon background.
  static const splashOrange = Color(0xFFF3821F);
}
