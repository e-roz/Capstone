/// A parsed `MAJOR.MINOR.PATCH` version, compared numerically rather than as
/// a string.
///
/// String comparison is why "1.0.9" > "1.0.10" would be wrong — `'9' > '1'`
/// lexicographically even though 10 is the newer release. Parsing each part as
/// an integer first is the only thing that makes `1.0.9 < 1.0.10` true.
class AppVersion implements Comparable<AppVersion> {
  const AppVersion(this.major, this.minor, this.patch);

  final int major;
  final int minor;
  final int patch;

  /// Parses `"1.2.3"`, `"v1.2.3"`, `"1.2"` (patch defaults to 0) or `"1"`
  /// (minor and patch default to 0). Build metadata (`+5`) and pre-release
  /// tags (`-beta`) are stripped before parsing, since this app only ever
  /// compares the three-part release number.
  ///
  /// Returns null for anything that doesn't parse cleanly — a malformed
  /// remote manifest should never crash the update check, just fail to offer
  /// an update.
  static AppVersion? tryParse(String input) {
    var value = input.trim();
    if (value.isEmpty) return null;

    if (value.startsWith('v') || value.startsWith('V')) {
      value = value.substring(1);
    }

    final metadataIndex = value.indexOf(RegExp(r'[+-]'));
    if (metadataIndex != -1) {
      value = value.substring(0, metadataIndex);
    }

    final parts = value.split('.');
    if (parts.isEmpty || parts.length > 3) return null;

    final numbers = <int>[];
    for (final part in parts) {
      final n = int.tryParse(part);
      if (n == null || n < 0) return null;
      numbers.add(n);
    }

    while (numbers.length < 3) {
      numbers.add(0);
    }

    return AppVersion(numbers[0], numbers[1], numbers[2]);
  }

  @override
  int compareTo(AppVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    return patch.compareTo(other.patch);
  }

  bool operator <(AppVersion other) => compareTo(other) < 0;
  bool operator <=(AppVersion other) => compareTo(other) <= 0;
  bool operator >(AppVersion other) => compareTo(other) > 0;
  bool operator >=(AppVersion other) => compareTo(other) >= 0;

  @override
  bool operator ==(Object other) =>
      other is AppVersion &&
      major == other.major &&
      minor == other.minor &&
      patch == other.patch;

  @override
  int get hashCode => Object.hash(major, minor, patch);

  @override
  String toString() => '$major.$minor.$patch';
}
