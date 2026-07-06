class RegistrationDetail {
  final String userId;
  final String fullName;
  final String email;
  final String? phoneNumber;
  final String registrationStep;
  final String accountStatus;
  final String verificationStatus;
  final String? rejectionReason;
  final DateTime? rejectedAt;
  final int rejectionCount;
  final DateTime? canReapplyAt;
  final VehicleInfo? vehicle;
  final List<DocumentInfo> documents;

  const RegistrationDetail({
    required this.userId,
    required this.fullName,
    required this.email,
    this.phoneNumber,
    required this.registrationStep,
    required this.accountStatus,
    required this.verificationStatus,
    this.rejectionReason,
    this.rejectedAt,
    required this.rejectionCount,
    this.canReapplyAt,
    this.vehicle,
    required this.documents,
  });

  factory RegistrationDetail.fromJson(Map<String, dynamic> json) =>
      RegistrationDetail(
        userId: json['userId']?.toString() ?? '',
        fullName: json['fullName']?.toString() ?? '',
        email: json['email']?.toString() ?? '',
        phoneNumber: json['phoneNumber']?.toString(),
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
        vehicle: json['vehicle'] != null
            ? VehicleInfo.fromJson(json['vehicle'] as Map<String, dynamic>)
            : null,
        documents: (json['documents'] as List<dynamic>? ?? [])
            .map((d) => DocumentInfo.fromJson(d as Map<String, dynamic>))
            .toList(),
      );
}

class VehicleInfo {
  final String? make;
  final String? model;
  final String? year;
  final String? plateNumber;
  final String? color;

  const VehicleInfo({
    this.make,
    this.model,
    this.year,
    this.plateNumber,
    this.color,
  });

  factory VehicleInfo.fromJson(Map<String, dynamic> json) => VehicleInfo(
        make: json['make']?.toString(),
        model: json['model']?.toString(),
        year: json['year']?.toString(),
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
