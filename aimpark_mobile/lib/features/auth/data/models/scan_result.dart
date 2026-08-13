/// Why a field is worth the user's attention on the confirmation screen.
///
/// Mirrors the C# `FieldFlag` enum, which the server sends by name.
enum FieldFlag {
  /// Nothing was read. The user has to type it, and the screen should say so
  /// rather than showing an unexplained blank.
  notFound,

  /// Worked out rather than read — the registration expiry calculated from the
  /// plate's renewal digit when the printed date did not survive the photo.
  /// Worth a glance, but nothing to do if it looks right.
  derived;

  static FieldFlag? fromWire(String? value) => switch (value) {
    'NotFound' => FieldFlag.notFound,
    'Derived' => FieldFlag.derived,
    _ => null,
  };
}

/// Whether the plate photographed on the vehicle is the plate the receipt names.
///
/// Mirrors the C# `PlateAgreement` enum. This carries the plate now: nothing is
/// typed, so two independent readings agreeing is the whole of the evidence.
enum PlateAgreement {
  /// One of the two readings is missing, so there was nothing to compare.
  notChecked,

  /// The photo shows the plate the receipt names.
  agreed,

  /// The photo shows a readable plate, and it is a different one.
  differs;

  static PlateAgreement fromWire(String? value) => switch (value) {
    'Agreed' => PlateAgreement.agreed,
    'Differs' => PlateAgreement.differs,
    _ => PlateAgreement.notChecked,
  };
}

/// One document the server could not read, and what to do about it.
class DocumentDiagnosis {
  const DocumentDiagnosis({
    required this.documentType,
    required this.reason,
    required this.message,
  });

  final String documentType;

  /// `NoText`, `Sideways` or `Blurry`.
  final String reason;

  /// Plain-language text written by the server. Shown verbatim — it already
  /// says what is wrong and what to do about it.
  final String message;

  factory DocumentDiagnosis.fromJson(Map<String, dynamic> json) =>
      DocumentDiagnosis(
        documentType: json['documentType'] as String? ?? '',
        reason: json['reason'] as String? ?? '',
        message: json['message'] as String? ?? '',
      );
}

/// Everything the extraction rules pulled out of the four photos.
///
/// Nulls are ordinary, not errors: the user fills them in.
class ExtractedValues {
  const ExtractedValues({
    this.studentNumber,
    this.studentName,
    this.section,
    this.semester,
    this.licenseName,
    this.licenseExpiry,
    this.plateNumber,
    this.registrationExpiry,
    this.platePhotoNumber,
    this.plateAgreement = PlateAgreement.notChecked,
    this.flags = const {},
  });

  final String? studentNumber;
  final String? studentName;
  final String? section;
  final String? semester;

  final String? licenseName;
  final DateTime? licenseExpiry;

  final String? plateNumber;
  final DateTime? registrationExpiry;

  /// What the photo of the physical plate read. Not editable — it is evidence
  /// for the reviewer, not a value the user is asked to agree to.
  final String? platePhotoNumber;

  /// Whether [platePhotoNumber] agrees with [plateNumber].
  final PlateAgreement plateAgreement;

  /// Field name to why it needs attention.
  final Map<String, FieldFlag> flags;

  FieldFlag? flagFor(String field) => flags[field];

  factory ExtractedValues.fromJson(Map<String, dynamic> json) {
    final flags = <String, FieldFlag>{};
    for (final entry in (json['fieldsToCheck'] as List<dynamic>? ?? [])) {
      final map = entry as Map<String, dynamic>;
      final flag = FieldFlag.fromWire(map['reason'] as String?);
      final field = map['field'] as String?;
      if (flag != null && field != null) flags[field] = flag;
    }

    return ExtractedValues(
      studentNumber: json['studentNumber'] as String?,
      studentName: json['studentName'] as String?,
      section: json['section'] as String?,
      semester: json['semester'] as String?,
      licenseName: json['licenseName'] as String?,
      licenseExpiry: _date(json['licenseExpiry']),
      plateNumber: json['plateNumber'] as String?,
      registrationExpiry: _date(json['registrationExpiry']),
      platePhotoNumber: json['platePhotoNumber'] as String?,
      plateAgreement: PlateAgreement.fromWire(json['plateAgreement'] as String?),
      flags: flags,
    );
  }

  static DateTime? _date(dynamic value) =>
      value is String ? DateTime.tryParse(value) : null;
}

/// The server's answer to a scan: what it read, and whether that is good enough
/// to move on.
class ScanResult {
  const ScanResult({
    required this.verificationId,
    required this.triesLeft,
    required this.canContinue,
    required this.diagnostics,
    required this.extracted,
  });

  final String verificationId;

  /// Scans left before the flow stops offering retakes. Some documents simply
  /// cannot be read, and no number of retakes fixes that.
  final int triesLeft;

  /// False only while a retake would still help and attempts remain.
  final bool canContinue;

  final List<DocumentDiagnosis> diagnostics;
  final ExtractedValues extracted;

  factory ScanResult.fromJson(Map<String, dynamic> json) => ScanResult(
    verificationId: json['verificationId'] as String? ?? '',
    triesLeft: json['triesLeft'] as int? ?? 0,
    canContinue: json['canContinue'] as bool? ?? false,
    diagnostics: [
      for (final d in (json['diagnostics'] as List<dynamic>? ?? []))
        DocumentDiagnosis.fromJson(d as Map<String, dynamic>),
    ],
    extracted: ExtractedValues.fromJson(
      json['extracted'] as Map<String, dynamic>? ?? const {},
    ),
  );
}
