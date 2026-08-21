/// Summary counts behind the dashboard and Reports.
///
/// The slot figures deserve care: `total` is every bay that physically exists,
/// which is *not* the number to measure occupancy against once some of them are
/// out of service. Use [usableSlots] for that.
class ReportsSummary {
  final int totalUsers;
  final int activeUsers;
  final int totalSlots;
  final int occupiedSlots;
  final int availableSlots;

  /// Bays that exist but cannot be parked in.
  final int outOfServiceSlots;
  final int sessionsToday;
  final double revenueCollected;
  final double revenuePending;
  final int violationsIssued;
  final int openIncidents;

  const ReportsSummary({
    required this.totalUsers,
    required this.activeUsers,
    required this.totalSlots,
    required this.occupiedSlots,
    required this.availableSlots,
    this.outOfServiceSlots = 0,
    required this.sessionsToday,
    required this.revenueCollected,
    required this.revenuePending,
    required this.violationsIssued,
    required this.openIncidents,
  });

  /// Bays that could actually take a car right now — the denominator for any
  /// "how full are we" figure. A lot with 10 bays where 8 are broken is at
  /// capacity with 2 cars, not at 20%.
  int get usableSlots => totalSlots - outOfServiceSlots;

  /// 0.0–1.0. Zero when nothing is usable, which reads better than a division
  /// by zero and is honest: no capacity cannot be "full".
  double get occupancyRatio =>
      usableSlots <= 0 ? 0 : occupiedSlots / usableSlots;

  factory ReportsSummary.fromJson(Map<String, dynamic> json) => ReportsSummary(
        totalUsers: (json['totalUsers'] as num?)?.toInt() ?? 0,
        activeUsers: (json['activeUsers'] as num?)?.toInt() ?? 0,
        totalSlots: (json['totalSlots'] as num?)?.toInt() ?? 0,
        occupiedSlots: (json['occupiedSlots'] as num?)?.toInt() ?? 0,
        availableSlots: (json['availableSlots'] as num?)?.toInt() ?? 0,
        outOfServiceSlots: (json['outOfServiceSlots'] as num?)?.toInt() ?? 0,
        sessionsToday: (json['sessionsToday'] as num?)?.toInt() ?? 0,
        revenueCollected: (json['revenueCollected'] as num?)?.toDouble() ?? 0,
        revenuePending: (json['revenuePending'] as num?)?.toDouble() ?? 0,
        violationsIssued: (json['violationsIssued'] as num?)?.toInt() ?? 0,
        openIncidents: (json['openIncidents'] as num?)?.toInt() ?? 0,
      );
}

class DailyCountPoint {
  final DateTime date;
  final int count;

  const DailyCountPoint({required this.date, required this.count});

  factory DailyCountPoint.fromJson(Map<String, dynamic> json) => DailyCountPoint(
        date: DateTime.parse(json['date'].toString()),
        count: (json['count'] as num?)?.toInt() ?? 0,
      );
}

class PeakHourPoint {
  final int hour;
  final int count;

  const PeakHourPoint({required this.hour, required this.count});

  factory PeakHourPoint.fromJson(Map<String, dynamic> json) => PeakHourPoint(
        hour: (json['hour'] as num?)?.toInt() ?? 0,
        count: (json['count'] as num?)?.toInt() ?? 0,
      );
}

class ViolationStatusCount {
  final String status;
  final int count;

  const ViolationStatusCount({required this.status, required this.count});

  factory ViolationStatusCount.fromJson(Map<String, dynamic> json) =>
      ViolationStatusCount(
        status: json['status']?.toString() ?? '',
        count: (json['count'] as num?)?.toInt() ?? 0,
      );
}

class ViolationRuleCount {
  final String ruleTitle;
  final int count;

  const ViolationRuleCount({required this.ruleTitle, required this.count});

  factory ViolationRuleCount.fromJson(Map<String, dynamic> json) => ViolationRuleCount(
        ruleTitle: json['ruleTitle']?.toString() ?? '',
        count: (json['count'] as num?)?.toInt() ?? 0,
      );
}

class ViolationBreakdown {
  final List<ViolationStatusCount> byStatus;
  final List<ViolationRuleCount> byRule;

  const ViolationBreakdown({required this.byStatus, required this.byRule});

  factory ViolationBreakdown.fromJson(Map<String, dynamic> json) => ViolationBreakdown(
        byStatus: (json['byStatus'] as List<dynamic>? ?? [])
            .map((s) => ViolationStatusCount.fromJson(s as Map<String, dynamic>))
            .toList(),
        byRule: (json['byRule'] as List<dynamic>? ?? [])
            .map((r) => ViolationRuleCount.fromJson(r as Map<String, dynamic>))
            .toList(),
      );
}

class RevenuePoint {
  final DateTime date;
  final double amount;

  const RevenuePoint({required this.date, required this.amount});

  factory RevenuePoint.fromJson(Map<String, dynamic> json) => RevenuePoint(
        date: DateTime.parse(json['date'].toString()),
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
      );
}
