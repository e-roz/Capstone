import '../../../../core/ocr/ocr_payload.dart';

/// One document a reviewer has asked the applicant to photograph again, and
/// what was wrong with the last one.
class DocumentRequest {
  const DocumentRequest({required this.type, required this.reason});

  final ScanDocumentType type;

  /// The reviewer's own words, shown on that document's capture screen.
  ///
  /// Carried all the way to the screen rather than summarised on a list page,
  /// because "too dark to read the plate" is only useful while the applicant is
  /// standing in front of the thing they have to photograph again.
  final String reason;

  static DocumentRequest? fromJson(Map<String, dynamic> json) {
    final type = ScanDocumentType.fromWire(json['type'] as String?);
    if (type == null) return null;

    return DocumentRequest(
      type: type,
      reason: (json['reason'] as String?)?.trim() ?? '',
    );
  }
}

/// What the server says about an account part-way through registration.
class RegistrationStatus {
  const RegistrationStatus({
    required this.registrationStep,
    required this.accountStatus,
    this.documentsToRetake = const [],
  });

  final String registrationStep;
  final String accountStatus;

  /// Empty for an ordinary first submission — the applicant owes all four
  /// documents and nothing in particular.
  final List<DocumentRequest> documentsToRetake;

  bool get hasRetakes => documentsToRetake.isNotEmpty;

  factory RegistrationStatus.fromJson(Map<String, dynamic> json) {
    return RegistrationStatus(
      registrationStep: json['registrationStep']?.toString() ?? '',
      accountStatus: json['accountStatus']?.toString() ?? '',
      documentsToRetake: [
        for (final entry in (json['documentsToRetake'] as List<dynamic>? ?? []))
          ?DocumentRequest.fromJson(entry as Map<String, dynamic>),
      ],
    );
  }
}
