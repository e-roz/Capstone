import 'package:web/web.dart' as web;

/// The short beep the live gate log plays when a tap is refused.
///
/// A generated tone rather than an audio file: nothing to ship or load, and it
/// plays offline. Browsers keep sound off until the person has clicked the
/// page, so [enable] must be called from a click; after that [beep] works for
/// the rest of the visit. Whether the guard wanted sound is remembered in
/// localStorage, but the click is still needed after each reload.
class AlertSound {
  AlertSound._();

  static const _storageKey = 'aimpark.liveGate.sound';

  static web.AudioContext? _context;

  static bool get isOn => _context != null;

  /// The guard turned sound on during an earlier visit.
  static bool get wanted {
    try {
      return web.window.localStorage.getItem(_storageKey) == 'on';
    } catch (_) {
      return false;
    }
  }

  /// Call from a click. Starts the audio and plays one beep as a check.
  static void enable() {
    try {
      _context ??= web.AudioContext();
      _context!.resume();
      web.window.localStorage.setItem(_storageKey, 'on');
    } catch (_) {
      // No sound in this browser. The red row still shows.
    }
    beep();
  }

  static void disable() {
    try {
      _context?.close();
      web.window.localStorage.setItem(_storageKey, 'off');
    } catch (_) {}
    _context = null;
  }

  /// Two short high tones, quick enough not to annoy on a busy gate.
  static void beep() {
    final context = _context;
    if (context == null) return;

    try {
      final start = context.currentTime;
      for (final offset in const [0.0, 0.18]) {
        final osc = context.createOscillator();
        final gain = context.createGain();
        osc.type = 'square';
        osc.frequency.value = 880;
        gain.gain.value = 0.08;
        osc.connect(gain);
        gain.connect(context.destination);
        osc.start(start + offset);
        osc.stop(start + offset + 0.12);
      }
    } catch (_) {}
  }
}
