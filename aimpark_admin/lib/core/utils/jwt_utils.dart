import 'dart:convert';

class JwtUtils {
  JwtUtils._();

  static Map<String, dynamic>? _decodePayload(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      // Add padding if needed
      var payload = parts[1];
      while (payload.length % 4 != 0) {
        payload += '=';
      }
      final decoded = utf8.decode(base64Url.decode(payload));
      return jsonDecode(decoded) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static bool isValid(String token) {
    final payload = _decodePayload(token);
    if (payload == null) return false;
    final exp = payload['exp'];
    if (exp == null) return false;
    final expiry =
        DateTime.fromMillisecondsSinceEpoch((exp as int) * 1000, isUtc: true);
    return DateTime.now().toUtc().isBefore(expiry);
  }

  /// Returns the role claim value from the JWT, or null if not present.
  static String? getRole(String token) {
    final payload = _decodePayload(token);
    if (payload == null) return null;
    // ASP.NET Core emits role in the long ClaimTypes URI key
    const roleKey =
        'http://schemas.microsoft.com/ws/2008/06/identity/claims/role';
    return (payload[roleKey] ?? payload['role'])?.toString();
  }

  static bool isAdmin(String token) => getRole(token) == 'Admin';
}
