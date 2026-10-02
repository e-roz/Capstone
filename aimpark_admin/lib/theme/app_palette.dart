import 'package:flutter/material.dart';

/// LAYER 1 — Primitives.
///
/// Raw colour ramps with no meaning attached. A primitive says *what a colour
/// is*, never *what it is for*, which is why nothing outside [AppTokens] may
/// import this file: the moment a screen reaches for `AppPalette.red500` it has
/// hardcoded a decision that dark mode and future rebrands can no longer reach.
///
/// Ramps follow the conventional 50–900 lightness scale, so "500 is the solid
/// one, 100 is the tint, 700 is the text on the tint" holds for every hue and
/// you never have to eyeball a pairing.
///
/// The panel shares its identity with the mobile app: the values below are
/// the same ramps as `aimpark_mobile/lib/core/theme/app_palette.dart` — a
/// deep indigo brand against a mint and cream canvas. Change a hue there and
/// here together, or the two products drift apart. What the panel does *not*
/// share is density; see `app_dimensions.dart` and `app_typography.dart`.
class AppPalette {
  AppPalette._();

  // ── Brand — indigo ────────────────────────────────────────────────────────
  // Primary actions, the active nav pill, focus rings, and — at the dark end —
  // the sidebar, echoing the indigo live-session and ID cards on mobile.
  static const brand50 = Color(0xFFF1F2FA);
  static const brand100 = Color(0xFFDEE1F4);
  static const brand200 = Color(0xFFBCC1E8);
  static const brand300 = Color(0xFF8F97D8);
  static const brand400 = Color(0xFF6169C7);
  static const brand500 = Color(0xFF3C46AE);
  static const brand600 = Color(0xFF2E3688);
  static const brand700 = Color(0xFF232967);
  static const brand800 = Color(0xFF191E4A);
  static const brand900 = Color(0xFF10132F);

  // ── Neutral — cream ───────────────────────────────────────────────────────
  // Surfaces, dividers *and* text. The mobile app keeps text on this same
  // ramp, so the panel dropped its separate cool `ink` ramp to match.
  static const neutral0 = Color(0xFFFFFFFF);
  static const neutral50 = Color(0xFFF7F7F3);
  static const neutral100 = Color(0xFFF0EFE9);
  static const neutral200 = Color(0xFFE2E0D7);
  static const neutral300 = Color(0xFFCBC8BB);
  static const neutral400 = Color(0xFF9E9A8C);
  static const neutral500 = Color(0xFF74705F);
  static const neutral600 = Color(0xFF54503F);
  static const neutral700 = Color(0xFF3A3728);
  static const neutral800 = Color(0xFF24221A);
  static const neutral900 = Color(0xFF161510);
  static const neutral950 = Color(0xFF0B0A07);

  // ── Info — sky ────────────────────────────────────────────────────────────
  // Lighter and cooler than the indigo brand so "informational" never reads
  // as "primary action".
  static const sky50 = Color(0xFFEAF5FC);
  static const sky100 = Color(0xFFD2EAF9);
  static const sky200 = Color(0xFFA6D5F3);
  static const sky300 = Color(0xFF72BBEA);
  static const sky400 = Color(0xFF3FA0DE);
  static const sky500 = Color(0xFF1E86C8);
  static const sky600 = Color(0xFF1569A0);
  static const sky700 = Color(0xFF114F79);

  // ── Tertiary — mint ───────────────────────────────────────────────────────
  // The mobile app's other recurring hue. Kept out of any button role, and out
  // of the success role too (that is [green]) — here it is a chart series.
  static const mint50 = Color(0xFFEAF8F3);
  static const mint100 = Color(0xFFD3F1E6);
  static const mint200 = Color(0xFFA8E3CE);
  static const mint300 = Color(0xFF77D1B3);
  static const mint400 = Color(0xFF45BB97);
  static const mint500 = Color(0xFF22A67E);
  static const mint600 = Color(0xFF178A69);
  static const mint700 = Color(0xFF106B52);

  // ── Success — green ───────────────────────────────────────────────────────
  static const green50 = Color(0xFFEAF7EE);
  static const green100 = Color(0xFFD1EEDA);
  static const green200 = Color(0xFFA3DDB5);
  static const green300 = Color(0xFF6FC98A);
  static const green400 = Color(0xFF3FB166);
  static const green500 = Color(0xFF249349);
  static const green600 = Color(0xFF19753A);
  static const green700 = Color(0xFF14582C);

  // ── Warning — amber ───────────────────────────────────────────────────────
  static const amber50 = Color(0xFFFEF6E7);
  static const amber100 = Color(0xFFFCEACB);
  static const amber200 = Color(0xFFF7D592);
  static const amber300 = Color(0xFFF0BC5D);
  static const amber400 = Color(0xFFE7A83B);
  static const amber500 = Color(0xFFD6931F);
  static const amber600 = Color(0xFFAD7315);
  static const amber700 = Color(0xFF7D530F);

  // ── Danger — coral ────────────────────────────────────────────────────────
  static const red50 = Color(0xFFFDEDEB);
  static const red100 = Color(0xFFFBDAD5);
  static const red200 = Color(0xFFF5B3A8);
  static const red300 = Color(0xFFEE8A78);
  static const red400 = Color(0xFFE66950);
  static const red500 = Color(0xFFDC5138);
  static const red600 = Color(0xFFB93F29);
  static const red700 = Color(0xFF8F311F);

  // ── Accent — violet ───────────────────────────────────────────────────────
  // Panel-only: the "in progress" tone and a categorical-chart partner to the
  // brand. Pushed further toward magenta than the old panel violet so it sits
  // clearly apart from the indigo brand rather than reading as a tint of it.
  static const violet50 = Color(0xFFF5EEFB);
  static const violet100 = Color(0xFFEBDCF7);
  static const violet400 = Color(0xFFB27FDD);
  static const violet500 = Color(0xFF9055C4);
  static const violet600 = Color(0xFF7440A3);
  static const violet700 = Color(0xFF55307A);

  // Chart-only: a warm hue so a categorical series doesn't repeat the brand.
  // Never used for status — danger already owns red.
  static const rose400 = Color(0xFFF97F95);
  static const rose500 = Color(0xFFDB4B6D);
}
