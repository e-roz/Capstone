/// What the user detail page shows before any tab is opened: the numbers on the
/// tab labels and the overview cards.
class UserHistorySummary {
  final int sessions;
  final int violations;
  final int incidentsFiled;
  final int incidentsPossible;
  final int taps;
  final double owed;
  final double paidThisYear;
  final bool isInside;
  final String? insideSlotCode;
  final DateTime? insideSince;

  const UserHistorySummary({
    required this.sessions,
    required this.violations,
    required this.incidentsFiled,
    required this.incidentsPossible,
    required this.taps,
    required this.owed,
    required this.paidThisYear,
    required this.isInside,
    required this.insideSlotCode,
    required this.insideSince,
  });

  int get incidents => incidentsFiled + incidentsPossible;

  factory UserHistorySummary.fromJson(Map<String, dynamic> json) =>
      UserHistorySummary(
        sessions: (json['sessions'] as num?)?.toInt() ?? 0,
        violations: (json['violations'] as num?)?.toInt() ?? 0,
        incidentsFiled: (json['incidentsFiled'] as num?)?.toInt() ?? 0,
        incidentsPossible: (json['incidentsPossible'] as num?)?.toInt() ?? 0,
        taps: (json['taps'] as num?)?.toInt() ?? 0,
        owed: (json['owed'] as num?)?.toDouble() ?? 0,
        paidThisYear: (json['paidThisYear'] as num?)?.toDouble() ?? 0,
        isInside: json['isInside'] == true,
        insideSlotCode: json['insideSlotCode']?.toString(),
        insideSince: json['insideSince'] == null
            ? null
            : DateTime.parse(json['insideSince'].toString()),
      );
}

/// One page of a list on a tab.
class HistoryPage<T> {
  final List<T> items;
  final int total;
  final int page;
  final int pageSize;

  const HistoryPage({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  factory HistoryPage.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) read,
  ) =>
      HistoryPage(
        items: [
          for (final e in json['items'] as List<dynamic>? ?? const [])
            read(e as Map<String, dynamic>),
        ],
        total: (json['total'] as num?)?.toInt() ?? 0,
        page: (json['page'] as num?)?.toInt() ?? 1,
        pageSize: (json['pageSize'] as num?)?.toInt() ?? 20,
      );
}

class UserSessionItem {
  final String id;
  final DateTime entryTime;
  final DateTime? exitTime;
  final int? gate;
  final String? slotCode;

  /// False means the bay is only the one the gate suggested.
  final bool slotConfirmed;
  final String? plate;
  final bool? plateMatched;

  const UserSessionItem({
    required this.id,
    required this.entryTime,
    required this.exitTime,
    required this.gate,
    required this.slotCode,
    required this.slotConfirmed,
    required this.plate,
    required this.plateMatched,
  });

  factory UserSessionItem.fromJson(Map<String, dynamic> json) => UserSessionItem(
        id: json['id']?.toString() ?? '',
        entryTime: DateTime.parse(json['entryTime'].toString()),
        exitTime: json['exitTime'] == null
            ? null
            : DateTime.parse(json['exitTime'].toString()),
        gate: (json['gate'] as num?)?.toInt(),
        slotCode: json['slotCode']?.toString(),
        slotConfirmed: json['slotConfirmed'] == true,
        plate: json['plate']?.toString(),
        plateMatched: json['plateMatched'] as bool?,
      );
}

class UserViolationItem {
  final String id;
  final String ruleTitle;
  final String status;
  final double penaltyAmount;
  final DateTime createdAt;
  final String? slotCode;
  final DateTime? sessionEntry;

  const UserViolationItem({
    required this.id,
    required this.ruleTitle,
    required this.status,
    required this.penaltyAmount,
    required this.createdAt,
    required this.slotCode,
    required this.sessionEntry,
  });

  factory UserViolationItem.fromJson(Map<String, dynamic> json) =>
      UserViolationItem(
        id: json['id']?.toString() ?? '',
        ruleTitle: json['ruleTitle']?.toString() ?? '',
        status: json['status']?.toString() ?? '',
        penaltyAmount: (json['penaltyAmount'] as num?)?.toDouble() ?? 0,
        createdAt: DateTime.parse(json['createdAt'].toString()),
        slotCode: json['slotCode']?.toString(),
        sessionEntry: json['sessionEntry'] == null
            ? null
            : DateTime.parse(json['sessionEntry'].toString()),
      );
}

class UserIncidentItem {
  final String id;
  final String category;
  final String status;
  final DateTime createdAt;
  final String? location;
  final String? slotCode;

  /// For a possible one: when this person was in that bay.
  final DateTime? involvedEntry;
  final DateTime? involvedExit;
  final bool involvedConfirmed;

  const UserIncidentItem({
    required this.id,
    required this.category,
    required this.status,
    required this.createdAt,
    required this.location,
    required this.slotCode,
    required this.involvedEntry,
    required this.involvedExit,
    required this.involvedConfirmed,
  });

  factory UserIncidentItem.fromJson(Map<String, dynamic> json) =>
      UserIncidentItem(
        id: json['id']?.toString() ?? '',
        category: json['category']?.toString() ?? '',
        status: json['status']?.toString() ?? '',
        createdAt: DateTime.parse(json['createdAt'].toString()),
        location: json['location']?.toString(),
        slotCode: json['slotCode']?.toString(),
        involvedEntry: json['involvedEntry'] == null
            ? null
            : DateTime.parse(json['involvedEntry'].toString()),
        involvedExit: json['involvedExit'] == null
            ? null
            : DateTime.parse(json['involvedExit'].toString()),
        involvedConfirmed: json['involvedConfirmed'] == true,
      );
}

class UserIncidents {
  final List<UserIncidentItem> filed;
  final List<UserIncidentItem> possiblyInvolved;

  const UserIncidents({required this.filed, required this.possiblyInvolved});

  factory UserIncidents.fromJson(Map<String, dynamic> json) => UserIncidents(
        filed: [
          for (final e in json['filed'] as List<dynamic>? ?? const [])
            UserIncidentItem.fromJson(e as Map<String, dynamic>),
        ],
        possiblyInvolved: [
          for (final e in json['possiblyInvolved'] as List<dynamic>? ?? const [])
            UserIncidentItem.fromJson(e as Map<String, dynamic>),
        ],
      );
}

class UserPaymentItem {
  final String id;
  final DateTime createdAt;
  final DateTime? paidAt;
  final String purpose;
  final double amount;
  final String status;

  const UserPaymentItem({
    required this.id,
    required this.createdAt,
    required this.paidAt,
    required this.purpose,
    required this.amount,
    required this.status,
  });

  factory UserPaymentItem.fromJson(Map<String, dynamic> json) => UserPaymentItem(
        id: json['id']?.toString() ?? '',
        createdAt: DateTime.parse(json['createdAt'].toString()),
        paidAt: json['paidAt'] == null
            ? null
            : DateTime.parse(json['paidAt'].toString()),
        purpose: json['for']?.toString() ?? '',
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        status: json['status']?.toString() ?? '',
      );
}
