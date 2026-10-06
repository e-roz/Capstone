import 'package:flutter/services.dart';

import 'update_config.dart';

/// Thin wrapper over the native side (MainActivity.kt) that actually opens
/// Android's system package installer.
///
/// Flutter has no built-in API for this — the install intent needs a
/// content:// URI from a FileProvider and the `REQUEST_INSTALL_PACKAGES`
/// permission dance, neither of which has a pure-Dart equivalent — so this is
/// a small hand-written MethodChannel rather than a dependency on one of the
/// handful of niche install-apk plugins on pub.dev.
class ApkInstaller {
  const ApkInstaller();

  static const MethodChannel _channel = MethodChannel(
    UpdateConfig.installerChannel,
  );

  /// Whether the OS will currently let this app trigger a package install.
  /// Always true below Android 8 (API 26), which has no such per-app gate.
  Future<bool> canInstall() async {
    final result = await _channel.invokeMethod<bool>('canInstallPackages');
    return result ?? false;
  }

  /// Sends the user to the system "allow installs from this app" screen.
  /// There's no callback for when they come back — the dialog re-checks
  /// [canInstall] when the app resumes.
  Future<void> openInstallPermissionSettings() {
    return _channel.invokeMethod<void>('openInstallPermissionSettings');
  }

  /// Opens the system installer for the APK at [path]. Returns normally once
  /// the installer activity has launched — not once installation finishes,
  /// which Flutter has no way to observe (the app process may be replaced
  /// mid-install).
  Future<void> install(String path) {
    return _channel.invokeMethod<void>('installApk', {'path': path});
  }
}
