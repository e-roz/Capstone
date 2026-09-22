import '../../parking/data/models/parking_history_entry.dart';
import '../../violations/data/models/violation.dart';

/// Where a user sits on the violation record, and what that costs them.
///
/// There is no Standing, Points or Streak entity in the backend — every figure
/// here is derived client-side from real parking logs and violation rows. That
/// makes the rules below the *only* definition of what these numbers mean, so
/// they live in one file rather than as private methods on the dashboard.
///
/// They were private methods on the dashboard, which was fine until a second
/// screen had to explain them. An explanation screen reading from different
/// constants than the screen it explains is a bug that looks like a lie.
enum StandingTier {
  gold,
  silver,
  bronze;

  String get label => switch (this) {
        StandingTier.gold => 'Gold',
        StandingTier.silver => 'Silver',
        StandingTier.bronze => 'Bronze',
      };

  /// What puts you in this tier.
  String get rule => switch (this) {
        StandingTier.gold => 'No unsettled violations',
        StandingTier.silver => 'One unsettled violation',
        StandingTier.bronze => 'Two or more unsettled violations',
      };

  /// What it actually means for you — stated plainly, because a tier that
  /// changes nothing should say so rather than implying a penalty.
  String get effect => switch (this) {
        StandingTier.gold => 'Full access, no restrictions.',
        StandingTier.silver =>
          'Full access. Settle the violation to return to Gold.',
        StandingTier.bronze =>
          'Full access. Repeated unsettled violations may be reviewed by the '
              'parking office.',
      };

  /// A meter reading, for the ring on the dashboard.
  double get level => switch (this) {
        StandingTier.gold => 1.0,
        StandingTier.silver => 0.65,
        StandingTier.bronze => 0.3,
      };
}

abstract final class Standing {
  Standing._();

  /// Awarded per completed parking session.
  static const int pointsPerSession = 10;

  /// Awarded once for every whole week of unbroken streak.
  static const int pointsPerStreakWeek = 50;

  /// Days in a streak week.
  static const int streakWeekDays = 7;

  /// Whether a violation still counts against the user.
  ///
  /// Only `Dismissed` was excluded before. A user who appealed and won watched
  /// their standing stay at Bronze and their streak stay broken, which made
  /// winning the appeal look like losing it — and is exactly the complaint
  /// testers raised.
  static bool countsAgainstUser(ViolationSummary v) {
    final status = v.status.toLowerCase();
    return status != 'dismissed' && status != 'overturned';
  }

  /// Whether a violation should still be holding the standing meter down.
  ///
  /// Narrower than [countsAgainstUser] by one case: a fine that has been paid
  /// is done with, and leaving it counted meant settling up changed nothing the
  /// user could see — the meter sat on Silver with no way back to Gold.
  ///
  /// The streak deliberately keeps using the wider test. Standing is a running
  /// account that paying squares; the streak is a record of which days went
  /// wrong, and paying afterwards does not make the day go right.
  static bool countsAgainstStanding(ViolationSummary v) =>
      countsAgainstUser(v) && !v.isSettled;

  /// Whether a violation is still open — issued, or under appeal — and so is
  /// something the user has to do something about.
  ///
  /// `Upheld` is closed: the appeal was heard and lost, and there is nothing
  /// left to act on but the fee, which the balance covers separately.
  static bool isOpen(ViolationSummary v) {
    final status = v.status.toLowerCase();
    return status == 'issued' || status == 'appealed';
  }

  static StandingTier tierFor(ViolationListResult? violations) {
    final count = (violations?.violations ?? const <ViolationSummary>[])
        .where(countsAgainstStanding)
        .length;
    if (count == 0) return StandingTier.gold;
    if (count == 1) return StandingTier.silver;
    return StandingTier.bronze;
  }

  /// Consecutive days, counting back from today, with a parking log and no
  /// violation issued that day.
  static int streakDays(
    ParkingHistoryResult? history,
    ViolationListResult? violations,
  ) {
    if (history == null) return 0;
    final violationDays = (violations?.violations ?? const <ViolationSummary>[])
        .where(countsAgainstUser)
        .map((v) =>
            DateTime(v.createdAt.year, v.createdAt.month, v.createdAt.day))
        .toSet();
    final parkedDays = history.logs
        .map((l) =>
            DateTime(l.entryTime.year, l.entryTime.month, l.entryTime.day))
        .toSet();

    var streak = 0;
    var cursor = DateTime.now();
    cursor = DateTime(cursor.year, cursor.month, cursor.day);
    while (parkedDays.contains(cursor) && !violationDays.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  static int points(ParkingHistoryResult? history, int streak) {
    if (history == null) return 0;
    return history.totalCount * pointsPerSession +
        (streak ~/ streakWeekDays) * pointsPerStreakWeek;
  }
}
