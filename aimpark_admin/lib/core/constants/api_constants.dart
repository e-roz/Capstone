class ApiConstants {
  ApiConstants._();

  static const _configured = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:5041',
  );

  /// Backend base URL. Defaults to the local API so day-to-day development needs
  /// no extra flags; deployed builds override it at compile time:
  ///
  ///   flutter build web --dart-define=API_BASE_URL=https://your-api.onrender.com
  ///
  /// `same-origin` means "whatever server served this page". The guard post's
  /// build uses it, so one build works at http://localhost:5041 on the guard
  /// PC and at http://<its LAN address>:5041 from any other browser.
  static final baseUrl =
      _configured == 'same-origin' ? Uri.base.origin : _configured;
}
