import 'package:flutter/material.dart';

/// LAYER 1 — Primitives.
///
/// Raw colour ramps with no meaning attached. A primitive says *what a colour
/// is*, never *what it is for*, which is why nothing outside [AppTokens] may
/// import this file: the moment a screen reaches for `AppPalette.indigo500` it
/// has hardcoded a decision that dark mode and future rebrands can no longer
/// reach.
///
/// Ramps follow the conventional 50–900 lightness scale, so "500 is the solid
/// one, 50 is the tint, 700 is the text on the tint" holds for every hue.
///
/// This is the second identity the app has shipped with. The first was a warm
/// orange, Duolingo-register palette; this one is drawn from a clean,
/// map-first campus-parking reference — a deep indigo brand against a mint
/// and cream canvas, flat rather than tactile. See `app_theme.dart` for how
/// that flatness carries into component shape.
class AppPalette {
  AppPalette._();

  // ── Brand — indigo ──────────────────────────────────────────────────────
  // The reference's one strong colour: primary CTAs, the live-session card,
  // the ID card header, the active nav state.
  static const indigo50 = Color(0xFFF1F2FA);
  static const indigo100 = Color(0xFFDEE1F4);
  static const indigo200 = Color(0xFFBCC1E8);
  static const indigo300 = Color(0xFF8F97D8);
  static const indigo400 = Color(0xFF6169C7);
  static const indigo500 = Color(0xFF3C46AE);
  static const indigo600 = Color(0xFF2E3688);
  static const indigo700 = Color(0xFF232967);
  static const indigo800 = Color(0xFF191E4A);
  static const indigo900 = Color(0xFF10132F);

  // ── Neutral ──────────────────────────────────────────────────────────────
  // A cream/paper cast rather than the old warm grey or the admin panel's
  // sand — pale enough that white cards still read as a step up from it.
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

  // ── Accent — sky ─────────────────────────────────────────────────────────
  // Secondary actions and the "informational" status tone — lighter and
  // cooler than the indigo brand so the two never get mistaken for one hue.
  static const sky50 = Color(0xFFEAF5FC);
  static const sky100 = Color(0xFFD2EAF9);
  static const sky200 = Color(0xFFA6D5F3);
  static const sky300 = Color(0xFF72BBEA);
  static const sky400 = Color(0xFF3FA0DE);
  static const sky500 = Color(0xFF1E86C8);
  static const sky600 = Color(0xFF1569A0);
  static const sky700 = Color(0xFF114F79);

  // ── Tertiary — mint ──────────────────────────────────────────────────────
  // The reference's other recurring hue — the hero/onboarding wash, and the
  // "available" tag. A third colour rather than a second brand, kept out of
  // any button role so "this space is free" never reads as "tap here".
  static const mint50 = Color(0xFFEAF8F3);
  static const mint100 = Color(0xFFD3F1E6);
  static const mint200 = Color(0xFFA8E3CE);
  static const mint300 = Color(0xFF77D1B3);
  static const mint400 = Color(0xFF45BB97);
  static const mint500 = Color(0xFF22A67E);
  static const mint600 = Color(0xFF178A69);
  static const mint700 = Color(0xFF106B52);

  // ── Success — green ──────────────────────────────────────────────────────
  // Kept distinct from [mint] even though the two sit close: mint is a brand
  // wash that shows up on chrome that carries no status meaning (the hero
  // background), and reusing it for "success" would make that chrome read as
  // a state. A dedicated green removes the ambiguity.
  static const green50 = Color(0xFFEAF7EE);
  static const green100 = Color(0xFFD1EEDA);
  static const green200 = Color(0xFFA3DDB5);
  static const green300 = Color(0xFF6FC98A);
  static const green400 = Color(0xFF3FB166);
  static const green500 = Color(0xFF249349);
  static const green600 = Color(0xFF19753A);
  static const green700 = Color(0xFF14582C);

  // ── Warning — amber ──────────────────────────────────────────────────────
  static const amber50 = Color(0xFFFEF6E7);
  static const amber100 = Color(0xFFFCEACB);
  static const amber200 = Color(0xFFF7D592);
  static const amber300 = Color(0xFFF0BC5D);
  static const amber400 = Color(0xFFE7A83B);
  static const amber500 = Color(0xFFD6931F);
  static const amber600 = Color(0xFFAD7315);
  static const amber700 = Color(0xFF7D530F);

  // ── Danger — coral ───────────────────────────────────────────────────────
  // Warmer and less saturated than a pure stop-sign red, matching the
  // reference's "Pay now" / "Delete account" tone.
  static const red50 = Color(0xFFFDEDEB);
  static const red100 = Color(0xFFFBDAD5);
  static const red200 = Color(0xFFF5B3A8);
  static const red300 = Color(0xFFEE8A78);
  static const red400 = Color(0xFFE66950);
  static const red500 = Color(0xFFDC5138);
  static const red600 = Color(0xFFB93F29);
  static const red700 = Color(0xFF8F311F);

  /// Full-bleed canvas behind the launch/splash screen. Kept separate from
  /// [indigo500] for the same reason the previous identity kept its splash
  /// orange separate: matched by the native launch screen and the adaptive
  /// icon background, so retuning the brand tone should never shift the very
  /// first frame of the app without a deliberate asset update alongside it.
  static const splashIndigo = Color(0xFF2E3688);
}
