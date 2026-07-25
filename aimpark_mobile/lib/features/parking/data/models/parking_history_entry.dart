class ParkingHistoryEntry {
  const ParkingHistoryEntry({
    required this.logId,
    required this.entryTime,
    this.slotCode,
    this.exitTime,
  });

  final String logId;
  final String? slotCode;
  final DateTime entryTime;
  final DateTime? exitTime;

  bool get isOpen => exitTime == null;

  Duration get duration => (exitTime ?? DateTime.now()).difference(entryTime);

  factory ParkingHistoryEntry.fromJson(Map<String, dynamic> json) {
    return ParkingHistoryEntry(
      logId: json['logId'] as String,
      slotCode: json['slotCode'] as String?,
      entryTime: DateTime.parse(json['entryTime'] as String),
      exitTime: json['exitTime'] == null ? null : DateTime.parse(json['exitTime'] as String),
    );
  }
}

class ParkingHistoryResult {
  const ParkingHistoryResult({required this.logs, required this.totalCount});

  final List<ParkingHistoryEntry> logs;
  final int totalCount;

  /// The most recent open log (no exit time yet), if the user is currently parked.
  ParkingHistoryEntry? get currentlyParked {
    for (final log in logs) {
      if (log.isOpen) return log;
    }
    return null;
  }

  /// Consecutive-day streak, counting back from today, of at least one log
  /// per calendar day. Derived client-side — there's no Streak entity in
  /// the backend.
  int get streakDays {
    final days = logs.map((l) => DateTime(l.entryTime.year, l.entryTime.month, l.entryTime.day)).toSet();
    var streak = 0;
    var cursor = DateTime.now();
    cursor = DateTime(cursor.year, cursor.month, cursor.day);
    while (days.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  factory ParkingHistoryResult.fromJson(Map<String, dynamic> json) {
    return ParkingHistoryResult(
      logs: (json['logs'] as List<dynamic>)
          .map((e) => ParkingHistoryEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalCount: json['totalCount'] as int,
    );
  }
}
