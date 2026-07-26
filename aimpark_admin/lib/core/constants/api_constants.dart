class ApiConstants {
  ApiConstants._();

  /// Backend base URL. Defaults to the local API so day-to-day development needs
  /// no extra flags; deployed builds override it at compile time:
  ///
  ///   flutter build web --dart-define=API_BASE_URL=https://your-api.onrender.com
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:5041',
  );
}
