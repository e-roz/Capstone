/// Philippine time (UTC+8, no daylight saving), whatever time zone the PC
/// showing the panel is set to.
///
/// The returned value is a UTC [DateTime] whose fields read as Manila wall
/// time, so `DateFormat` prints Manila time from it. Use it only for showing
/// a time, never for arithmetic against other instants.
DateTime manila(DateTime t) => t.toUtc().add(const Duration(hours: 8));

/// The time in Manila right now.
DateTime manilaNow() => manila(DateTime.now());
