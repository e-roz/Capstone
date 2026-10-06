import 'app_version.dart';
import 'update_manifest.dart';

/// What the app should do about an available update.
class UpdateOffer {
  const UpdateOffer({required this.manifest, required this.isMandatory});

  final UpdateManifest manifest;
  final bool isMandatory;
}

/// Decides whether [manifest] is actually newer than what's installed, and
/// if so, whether accepting it is optional or required.
///
/// Pure and side-effect free on purpose — this is the one piece of the
/// updater worth unit testing in isolation (see
/// `test/core/update/update_policy_test.dart`), and keeping it a plain
/// function rather than a method on a stateful class is what makes that easy.
UpdateOffer? evaluateUpdate({
  required UpdateManifest manifest,
  required AppVersion localVersion,
  required int localBuild,
}) {
  final remoteVersion = manifest.version;

  // Equal or older semver is never an update, regardless of build number.
  if (remoteVersion <= localVersion) return null;

  // A higher semver with a build number that didn't also go up means the
  // manifest was edited incorrectly (or `pubspec.yaml`'s +build wasn't
  // bumped before publishing) — Android itself would refuse to install over
  // an equal-or-lower versionCode, so there's no point offering it.
  if (manifest.build <= localBuild) return null;

  final belowMinSupported = manifest.minSupportedVersion != null &&
      localVersion < manifest.minSupportedVersion!;

  return UpdateOffer(
    manifest: manifest,
    isMandatory: manifest.mandatory || belowMinSupported,
  );
}
