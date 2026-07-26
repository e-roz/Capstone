class ApiConstants {
  ApiConstants._();

  /// Backend base URL. The default points at a machine on the local network for
  /// development against a locally-run API; release builds override it:
  ///
  ///   flutter build apk --release --dart-define=API_BASE_URL=https://your-api.onrender.com
  ///
  /// Note the default is only reachable from the same Wi-Fi — a distributed APK
  /// must always be built with API_BASE_URL set to the deployed URL.
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.100.95:5041',
  );
}
