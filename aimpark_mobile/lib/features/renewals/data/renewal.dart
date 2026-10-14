/// What is being renewed. The wire names are the API's `DocumentType` names.
enum RenewalKind {
  license('License', "Driver's licence"),
  registration('OfficialReceipt', 'Vehicle registration');

  const RenewalKind(this.wireName, this.label);

  final String wireName;
  final String label;

  static RenewalKind? fromWire(String? value) {
    for (final kind in values) {
      if (kind.wireName == value) return kind;
    }
    return null;
  }
}

/// One document to renew: a licence, or the registration of one vehicle.
///
/// Passed to the renewal screens as the route's `extra`, so the plate, which is
/// personal, is not in the address.
class RenewalTarget {
  const RenewalTarget({required this.kind, this.vehicleId, this.plateNumber});

  final RenewalKind kind;

  /// Required for a registration, which belongs to one vehicle.
  final String? vehicleId;
  final String? plateNumber;

  String get title => kind == RenewalKind.license
      ? "Driver's licence"
      : 'Registration · ${plateNumber ?? 'vehicle'}';
}

/// A renewal that is waiting for an admin, or was turned down.
class Renewal {
  const Renewal({
    required this.id,
    required this.kind,
    this.vehicleId,
    this.plateNumber,
    required this.status,
    this.newExpiry,
    this.rejectReason,
  });

  final String id;
  final RenewalKind kind;
  final String? vehicleId;
  final String? plateNumber;

  /// `Pending` or `Rejected`.
  final String status;
  final DateTime? newExpiry;
  final String? rejectReason;

  bool get isPending => status == 'Pending';
  bool get isRejected => status == 'Rejected';

  static Renewal? fromJson(Map<String, dynamic> json) {
    final kind = RenewalKind.fromWire(json['kind']?.toString());
    if (kind == null) return null;

    return Renewal(
      id: json['id']?.toString() ?? '',
      kind: kind,
      vehicleId: json['vehicleId']?.toString(),
      plateNumber: json['plateNumber']?.toString(),
      status: json['status']?.toString() ?? '',
      newExpiry: DateTime.tryParse(json['newExpiry']?.toString() ?? ''),
      rejectReason: json['rejectReason']?.toString(),
    );
  }
}

/// What reading a renewed document returned.
class RenewalScan {
  const RenewalScan({
    required this.renewalId,
    this.extractedExpiry,
    required this.canContinue,
    this.problems = const [],
  });

  final String renewalId;
  final DateTime? extractedExpiry;

  /// False while a retake would still help.
  final bool canContinue;

  /// Plain sentences about what could not be read or did not match.
  final List<String> problems;

  factory RenewalScan.fromJson(Map<String, dynamic> json) => RenewalScan(
        renewalId: json['renewalId']?.toString() ?? '',
        extractedExpiry:
            DateTime.tryParse(json['extractedExpiry']?.toString() ?? ''),
        canContinue: json['canContinue'] as bool? ?? true,
        problems: [
          for (final d in (json['diagnostics'] as List<dynamic>? ?? []))
            if ((d as Map<String, dynamic>)['message'] != null)
              d['message'].toString(),
        ],
      );
}
