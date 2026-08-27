/// Shape checks the app can make before bothering the server.
///
/// Deliberately loose. The point is not to decide what a valid address is —
/// only the server sending mail to it can do that — but to catch the typo that
/// would otherwise cost someone a one-time password sent nowhere and a minute
/// of cooldown before they may even try again.
library;

/// A local part, an `@`, a dotted domain, and no spaces anywhere.
///
/// Every stricter rule invented for this ends up rejecting a real address, and
/// the cost of letting an odd-looking one through is nil — the OTP simply does
/// not arrive, which is the same outcome as a wrong-but-well-formed address.
final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

bool isValidEmail(String value) => _emailPattern.hasMatch(value.trim());
