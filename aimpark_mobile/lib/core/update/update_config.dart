/// Configuration for the in-app APK self-updater.
///
/// Nothing about "what the latest version is" lives here — only where to ask.
/// The manifest URL is the one thing that would need a code change (and a new
/// APK) to update; everything else about a release lives in the manifest
/// itself, so publishing a new version never requires shipping another APK
/// just to announce it.
abstract class UpdateConfig {
  /// Where the update manifest (see [UpdateManifest]) is fetched from.
  ///
  /// Overridable via `--dart-define=UPDATE_MANIFEST_URL=...` so a developer
  /// can point a debug/manual check at a test manifest without touching this
  /// default, which is the real production manifest committed to the repo.
  static const String manifestUrl = String.fromEnvironment(
    'UPDATE_MANIFEST_URL',
    defaultValue:
        'https://raw.githubusercontent.com/e-roz/Capstone/main/aimpark_mobile/release/update.json',
  );

  /// How long a cached manifest is trusted before [UpdateChecker.checkOnLaunch]
  /// fetches again. Keeps a slow/flaky connection or a busy launch from paying
  /// for a network round-trip every single time.
  static const Duration checkCooldown = Duration(hours: 12);

  /// How long an already-dismissed *optional* update is left alone before it
  /// is offered again. A mandatory update ignores this and is always shown.
  static const Duration optionalRemindAfter = Duration(hours: 24);

  /// Name of the MethodChannel backing [ApkInstaller] (see MainActivity.kt).
  static const String installerChannel = 'com.aimpark.aimpark_mobile/updater';

  /// Matches the FileProvider authority declared in AndroidManifest.xml.
  static const String fileProviderAuthoritySuffix = 'fileprovider';

  // shared_preferences keys.
  static const String prefLastCheckedAt = 'update.last_checked_at';
  static const String prefCachedManifest = 'update.cached_manifest';
  static const String prefLastPromptedVersion = 'update.last_prompted_version';
  static const String prefLastPromptedAt = 'update.last_prompted_at';
}
