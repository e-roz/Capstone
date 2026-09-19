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
///
/// Values below were converted from the OKLCH colours of a Claude Design
/// mockup (an operations-dashboard reference) — see
/// `docs/admin-design-system.md` for how a re-skin like this should flow
/// through the token layers.
class AppPalette {
  AppPalette._();

  // ── Brand ─────────────────────────────────────────────────────────────────
  // A blue-indigo replaces the teal the panel shipped with previously. It is
  // the accent hue the mockup builds its whole identity around — the logo
  // mark, the active nav pill, the "info" KPI tile.
  static const brand50 = Color(0xFFF1F5FC);
  static const brand100 = Color(0xFFD3E5FF);
  static const brand200 = Color(0xFFC2D8FF);
  static const brand300 = Color(0xFF73A3FC);
  static const brand400 = Color(0xFF4A81EB);
  static const brand500 = Color(0xFF3A6CCE);
  static const brand600 = Color(0xFF2757B6);
  static const brand700 = Color(0xFF194292);
  static const brand800 = Color(0xFF123780);
  static const brand900 = Color(0xFF06235E);
  static const brand950 = Color(0xFF00113E);

  // ── Neutral ───────────────────────────────────────────────────────────────
  // Warm sand — the mockup's page and card surfaces, never quite pure white.
  // This ramp is for surfaces and dividers only; text lives on [AppPalette]'s
  // `ink*` ramp below, which carries a cooler, blue-grey cast. That two-hue
  // split (warm surface, cool ink) is what keeps the mockup from reading as
  // flat sepia — see the header/body contrast in the reference dashboard.
  static const neutral0 = Color(0xFFFBFAF6);
  static const neutral50 = Color(0xFFF7F5F1);
  static const neutral100 = Color(0xFFF3F2ED);
  static const neutral200 = Color(0xFFEAE8E2);
  static const neutral300 = Color(0xFFCDC3AF);
  static const neutral400 = Color(0xFFA69E8D);
  static const neutral500 = Color(0xFF868073);
  static const neutral600 = Color(0xFF635D51);
  static const neutral700 = Color(0xFF413D33);
  static const neutral800 = Color(0xFF211F19);
  static const neutral900 = Color(0xFF13110D);
  static const neutral950 = Color(0xFF0B0905);

  // ── Ink ───────────────────────────────────────────────────────────────────
  // Cool blue-grey, used for every text role and for the dark, high-contrast
  // fills the mockup uses as its "primary button" surface (the active nav
  // tab, the filled "Export report" pill) instead of a brand-coloured fill.
  static const ink50 = Color(0xFFF4F5F8);
  static const ink100 = Color(0xFFE4E8EF);
  static const ink200 = Color(0xFFCACED4);
  static const ink300 = Color(0xFF9EA5B2);
  static const ink400 = Color(0xFF767A84);
  static const ink500 = Color(0xFF51555E);
  static const ink600 = Color(0xFF323845);
  static const ink700 = Color(0xFF1C1F25);
  static const ink800 = Color(0xFF0B0D12);
  static const ink900 = Color(0xFF030305);

  // ── Success ───────────────────────────────────────────────────────────────
  static const green50 = Color(0xFFDEF5E8);
  static const green100 = Color(0xFFC0EED4);
  static const green200 = Color(0xFF8FD7B0);
  static const green400 = Color(0xFF179765);
  static const green500 = Color(0xFF007D50);
  static const green600 = Color(0xFF00613B);
  static const green700 = Color(0xFF004527);
  static const green900 = Color(0xFF001E0C);

  // ── Danger ────────────────────────────────────────────────────────────────
  static const red50 = Color(0xFFFFE7E4);
  static const red100 = Color(0xFFFFD3CD);
  static const red200 = Color(0xFFFFAEA7);
  static const red400 = Color(0xFFF2716A);
  static const red500 = Color(0xFFE3645E);
  static const red600 = Color(0xFFA83634);
  static const red700 = Color(0xFF862726);
  static const red900 = Color(0xFF400407);

  // ── Warning ───────────────────────────────────────────────────────────────
  static const amber50 = Color(0xFFFBF1DC);
  static const amber100 = Color(0xFFFCE9C2);
  static const amber200 = Color(0xFFF4C582);
  static const amber400 = Color(0xFFDEA143);
  static const amber500 = Color(0xFFD79628);
  static const amber600 = Color(0xFFAE7200);
  static const amber700 = Color(0xFF663E00);
  static const amber900 = Color(0xFF371D00);

  // ── Info ──────────────────────────────────────────────────────────────────
  // A teal, not a sky blue, so it reads distinctly from the brand-blue hue —
  // the mockup's own "capacity factor" KPI tile.
  static const teal50 = Color(0xFFD9F5F3);
  static const teal100 = Color(0xFFB4EFEA);
  static const teal200 = Color(0xFF7AD7D1);
  static const teal400 = Color(0xFF009E97);
  static const teal500 = Color(0xFF008781);
  static const teal600 = Color(0xFF006762);
  static const teal700 = Color(0xFF004642);
  static const teal900 = Color(0xFF001E1C);

  // ── Accent ────────────────────────────────────────────────────────────────
  // Violet earns its place as the categorical-chart partner to brand blue and
  // as the "in progress" tone; it is deliberately not a second brand colour.
  // The mockup's reference dashboard has no accent state of its own, so this
  // ramp continues its hue-rotation formula (tint / solid / text-on-tint) at
  // hue 300 rather than copying a value verbatim.
  static const violet50 = Color(0xFFF0ECFA);
  static const violet100 = Color(0xFFE7D9FF);
  static const violet400 = Color(0xFFB48DF4);
  static const violet500 = Color(0xFF8156C0);
  static const violet600 = Color(0xFF663E9E);
  static const violet700 = Color(0xFF492676);

  // Chart-only: a warm fourth hue so a categorical series doesn't repeat the
  // brand blue. Never used for status — danger already owns red.
  static const rose400 = Color(0xFFF97F95);
  static const rose500 = Color(0xFFDB4B6D);
}
