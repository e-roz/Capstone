class ParkingHistoryEntry {
  const ParkingHistoryEntry({
    required this.logId,
    required this.entryTime,
    this.slotCode,
    this.exitTime,
    this.paymentId,
    this.alprPlateNumber,
    this.vehicleId,
  });

  final String logId;
  final String? slotCode;
  final DateTime entryTime;
  final DateTime? exitTime;

  /// The fee raised for this session. Null while the session is still open —
  /// the transaction is only created on exit.
  final String? paymentId;

  /// The ALPR-confirmed plate for this session. Null for a manually logged
  /// entry — never a mismatched plate, since a mismatch is refused at the
  /// gate and never becomes a log at all.
  final String? alprPlateNumber;

  /// Which of the signed-in user's own vehicles this session is attributed
  /// to, worked out server-side from [alprPlateNumber]. Null when it can't
  /// be determined (no plate and more than one vehicle on the account, or a
  /// plate that no longer matches any vehicle on file).
  final String? vehicleId;

  bool get isOpen => exitTime == null;

  Duration get duration => (exitTime ?? DateTime.now()).difference(entryTime);

  factory ParkingHistoryEntry.fromJson(Map<String, dynamic> json) {
    return ParkingHistoryEntry(
      logId: json['logId'] as String,
      slotCode: json['slotCode'] as String?,
      entryTime: DateTime.parse(json['entryTime'] as String),
      exitTime: json['exitTime'] == null ? null : DateTime.parse(json['exitTime'] as String),
      paymentId: json['paymentId'] as String?,
      alprPlateNumber: json['alprPlateNumber'] as String?,
      vehicleId: json['vehicleId'] as String?,
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
