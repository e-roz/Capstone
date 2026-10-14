/// One tap at a gate reader, or one manual open, on the guard's live log.
class GateTapEvent {
  final String id;
  final DateTime at;
  final int gate;
  final String? readerName;

  /// IN, OUT, or "-" when the tap never got as far as a direction.
  final String direction;
  final bool opened;
  final String message;
  final String? rfidTagId;
  final String? personName;

  /// Driver, Visitor, Unknown, or Manual.
  final String personKind;
  final String? cameraPlate;
  final String? registeredPlates;

  /// Null when there was nothing to compare.
  final bool? plateMatches;
  final bool hasPhoto;

  /// A refusal that needs a look: a card nobody holds, or a plate that is not
  /// the holder's. Decided by the API so the rows and the summary agree.
  final bool serious;

  /// The bay an accepted entry was recommended. Only the live log sends it.
  final String? recommendedSlot;

  /// 'Car' or 'Motorcycle' for an accepted entry. Only the live log sends it.
  final String? vehicleType;

  const GateTapEvent({
    required this.id,
    required this.at,
    required this.gate,
    required this.readerName,
    required this.direction,
    required this.opened,
    required this.message,
    required this.rfidTagId,
    required this.personName,
    required this.personKind,
    required this.cameraPlate,
    required this.registeredPlates,
    required this.plateMatches,
    required this.hasPhoto,
    required this.serious,
    this.recommendedSlot,
    this.vehicleType,
  });

  bool get isManual => personKind == 'Manual';
  bool get isVisitor => personKind == 'Visitor';
  bool get isDriver => personKind == 'Driver';
  bool get isUnknownCard => personKind == 'Unknown';

  /// What happened, in words a guard reads at a glance. "IN" alone read as
  /// "the car is inside" even when the barrier stayed shut.
  String get outcomeLabel => switch ((isManual, opened, direction)) {
    (true, _, _) => 'OPENED BY GUARD',
    (_, true, 'IN') => 'ENTERED',
    (_, true, 'OUT') => 'EXITED',
    (_, true, _) => 'OPENED',
    (_, false, 'IN') => 'ENTRY DENIED',
    (_, false, 'OUT') => 'EXIT DENIED',
    _ => 'DENIED',
  };

  /// What to call whoever tapped, for a row title.
  String get who => switch (personKind) {
    'Manual' => 'Opened by guard',
    'Unknown' => 'Unregistered card',
    _ => personName ?? 'Unregistered card',
  };

  factory GateTapEvent.fromJson(Map<String, dynamic> json) => GateTapEvent(
    id: json['id'] as String,
    at: DateTime.parse(json['at'] as String),
    gate: (json['gate'] as num?)?.toInt() ?? 0,
    readerName: json['readerName'] as String?,
    direction: json['direction'] as String? ?? '-',
    opened: json['opened'] as bool? ?? false,
    message: json['message'] as String? ?? '',
    rfidTagId: json['rfidTagId'] as String?,
    personName: json['personName'] as String?,
    personKind: json['personKind'] as String? ?? 'Unknown',
    cameraPlate: json['cameraPlate'] as String?,
    registeredPlates: json['registeredPlates'] as String?,
    plateMatches: json['plateMatches'] as bool?,
    hasPhoto: json['hasPhoto'] as bool? ?? false,
    serious: json['serious'] as bool? ?? false,
    recommendedSlot: json['recommendedSlot'] as String?,
    vehicleType: json['vehicleType'] as String?,
  );
}

/// Counts for the current date, gate and search filters, as the Gate Taps page
/// shows above its table. Refusals are split by whether they need a look.
class GateTapSummary {
  final int entered;
  final int exited;
  final int deniedSerious;
  final int deniedRoutine;
  final int manual;

  const GateTapSummary({
    required this.entered,
    required this.exited,
    required this.deniedSerious,
    required this.deniedRoutine,
    required this.manual,
  });

  factory GateTapSummary.fromJson(Map<String, dynamic> json) => GateTapSummary(
    entered: (json['entered'] as num?)?.toInt() ?? 0,
    exited: (json['exited'] as num?)?.toInt() ?? 0,
    deniedSerious: (json['deniedSerious'] as num?)?.toInt() ?? 0,
    deniedRoutine: (json['deniedRoutine'] as num?)?.toInt() ?? 0,
    manual: (json['manual'] as num?)?.toInt() ?? 0,
  );
}

class GateTapPage {
  final List<GateTapEvent> taps;
  final GateTapSummary summary;
  final int totalCount;
  final int page;
  final int pageSize;

  const GateTapPage({
    required this.taps,
    required this.summary,
    required this.totalCount,
    required this.page,
    required this.pageSize,
  });

  factory GateTapPage.fromJson(Map<String, dynamic> json) => GateTapPage(
    taps: [
      for (final t in json['taps'] as List? ?? const [])
        GateTapEvent.fromJson(t as Map<String, dynamic>),
    ],
    summary: GateTapSummary.fromJson(
      (json['summary'] as Map?)?.cast<String, dynamic>() ?? const {},
    ),
    totalCount: (json['totalCount'] as num?)?.toInt() ?? 0,
    page: (json['page'] as num?)?.toInt() ?? 1,
    pageSize: (json['pageSize'] as num?)?.toInt() ?? 25,
  );
}
