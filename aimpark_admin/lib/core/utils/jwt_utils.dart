import 'dart:convert';

import '../../router/destinations.dart';

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

  /// Which kind of staff account this token belongs to, or null for anything
  /// that has no business in this panel.
  static StaffRole? staffRole(String token) =>
      StaffRole.fromClaim(getRole(token));

  /// Returns the email claim, or null if not present. The sidebar's user chip
  /// shows this: the token carries no display name, and an email is at least
  /// true, where an invented "Administrator" would not be.
  static String? getEmail(String token) {
    final payload = _decodePayload(token);
    if (payload == null) return null;
    const emailKey =
        'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress';
    return (payload[emailKey] ?? payload['email'])?.toString();
  }
}
