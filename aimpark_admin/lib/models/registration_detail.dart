class RegistrationDetail {
  final String userId;
  final String fullName;
  final String email;
  final String affiliation;
  final String? studentNumber;
  final String? section;
  final DateTime? enrollmentValidUntil;
  final String registrationStep;
  final String accountStatus;
  final String verificationStatus;
  final String? rejectionReason;
  final DateTime? rejectedAt;
  final int rejectionCount;
  final DateTime? canReapplyAt;
  final bool isDeleted;
  final DateTime createdAt;
  final String? rfidTagId;
  final String rfidStatus;
  final DateTime? rfidSuspendedUntil;
  /// Every vehicle on the account — one RFID card can cover several.
  final List<VehicleInfo> vehicles;
  final List<DocumentInfo> documents;

  const RegistrationDetail({
    required this.userId,
    required this.fullName,
    required this.email,
    required this.affiliation,
    this.studentNumber,
    this.section,
    this.enrollmentValidUntil,
    required this.registrationStep,
    required this.accountStatus,
    required this.verificationStatus,
    this.rejectionReason,
    this.rejectedAt,
    required this.rejectionCount,
    this.canReapplyAt,
    required this.isDeleted,
    required this.createdAt,
    this.rfidTagId,
    required this.rfidStatus,
    this.rfidSuspendedUntil,
    required this.vehicles,
    required this.documents,
  });

  factory RegistrationDetail.fromJson(Map<String, dynamic> json) =>
      RegistrationDetail(
        userId: json['userId']?.toString() ?? '',
        fullName: json['fullName']?.toString() ?? '',
        email: json['email']?.toString() ?? '',
        affiliation: json['affiliation']?.toString() ?? 'Student',
        studentNumber: json['studentNumber']?.toString(),
        section: json['section']?.toString(),
        enrollmentValidUntil: json['enrollmentValidUntil'] != null
            ? DateTime.tryParse(json['enrollmentValidUntil'].toString())
            : null,
        registrationStep: json['registrationStep']?.toString() ?? '',
        accountStatus: json['accountStatus']?.toString() ?? '',
        verificationStatus: json['verificationStatus']?.toString() ?? '',
        rejectionReason: json['rejectionReason']?.toString(),
        rejectedAt: json['rejectedAt'] != null
            ? DateTime.tryParse(json['rejectedAt'].toString())
            : null,
        rejectionCount: (json['rejectionCount'] as num?)?.toInt() ?? 0,
        canReapplyAt: json['canReapplyAt'] != null
            ? DateTime.tryParse(json['canReapplyAt'].toString())
            : null,
        isDeleted: (json['isDeleted'] as bool?) ?? false,
        createdAt: DateTime.parse(json['createdAt'].toString()),
        rfidTagId: json['rfidTagId']?.toString(),
        rfidStatus: json['rfidStatus']?.toString() ?? 'Unassigned',
        rfidSuspendedUntil: json['rfidSuspendedUntil'] != null
            ? DateTime.tryParse(json['rfidSuspendedUntil'].toString())
            : null,
        vehicles: (json['vehicles'] as List<dynamic>? ?? [])
            .map((v) => VehicleInfo.fromJson(v as Map<String, dynamic>))
            .toList(),
        documents: (json['documents'] as List<dynamic>? ?? [])
            .map((d) => DocumentInfo.fromJson(d as Map<String, dynamic>))
            .toList(),
      );
}

class VehicleInfo {
  final String? brand;
  final String? model;
  final String? vehicleType;
  final String? plateNumber;
  final String? color;

  const VehicleInfo({
    this.brand,
    this.model,
    this.vehicleType,
    this.plateNumber,
    this.color,
  });

  factory VehicleInfo.fromJson(Map<String, dynamic> json) => VehicleInfo(
        brand: json['brand']?.toString(),
        model: json['model']?.toString(),
        vehicleType: json['vehicleType']?.toString(),
        plateNumber: json['plateNumber']?.toString(),
        color: json['color']?.toString(),
      );
}

class DocumentInfo {
  final String id;
  final String type;
  final String fileName;
  final String filePath;
  final DateTime uploadedAt;

  const DocumentInfo({
    required this.id,
    required this.type,
    required this.fileName,
    required this.filePath,
    required this.uploadedAt,
  });

  factory DocumentInfo.fromJson(Map<String, dynamic> json) => DocumentInfo(
        id: json['id']?.toString() ?? '',
        type: json['type']?.toString() ?? '',
        fileName: json['fileName']?.toString() ?? '',
        filePath: json['filePath']?.toString() ?? '',
        uploadedAt: DateTime.parse(json['uploadedAt'].toString()),
      );
}
