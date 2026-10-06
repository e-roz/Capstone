import 'app_version.dart';

/// The remote JSON document the update checker fetches from
/// [UpdateConfig.manifestUrl] — see `aimpark_mobile/release/update.json` and
/// `MD files/MOBILE_UPDATES.md` for the field reference.
///
/// Hand-written parsing (this project has no `json_serializable`), and
/// deliberately strict about what it accepts: a manifest that's missing a
/// required field or offers a plain-`http` APK is rejected outright rather
/// than half-trusted, since this is the one piece of remote, unauthenticated
/// data that can make the app download and launch an installer.
class UpdateManifest {
  const UpdateManifest({
    required this.version,
    required this.build,
    required this.apkUrl,
    this.apkSha256,
    this.apkSizeBytes,
    this.mandatory = false,
    this.minSupportedVersion,
    this.releaseNotes = const [],
  });

  final AppVersion version;
  final int build;
  final String apkUrl;
  final String? apkSha256;
  final int? apkSizeBytes;
  final bool mandatory;
  final AppVersion? minSupportedVersion;
  final List<String> releaseNotes;

  /// Throws [FormatException] for anything that isn't a usable manifest.
  /// Callers (see [UpdateChecker]) treat that the same as a network failure —
  /// log it, don't surface it, and try again on the next check.
  factory UpdateManifest.fromJson(Map<String, dynamic> json) {
    final versionRaw = json['version'];
    if (versionRaw is! String) {
      throw const FormatException('Manifest is missing "version"');
    }
    final version = AppVersion.tryParse(versionRaw);
    if (version == null) {
      throw FormatException('Manifest "version" is not parseable: $versionRaw');
    }

    final build = json['build'];
    if (build is! int) {
      throw const FormatException('Manifest is missing an integer "build"');
    }

    final apkUrl = json['apk_url'];
    if (apkUrl is! String || apkUrl.isEmpty) {
      throw const FormatException('Manifest is missing "apk_url"');
    }
    if (!apkUrl.startsWith('https://')) {
      throw FormatException('Manifest "apk_url" must be https: $apkUrl');
    }

    final apkSha256 = json['apk_sha256'];
    final apkSizeBytes = json['apk_size_bytes'];
    final mandatory = json['mandatory'];

    final minSupportedRaw = json['min_supported_version'];
    final minSupportedVersion =
        minSupportedRaw is String ? AppVersion.tryParse(minSupportedRaw) : null;

    final notesRaw = json['release_notes'];
    final releaseNotes = notesRaw is List
        ? notesRaw.whereType<String>().toList(growable: false)
        : const <String>[];

    return UpdateManifest(
      version: version,
      build: build,
      apkUrl: apkUrl,
      apkSha256: apkSha256 is String && apkSha256.isNotEmpty ? apkSha256 : null,
      apkSizeBytes: apkSizeBytes is int && apkSizeBytes > 0 ? apkSizeBytes : null,
      mandatory: mandatory is bool && mandatory,
      minSupportedVersion: minSupportedVersion,
      // At most 8: a dialog listing forty bullet points is not release notes,
      // it's a changelog nobody will read standing at a gate.
      releaseNotes: releaseNotes.take(8).toList(growable: false),
    );
  }
}
