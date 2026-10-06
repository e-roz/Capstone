import 'package:flutter_test/flutter_test.dart';

import 'package:aimpark_mobile/core/update/app_version.dart';
import 'package:aimpark_mobile/core/update/update_manifest.dart';
import 'package:aimpark_mobile/core/update/update_policy.dart';

UpdateManifest _manifest({
  String version = '1.0.1',
  int build = 2,
  bool mandatory = false,
  String? minSupportedVersion,
}) {
  return UpdateManifest.fromJson({
    'version': version,
    'build': build,
    'apk_url': 'https://example.com/app.apk',
    'mandatory': mandatory,
    if (minSupportedVersion != null)
      'min_supported_version': minSupportedVersion,
  });
}

void main() {
  group('evaluateUpdate', () {
    test('offers an update when remote version and build are both newer', () {
      final offer = evaluateUpdate(
        manifest: _manifest(version: '1.0.1', build: 2),
        localVersion: const AppVersion(1, 0, 0),
        localBuild: 1,
      );
      expect(offer, isNotNull);
      expect(offer!.isMandatory, isFalse);
    });

    test('does not offer when remote version equals local', () {
      final offer = evaluateUpdate(
        manifest: _manifest(version: '1.0.0', build: 2),
        localVersion: const AppVersion(1, 0, 0),
        localBuild: 1,
      );
      expect(offer, isNull);
    });

    test('does not offer a downgrade', () {
      final offer = evaluateUpdate(
        manifest: _manifest(version: '0.9.0', build: 1),
        localVersion: const AppVersion(1, 0, 0),
        localBuild: 5,
      );
      expect(offer, isNull);
    });

    test('does not offer when semver is newer but build number is not', () {
      final offer = evaluateUpdate(
        manifest: _manifest(version: '1.0.1', build: 1),
        localVersion: const AppVersion(1, 0, 0),
        localBuild: 1,
      );
      expect(offer, isNull);
    });

    test('is mandatory when the manifest says so', () {
      final offer = evaluateUpdate(
        manifest: _manifest(version: '1.0.1', build: 2, mandatory: true),
        localVersion: const AppVersion(1, 0, 0),
        localBuild: 1,
      );
      expect(offer!.isMandatory, isTrue);
    });

    test('is mandatory when the local version is below min_supported_version', () {
      final offer = evaluateUpdate(
        manifest: _manifest(
          version: '1.1.0',
          build: 3,
          minSupportedVersion: '1.0.0',
        ),
        localVersion: const AppVersion(0, 9, 0),
        localBuild: 1,
      );
      expect(offer!.isMandatory, isTrue);
    });

    test('is optional when local version already meets min_supported_version', () {
      final offer = evaluateUpdate(
        manifest: _manifest(
          version: '1.1.0',
          build: 3,
          minSupportedVersion: '1.0.0',
        ),
        localVersion: const AppVersion(1, 0, 0),
        localBuild: 2,
      );
      expect(offer!.isMandatory, isFalse);
    });
  });
}
