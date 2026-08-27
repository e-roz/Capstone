import '../../../../core/camera/capture_spec.dart';
import '../../../../core/ocr/ocr_payload.dart';
import '../../presentation/providers/registration_provider.dart';

/// One document the registration flow asks for.
///
/// A [CaptureSpec] — how to photograph it — plus the two things only
/// registration cares about: which slot it fills on the server, and what it is
/// for in the applicant's terms.
///
/// Split this way so the capture screen stays document-agnostic. It reads
/// `label`, `instruction` and `aspectRatio` off the base class and never learns
/// that documents exist, which is what lets a plate recogniser reuse it
/// unchanged.
class DocumentSpec extends CaptureSpec {
  const DocumentSpec({
    required this.type,
    required this.purpose,
    required super.label,
    required super.instruction,
    required super.aspectRatio,
  });

  final ScanDocumentType type;

  /// What this document is for, in the applicant's terms.
  ///
  /// Each one answers exactly one question, and someone asked for four
  /// photographs deserves to know which question each is answering — otherwise
  /// the licence and the receipt look like the same demand for paperwork twice.
  final String purpose;

  /// A4-ish, portrait.
  static const raf = DocumentSpec(
    type: ScanDocumentType.raf,
    label: 'Registration form',
    purpose: 'Shows that you are enrolled this term.',
    instruction: 'Lay it flat and fit the whole form inside the frame.',
    aspectRatio: 1 / 1.414,
  );

  static const schoolId = DocumentSpec(
    type: ScanDocumentType.schoolId,
    label: 'School ID',
    purpose: 'Shows that you work at the school.',
    instruction: 'Front of your school ID, filling the frame.',
    aspectRatio: 1.586,
  );

  static const license = DocumentSpec(
    type: ScanDocumentType.license,
    label: "Driver's licence",
    purpose: 'Shows that you may drive, and that you are the same person.',
    instruction: 'Front of your licence, with the expiry date visible.',
    aspectRatio: 1.586,
  );

  static const officialReceipt = DocumentSpec(
    type: ScanDocumentType.officialReceipt,
    label: 'Official receipt',
    purpose:
        'Your plate number is read from here — you will not have to type it.',
    instruction: 'The LTO receipt. Keep the plate number and date in frame.',
    aspectRatio: 1 / 1.414,
  );

  static const platePhoto = DocumentSpec(
    type: ScanDocumentType.platePhoto,
    label: 'Plate photo',
    purpose: 'Checked against the receipt, so the right plate reaches the gate.',
    instruction: 'The plate on the vehicle itself, straight on and close up.',
    aspectRatio: 2.0,
  );

  /// The documents registration asks for, in the order it asks for them.
  ///
  /// Students prove enrolment with a registration form; everyone else brings a
  /// school ID, which is filed but not read.
  static List<DocumentSpec> forAffiliation(Affiliation affiliation) => [
        affiliation == Affiliation.student ? raf : schoolId,
        license,
        officialReceipt,
        platePhoto,
      ];
}
