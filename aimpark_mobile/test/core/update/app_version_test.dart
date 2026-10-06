import 'package:flutter_test/flutter_test.dart';

import 'package:aimpark_mobile/core/update/app_version.dart';

void main() {
  group('AppVersion.tryParse', () {
    test('parses a plain three-part version', () {
      expect(AppVersion.tryParse('1.2.3'), const AppVersion(1, 2, 3));
    });

    test('pads a missing patch/minor with 0', () {
      expect(AppVersion.tryParse('1.2'), const AppVersion(1, 2, 0));
      expect(AppVersion.tryParse('1'), const AppVersion(1, 0, 0));
    });

    test('strips a leading v', () {
      expect(AppVersion.tryParse('v1.2.3'), const AppVersion(1, 2, 3));
    });

    test('strips build metadata and pre-release tags', () {
      expect(AppVersion.tryParse('1.0.0+5'), const AppVersion(1, 0, 0));
      expect(AppVersion.tryParse('1.0.0-beta'), const AppVersion(1, 0, 0));
    });

    test('returns null for garbage input', () {
      expect(AppVersion.tryParse(''), isNull);
      expect(AppVersion.tryParse('not-a-version'), isNull);
      expect(AppVersion.tryParse('1.2.3.4'), isNull);
      expect(AppVersion.tryParse('1.-2.3'), isNull);
    });
  });

  group('AppVersion ordering', () {
    test('compares by integer, not lexicographically', () {
      expect(AppVersion.tryParse('1.0.9')! < AppVersion.tryParse('1.0.10')!,
          isTrue);
      expect(AppVersion.tryParse('1.2.0')! > AppVersion.tryParse('1.1.99')!,
          isTrue);
      expect(AppVersion.tryParse('2.0.0')! > AppVersion.tryParse('1.9.9')!,
          isTrue);
    });

    test('equal versions compare equal', () {
      expect(AppVersion.tryParse('1.2')! == AppVersion.tryParse('1.2.0')!,
          isTrue);
    });
  });
}
