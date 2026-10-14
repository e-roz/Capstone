/// A licence or a vehicle registration an approved user has renewed and
/// uploaded again, waiting for an admin.
class AdminRenewal {
  const AdminRenewal({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.email,
    required this.kind,
    this.vehicleId,
    this.plateNumber,
    required this.status,
    this.currentExpiry,
    this.extractedExpiry,
    this.newExpiry,
    required this.fileName,
    required this.fileUrl,
    this.rejectReason,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String fullName;
  final String email;

  /// `License` or `OfficialReceipt`.
  final String kind;
  final String? vehicleId;
  final String? plateNumber;
  final String status;

  /// The expiry on file now, before this renewal.
  final DateTime? currentExpiry;

  /// What the phone read off the new document.
  final DateTime? extractedExpiry;

  /// What the user confirmed. This is the date applied on approval.
  final DateTime? newExpiry;

  final String fileName;
  final String fileUrl;
  final String? rejectReason;
  final DateTime createdAt;

  bool get isLicense => kind == 'License';

  String get label => isLicense
      ? "Driver's licence"
      : 'Registration · ${plateNumber ?? 'vehicle'}';

  /// The user changed the date the phone read, so the reviewer should look at
  /// the document rather than trust either value.
  bool get dateWasEdited {
    final read = extractedExpiry;
    final confirmed = newExpiry;
    if (read == null || confirmed == null) return false;
    return DateTime(read.year, read.month, read.day) !=
        DateTime(confirmed.year, confirmed.month, confirmed.day);
  }

  factory AdminRenewal.fromJson(Map<String, dynamic> json) => AdminRenewal(
        id: json['id']?.toString() ?? '',
        userId: json['userId']?.toString() ?? '',
        fullName: json['fullName']?.toString() ?? '',
        email: json['email']?.toString() ?? '',
        kind: json['kind']?.toString() ?? '',
        vehicleId: json['vehicleId']?.toString(),
        plateNumber: json['plateNumber']?.toString(),
        status: json['status']?.toString() ?? '',
        currentExpiry: _date(json['currentExpiry']),
        extractedExpiry: _date(json['extractedExpiry']),
        newExpiry: _date(json['newExpiry']),
        fileName: json['fileName']?.toString() ?? '',
        fileUrl: json['fileUrl']?.toString() ?? '',
        rejectReason: json['rejectReason']?.toString(),
        createdAt: DateTime.parse(json['createdAt'].toString()),
      );
}

DateTime? _date(Object? raw) =>
    raw == null ? null : DateTime.tryParse(raw.toString());
