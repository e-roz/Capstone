import 'package:flutter/services.dart';

/// LAYER 2 — Haptic patterns, brief §6.
///
/// The user's eyes are on the gate, not the screen, so the haptic is often
/// the real feedback channel — never the only one (brief §9: always pair
/// with a visible state change too).
///
/// Modelled as trigger methods rather than themed values: a vibration
/// pattern has no colour or size to interpolate, so this sits alongside
/// [EmotionTokens] as a plain const object instead of participating in its
/// `lerp`.
class EmotionHapticTokens {
  const EmotionHapticTokens();

  /// Gate open, registration complete. One medium impact.
  void success() => HapticFeedback.mediumImpact();

  /// Lot filling, low balance. Two light impacts, ~80ms apart.
  Future<void> warning() async {
    HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 80));
    HapticFeedback.lightImpact();
  }

  /// RFID not read, payment failed. Deliberately the *weakest* pattern in the
  /// system — a failure the system caused should never be felt as a
  /// punishment. Do not escalate this to a medium or heavy impact, even for a
  /// failure that feels urgent to fix.
  void error() => HapticFeedback.lightImpact();

  static const instance = EmotionHapticTokens();
}
