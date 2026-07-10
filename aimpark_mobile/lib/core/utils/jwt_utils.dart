import 'dart:convert';

class JwtUtils {
  JwtUtils._();

  static const _roleClaimUri =
      'http://schemas.microsoft.com/ws/2008/06/identity/claims/role';

  static Map<String, dynamic>? decodePayload(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) {
        return null;
      }

      final normalized = base64Url.normalize(parts[1]);
      final decoded = utf8.decode(base64Url.decode(normalized));
      return jsonDecode(decoded) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static bool isExpired(String token) {
    final payload = decodePayload(token);
    if (payload == null) {
      return true;
    }

    final exp = payload['exp'];
    if (exp == null) {
      return true;
    }

    final expirySeconds = exp is int ? exp : int.tryParse(exp.toString());
    if (expirySeconds == null) {
      return true;
    }

    final expiry = DateTime.fromMillisecondsSinceEpoch(expirySeconds * 1000);
    return DateTime.now().isAfter(expiry);
  }

  static bool isValid(String token) {
    if (token.isEmpty) {
      return false;
    }
    return decodePayload(token) != null && !isExpired(token);
  }

  static String? getRole(String token) {
    final payload = decodePayload(token);
    if (payload == null) {
      return null;
    }

    final role = payload['role'] ?? payload[_roleClaimUri];
    return role?.toString();
  }

  static String? homeRouteForRole(String? role) {
    switch (role) {
      case 'Admin':
        return '/home/admin';
      case 'Security':
        return '/home/security';
      case 'User':
        return '/home/user';
      default:
        return null;
    }
  }

  /// Returns true when the token was issued with `registration_only: "true"`,
  /// meaning the user has not finished the registration flow yet.
  static bool isRegistrationOnly(String token) {
    final payload = decodePayload(token);
    return payload?['registration_only']?.toString() == 'true';
  }

  /// Reads the `registrationStep` claim from a registration-only JWT.
  static String? getRegistrationStep(String token) {
    final payload = decodePayload(token);
    return payload?['registrationStep']?.toString();
  }

  /// Returns the correct named-route for the user after any successful sign-in
  /// (local OR OAuth). If registration is incomplete it returns the next step's
  /// route; if registration is complete it returns the role home route.
  static String routeAfterLogin(String token) {
    if (!isRegistrationOnly(token)) {
      final role = getRole(token);
      return homeRouteForRole(role) ?? '/login';
    }

    final step = getRegistrationStep(token);
    switch (step) {
      case 'ProfileSetup':
        return '/register/profile';
      case 'VehicleInfo':
        return '/register/vehicle';
      case 'DocumentUpload':
        return '/register/documents';
      default:
        // EmailVerification, Submitted, or unknown — send to email step
        return '/register/email';
    }
  }
}
