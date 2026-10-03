/// One of the cards kept at the guard post for lending to visitors, and
/// where it is right now. See `AimPark.API.Entities.VisitorCard`.
class VisitorCard {
  final String rfidTagId;

  /// What is written on the card, e.g. "V1".
  final String label;

  /// Active or Blocked.
  final String state;
  final String? note;

  /// InDrawer, OutWithVisitor, NotYetReturned or Blocked.
  final String whereabouts;

  final String? lastPassId;
  final String? lastVisitorName;
  final String? lastPlateNumber;
  final DateTime? lastIssuedAt;
  final DateTime? lastReturnedAt;

  /// A card that was never lent can be removed; one with history is blocked.
  final int timesLent;

  const VisitorCard({
    required this.rfidTagId,
    required this.label,
    required this.state,
    required this.note,
    required this.whereabouts,
    required this.lastPassId,
    required this.lastVisitorName,
    required this.lastPlateNumber,
    required this.lastIssuedAt,
    required this.lastReturnedAt,
    required this.timesLent,
  });

  bool get isBlocked => state == 'Blocked';

  factory VisitorCard.fromJson(Map<String, dynamic> json) => VisitorCard(
        rfidTagId: json['rfidTagId']?.toString() ?? '',
        label: json['label']?.toString() ?? '',
        state: json['state']?.toString() ?? '',
        note: json['note']?.toString(),
        whereabouts: json['whereabouts']?.toString() ?? '',
        lastPassId: json['lastPassId']?.toString(),
        lastVisitorName: json['lastVisitorName']?.toString(),
        lastPlateNumber: json['lastPlateNumber']?.toString(),
        lastIssuedAt: _date(json['lastIssuedAt']),
        lastReturnedAt: _date(json['lastReturnedAt']),
        timesLent: (json['timesLent'] as num?)?.toInt() ?? 0,
      );
}

/// How a card's whereabouts reads to a person.
String visitorCardWhereaboutsLabel(String whereabouts) => switch (whereabouts) {
      'InDrawer' => 'In the drawer',
      'OutWithVisitor' => 'Out with visitor',
      'NotYetReturned' => 'Not yet returned',
      'Blocked' => 'Blocked',
      _ => whereabouts,
    };

/// An idle visitor card tapped at a gate. The barrier stays shut until a guard
/// says who is in the car.
class PendingVisitorRegistration {
  final String id;
  final String rfidTagId;
  final String cardLabel;
  final int gate;
  final DateTime tappedAt;

  /// What the gate camera read around the tap, to prefill the plate.
  final String? cameraPlate;

  const PendingVisitorRegistration({
    required this.id,
    required this.rfidTagId,
    required this.cardLabel,
    required this.gate,
    required this.tappedAt,
    required this.cameraPlate,
  });

  factory PendingVisitorRegistration.fromJson(Map<String, dynamic> json) =>
      PendingVisitorRegistration(
        id: json['id']?.toString() ?? '',
        rfidTagId: json['rfidTagId']?.toString() ?? '',
        cardLabel: json['cardLabel']?.toString() ?? '',
        gate: (json['gate'] as num?)?.toInt() ?? 0,
        tappedAt: DateTime.parse(json['tappedAt'].toString()),
        cameraPlate: json['cameraPlate']?.toString(),
      );
}

DateTime? _date(Object? value) =>
    value == null ? null : DateTime.parse(value.toString());
