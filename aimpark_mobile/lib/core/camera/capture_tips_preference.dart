import 'package:shared_preferences/shared_preferences.dart';

/// Whether the user has already been shown how to photograph a document.
///
/// A plain preference rather than registration state: the tips are a
/// once-ever primer, not part of any one registration run, so they must
/// survive [RegistrationNotifier.startFresh]/`clearCaptured` and apply
/// equally the first time someone adds a vehicle later. Follows the same
/// shape as `RegistrationDraftStore` — a small class wrapping
/// `SharedPreferences` rather than a provider, since nothing here needs to be
/// watched or rebuilt from.
class CaptureTipsPreference {
  const CaptureTipsPreference();

  static const _key = 'capture_tips_seen';

  Future<bool> hasBeenShown() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  Future<void> markShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
  }
}
