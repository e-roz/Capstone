/// Who has used one bay: the answer to "who was in M3?".
class SlotHistory {
  final String slotId;
  final String slotCode;
  final int gate;
  final String? bayType;

  /// The session in the bay right now, if any.
  final SlotSession? current;

  /// Newest first.
  final List<SlotSession> sessions;
  final List<SlotViolation> violations;
  final List<SlotWrongBay> wrongBayFlags;

  /// True when there were more sessions than one call returns.
  final bool truncated;

  const SlotHistory({
    required this.slotId,
    required this.slotCode,
    required this.gate,
    required this.bayType,
    required this.current,
    required this.sessions,
    required this.violations,
    required this.wrongBayFlags,
    required this.truncated,
  });

  factory SlotHistory.fromJson(Map<String, dynamic> json) => SlotHistory(
        slotId: json['slotId']?.toString() ?? '',
        slotCode: json['slotCode']?.toString() ?? '',
        gate: (json['gate'] as num?)?.toInt() ?? 1,
        bayType: json['bayType']?.toString(),
        current: json['current'] == null
            ? null
            : SlotSession.fromJson(json['current'] as Map<String, dynamic>),
        sessions: _list(json['sessions'], SlotSession.fromJson),
        violations: _list(json['violations'], SlotViolation.fromJson),
        wrongBayFlags: _list(json['wrongBayFlags'], SlotWrongBay.fromJson),
        truncated: json['truncated'] == true,
      );
}

List<T> _list<T>(Object? raw, T Function(Map<String, dynamic>) parse) => [
      for (final item in raw as List<dynamic>? ?? const [])
        parse(item as Map<String, dynamic>),
    ];

class SlotSession {
  final String logId;
  final String? userId;
  final String userName;
  final String? plateNumber;
  final bool isVisitor;
  final DateTime entryTime;
  final DateTime? exitTime;

  /// When the driver confirmed this bay in the app. Null means the bay is only
  /// the one the gate suggested, which is not proof of where they parked.
  final DateTime? confirmedAt;

  const SlotSession({
    required this.logId,
    required this.userId,
    required this.userName,
    required this.plateNumber,
    required this.isVisitor,
    required this.entryTime,
    required this.exitTime,
    required this.confirmedAt,
  });

  bool get isConfirmed => confirmedAt != null;
  bool get isInside => exitTime == null;

  factory SlotSession.fromJson(Map<String, dynamic> json) => SlotSession(
        logId: json['logId']?.toString() ?? '',
        userId: json['userId']?.toString(),
        userName: json['userName']?.toString() ?? 'Unknown',
        plateNumber: json['plateNumber']?.toString(),
        isVisitor: json['isVisitor'] == true,
        entryTime: DateTime.parse(json['entryTime'].toString()),
        exitTime: json['exitTime'] == null
            ? null
            : DateTime.parse(json['exitTime'].toString()),
        confirmedAt: json['confirmedAt'] == null
            ? null
            : DateTime.parse(json['confirmedAt'].toString()),
      );
}

class SlotViolation {
  final String violationId;
  final String userName;
  final String ruleTitle;
  final String status;
  final double penaltyAmount;
  final DateTime createdAt;

  const SlotViolation({
    required this.violationId,
    required this.userName,
    required this.ruleTitle,
    required this.status,
    required this.penaltyAmount,
    required this.createdAt,
  });

  factory SlotViolation.fromJson(Map<String, dynamic> json) => SlotViolation(
        violationId: json['violationId']?.toString() ?? '',
        userName: json['userName']?.toString() ?? '',
        ruleTitle: json['ruleTitle']?.toString() ?? '',
        status: json['status']?.toString() ?? '',
        penaltyAmount: (json['penaltyAmount'] as num?)?.toDouble() ?? 0,
        createdAt: DateTime.parse(json['createdAt'].toString()),
      );
}

class SlotWrongBay {
  final String flagId;
  final String status;
  final DateTime detectedAt;

  const SlotWrongBay({
    required this.flagId,
    required this.status,
    required this.detectedAt,
  });

  factory SlotWrongBay.fromJson(Map<String, dynamic> json) => SlotWrongBay(
        flagId: json['flagId']?.toString() ?? '',
        status: json['status']?.toString() ?? '',
        detectedAt: DateTime.parse(json['detectedAt'].toString()),
      );
}
