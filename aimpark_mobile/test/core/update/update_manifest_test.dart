import 'package:flutter_test/flutter_test.dart';

import 'package:aimpark_mobile/core/update/app_version.dart';
import 'package:aimpark_mobile/core/update/update_manifest.dart';

Map<String, dynamic> _validJson({Map<String, dynamic> overrides = const {}}) {
  return {
    'version': '1.0.1',
    'build': 2,
    'apk_url': 'https://example.com/app.apk',
    ...overrides,
  };
}

void main() {
  group('UpdateManifest.fromJson', () {
    test('parses a minimal valid manifest', () {
      final manifest = UpdateManifest.fromJson(_validJson());
      expect(manifest.version, const AppVersion(1, 0, 1));
      expect(manifest.build, 2);
      expect(manifest.apkUrl, 'https://example.com/app.apk');
      expect(manifest.mandatory, isFalse);
      expect(manifest.releaseNotes, isEmpty);
    });

    test('parses optional fields when present', () {
      final manifest = UpdateManifest.fromJson(_validJson(overrides: {
        'apk_sha256': 'abc123',
        'apk_size_bytes': 1024,
        'mandatory': true,
        'min_supported_version': '1.0.0',
        'release_notes': ['Fix A', 'Fix B'],
      }));

      expect(manifest.apkSha256, 'abc123');
      expect(manifest.apkSizeBytes, 1024);
      expect(manifest.mandatory, isTrue);
      expect(manifest.minSupportedVersion, const AppVersion(1, 0, 0));
      expect(manifest.releaseNotes, ['Fix A', 'Fix B']);
    });

    test('ignores unknown keys', () {
      final manifest = UpdateManifest.fromJson(
        _validJson(overrides: {'some_future_field': 'whatever'}),
      );
      expect(manifest.version, const AppVersion(1, 0, 1));
    });

    test('caps release notes at 8', () {
      final manifest = UpdateManifest.fromJson(_validJson(overrides: {
        'release_notes': List.generate(20, (i) => 'Note $i'),
      }));
      expect(manifest.releaseNotes, hasLength(8));
    });

    test('throws when version is missing', () {
      final json = _validJson()..remove('version');
      expect(() => UpdateManifest.fromJson(json), throwsFormatException);
    });

    test('throws when version is unparseable', () {
      expect(
        () => UpdateManifest.fromJson(
          _validJson(overrides: {'version': 'not-a-version'}),
        ),
        throwsFormatException,
      );
    });

    test('throws when build is missing', () {
      final json = _validJson()..remove('build');
      expect(() => UpdateManifest.fromJson(json), throwsFormatException);
    });

    test('throws when apk_url is missing', () {
      final json = _validJson()..remove('apk_url');
      expect(() => UpdateManifest.fromJson(json), throwsFormatException);
    });

    test('rejects a non-https apk_url', () {
      expect(
        () => UpdateManifest.fromJson(
          _validJson(overrides: {'apk_url': 'http://example.com/app.apk'}),
        ),
        throwsFormatException,
      );
    });
  });
}
