import '../../../core/theme/theme.dart';

/// The user is warned this many days before something runs out.
///
/// The admin panel warns earlier (60 days) and goes urgent at 30, so an admin
/// sees a problem coming well before the user's own countdown starts.
const int expiryWarningDays = 30;

enum ExpiryLevel { valid, soon, expired, unknown }

/// How far off an expiry date is, said in days.
class ExpiryInfo {
  const ExpiryInfo._(this.level, this.days);

  final ExpiryLevel level;

  /// Whole calendar days from today. Negative once the date has passed.
  final int days;

  /// Compared on the calendar date, not the instant: an expiry is a day, and
  /// "expires in 0 days" should mean today, not fourteen hours.
  factory ExpiryInfo.of(DateTime? date, {DateTime? now}) {
    if (date == null) return const ExpiryInfo._(ExpiryLevel.unknown, 0);

    final today = now ?? DateTime.now();
    final local = date.toLocal();
    final days = DateTime(local.year, local.month, local.day)
        .difference(DateTime(today.year, today.month, today.day))
        .inDays;

    final level = days < 0
        ? ExpiryLevel.expired
        : days <= expiryWarningDays
            ? ExpiryLevel.soon
            : ExpiryLevel.valid;

    return ExpiryInfo._(level, days);
  }

  bool get needsAttention =>
      level == ExpiryLevel.soon || level == ExpiryLevel.expired;

  StatusIntent get intent => switch (level) {
        ExpiryLevel.valid => StatusIntent.success,
        ExpiryLevel.soon => StatusIntent.warning,
        ExpiryLevel.expired => StatusIntent.danger,
        ExpiryLevel.unknown => StatusIntent.neutral,
      };

  static String _n(int d) => '$d ${d == 1 ? 'day' : 'days'}';

  /// "18 days left", "Expires today", "Expired 3 days ago".
  String get phrase => switch (level) {
        ExpiryLevel.valid || ExpiryLevel.soon =>
          days == 0 ? 'Expires today' : '${_n(days)} left',
        ExpiryLevel.expired => 'Expired ${_n(-days)} ago',
        ExpiryLevel.unknown => 'No date on file',
      };
}
