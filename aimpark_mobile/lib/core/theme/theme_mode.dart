import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'theme_mode.g.dart';

/// The user's appearance preference, remembered between launches.
///
/// Defaults to [ThemeMode.system], which is the right default: someone who has
/// put their phone into dark mode at night has already said what they want, and
/// asking again is a setting nobody should have to find.
///
/// The explicit Light and Dark options exist anyway for one practical reason —
/// showing both themes during the defence should not require leaving the app to
/// change a system setting.
@Riverpod(keepAlive: true)
class AppThemeMode extends _$AppThemeMode {
  static const _key = 'theme_mode';

  /// Starts on [ThemeMode.system] and swaps in the stored value once
  /// preferences have loaded.
  ///
  /// Reading synchronously is not possible, and making the whole app await a
  /// preference read would add a blank frame to every cold start. The stored
  /// value arrives a frame or two later; for someone whose choice matches
  /// their system setting — most people — nothing visibly changes at all.
  @override
  ThemeMode build() {
    _restore();
    return ThemeMode.system;
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key);
    if (stored == null) return;

    final restored = _fromName(stored);
    // The user may have tapped a different option while this was in flight.
    // Their tap wins over what was on disk when the app started.
    if (restored != null && state == ThemeMode.system) state = restored;
  }

  Future<void> set(ThemeMode mode) async {
    if (state == mode) return;
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }

  static ThemeMode? _fromName(String name) => switch (name) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        'system' => ThemeMode.system,
        _ => null,
      };
}

/// How each option is labelled in the Account screen's Appearance control.
extension ThemeModeLabel on ThemeMode {
  String get label => switch (this) {
        ThemeMode.system => 'System',
        ThemeMode.light => 'Light',
        ThemeMode.dark => 'Dark',
      };

  IconData get icon => switch (this) {
        ThemeMode.system => Icons.brightness_auto_rounded,
        ThemeMode.light => Icons.light_mode_rounded,
        ThemeMode.dark => Icons.dark_mode_rounded,
      };
}
