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

  /// Bays whose sensor has stopped reading.
  final int noSignalSlots;

  /// Bays a car could use. Free plus occupied add up to this, always.
  final int usableBays;
  final int freeFourWheel;
  final int usableFourWheel;
  final int freeMotorcycle;
  final int usableMotorcycle;
  final int sessionsToday;
  final int sessionsInPeriod;

  /// Everything paid in the period: fees plus fines.
  final double revenueCollected;
  final double feesCollected;
  final double finesCollected;

  /// Owed right now, whatever the period.
  final double revenuePending;
  final double feesPending;
  final double finesPending;
  final int violationsIssued;
  final int openIncidents;

  /// Refusals today that need a look: an unknown card or a plate mismatch.
  final int seriousDenialsToday;

  const ReportsSummary({
    required this.totalUsers,
    required this.activeUsers,
    required this.totalSlots,
    required this.occupiedSlots,
    required this.availableSlots,
    this.outOfServiceSlots = 0,
    this.noSignalSlots = 0,
    this.usableBays = 0,
    this.freeFourWheel = 0,
    this.usableFourWheel = 0,
    this.freeMotorcycle = 0,
    this.usableMotorcycle = 0,
    required this.sessionsToday,
    this.sessionsInPeriod = 0,
    required this.revenueCollected,
    this.feesCollected = 0,
    this.finesCollected = 0,
    required this.revenuePending,
    this.feesPending = 0,
    this.finesPending = 0,
    required this.violationsIssued,
    required this.openIncidents,
    this.seriousDenialsToday = 0,
  });

  /// Bays that could actually take a car right now — the denominator for any
  /// "how full are we" figure. A lot with 10 bays where 8 are broken is at
  /// capacity with 2 cars, not at 20%.
  int get usableSlots =>
      usableBays > 0 ? usableBays : totalSlots - outOfServiceSlots;

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
        noSignalSlots: (json['noSignalSlots'] as num?)?.toInt() ?? 0,
        usableBays: (json['usableSlots'] as num?)?.toInt() ?? 0,
        freeFourWheel: (json['freeFourWheel'] as num?)?.toInt() ?? 0,
        usableFourWheel: (json['usableFourWheel'] as num?)?.toInt() ?? 0,
        freeMotorcycle: (json['freeMotorcycle'] as num?)?.toInt() ?? 0,
        usableMotorcycle: (json['usableMotorcycle'] as num?)?.toInt() ?? 0,
        sessionsToday: (json['sessionsToday'] as num?)?.toInt() ?? 0,
        sessionsInPeriod: (json['sessionsInPeriod'] as num?)?.toInt() ?? 0,
        revenueCollected: (json['revenueCollected'] as num?)?.toDouble() ?? 0,
        feesCollected: (json['feesCollected'] as num?)?.toDouble() ?? 0,
        finesCollected: (json['finesCollected'] as num?)?.toDouble() ?? 0,
        revenuePending: (json['revenuePending'] as num?)?.toDouble() ?? 0,
        feesPending: (json['feesPending'] as num?)?.toDouble() ?? 0,
        finesPending: (json['finesPending'] as num?)?.toDouble() ?? 0,
        violationsIssued: (json['violationsIssued'] as num?)?.toInt() ?? 0,
        openIncidents: (json['openIncidents'] as num?)?.toInt() ?? 0,
        seriousDenialsToday:
            (json['seriousDenialsToday'] as num?)?.toInt() ?? 0,
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

/// Vehicles in and out on one day.
///
/// In and out are separate series, not a net figure: 40 in and 40 out is a busy
/// day, 5 in and 5 out is a quiet one, and a single number cannot tell them
/// apart.
class EntryExitPoint {
  final DateTime date;
  final int entries;
  final int exits;
  final int visitorEntries;

  const EntryExitPoint({
    required this.date,
    required this.entries,
    required this.exits,
    required this.visitorEntries,
  });

  factory EntryExitPoint.fromJson(Map<String, dynamic> json) => EntryExitPoint(
        date: DateTime.parse(json['date'].toString()),
        entries: (json['entries'] as num?)?.toInt() ?? 0,
        exits: (json['exits'] as num?)?.toInt() ?? 0,
        visitorEntries: (json['visitorEntries'] as num?)?.toInt() ?? 0,
      );
}

class EntryExitReport {
  final List<EntryExitPoint> points;
  final int totalEntries;
  final int totalExits;
  final int totalVisitorEntries;

  /// Sessions opened in the window with no exit recorded. A few is normal —
  /// cars still parked. A lot means the exit side of the gate is not being used.
  final int stillOpen;

  const EntryExitReport({
    required this.points,
    required this.totalEntries,
    required this.totalExits,
    required this.totalVisitorEntries,
    required this.stillOpen,
  });

  factory EntryExitReport.fromJson(Map<String, dynamic> json) =>
      EntryExitReport(
        points: (json['points'] as List<dynamic>? ?? [])
            .map((p) => EntryExitPoint.fromJson(p as Map<String, dynamic>))
            .toList(),
        totalEntries: (json['totalEntries'] as num?)?.toInt() ?? 0,
        totalExits: (json['totalExits'] as num?)?.toInt() ?? 0,
        totalVisitorEntries: (json['totalVisitorEntries'] as num?)?.toInt() ?? 0,
        stillOpen: (json['stillOpen'] as num?)?.toInt() ?? 0,
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

  /// Fees plus fines.
  final double amount;
  final double fees;
  final double fines;

  const RevenuePoint({
    required this.date,
    required this.amount,
    this.fees = 0,
    this.fines = 0,
  });

  factory RevenuePoint.fromJson(Map<String, dynamic> json) => RevenuePoint(
        date: DateTime.parse(json['date'].toString()),
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        fees: (json['fees'] as num?)?.toDouble() ?? 0,
        fines: (json['fines'] as num?)?.toDouble() ?? 0,
      );
}
