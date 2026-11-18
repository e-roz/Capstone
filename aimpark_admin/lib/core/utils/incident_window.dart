import 'ph_time.dart';

/// The least an incident lookup reaches back, so a report just after midnight
/// still covers the evening before.
const incidentMinimumLookBack = Duration(hours: 6);

/// When the lookup for a report starts: midnight in Manila on the day of the
/// report, or six hours before it, whichever is earlier. Damage is usually
/// found some time after it happened. The same window the API uses for a
/// user's "possibly involved" (IncidentInvolvement), so the two never disagree.
DateTime incidentWindowStart(DateTime reportedAt) {
  final m = manila(reportedAt);
  // Manila midnight as a real instant: the wall-clock date at 00:00, less the
  // eight hours manila() added.
  final midnight =
      DateTime.utc(m.year, m.month, m.day).subtract(const Duration(hours: 8));
  final minimum = reportedAt.toUtc().subtract(incidentMinimumLookBack);
  return midnight.isBefore(minimum) ? midnight : minimum;
}
