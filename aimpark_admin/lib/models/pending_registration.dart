import 'registration_checks.dart';

/// One line in the review queue.
///
/// Carries counts rather than the checks themselves: the list only needs to say
/// which applications deserve time, and the detail screen holds the evidence.
class PendingRegistration {
  final String userId;
  final String fullName;
  final String email;

  /// `Student`, `Faculty` or `Staff`.
  final String affiliation;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// `Clear`, `LookCloser`, `Unreadable`, or `None` when nothing was submitted.
  final String checksVerdict;

  /// Ready to render — "2 need attention", "All 6 passed".
  final String checksSummary;

  final int checksNeedingAttention;
  final int checksUnreadable;

  /// Whole days since submission. Nothing else on the screen says this.
  final int waitingDays;

  /// The most serious flagged finding in words ("Name mismatch"), or null
  /// when nothing was flagged. Same wording as the review screen's first row.
  final String? topFinding;

  /// Tone of [topFinding]. Null alongside it.
  final FindingSeverity? topFindingSeverity;

  /// Flagged findings, [topFinding] included.
  final int flaggedCount;

  /// An e-bike application, which waits for an in-person inspection rather
  /// than a document review.
  final bool isEBike;

  /// When they should have come to the office by.
  final DateTime? eBikeInspectionDeadline;

  /// Approved and Rejected lists only. When the applicant was decided on.
  final DateTime? decidedAt;

  /// The admin who decided. Null for an automatic approval.
  final String? decidedByName;

  /// Rejected list only.
  final String? rejectionReason;

  /// Rejected list only: how many times this applicant has been rejected.
  final int timesRejected;

  const PendingRegistration({
    required this.userId,
    required this.fullName,
    required this.email,
    this.affiliation = 'Student',
    required this.createdAt,
    required this.updatedAt,
    required this.checksVerdict,
    required this.checksSummary,
    required this.checksNeedingAttention,
    required this.checksUnreadable,
    required this.waitingDays,
    this.topFinding,
    this.topFindingSeverity,
    this.flaggedCount = 0,
    this.isEBike = false,
    this.eBikeInspectionDeadline,
    this.decidedAt,
    this.decidedByName,
    this.rejectionReason,
    this.timesRejected = 0,
  });

  /// Nothing to review yet. Sorted to the bottom whichever way the column runs.
  bool get hasNoDocuments => checksVerdict == 'None';

  /// Worst first, so sorting the column puts the applications that need a human
  /// at the top rather than sorting them alphabetically by their summary text.
  /// Red before amber before unreadable before clean; more flags break a tie.
  int get concernRank {
    final tone = switch (topFindingSeverity) {
      FindingSeverity.danger => 4,
      FindingSeverity.warning => 3,
      FindingSeverity.neutral => 2,
      _ => hasNoDocuments ? 0 : 1,
    };
    return tone * 100 + flaggedCount;
  }

  factory PendingRegistration.fromJson(Map<String, dynamic> json) =>
      PendingRegistration(
        userId: json['userId']?.toString() ?? '',
        fullName: json['fullName']?.toString() ?? '',
        email: json['email']?.toString() ?? '',
        affiliation: json['affiliation']?.toString() ?? 'Student',
        createdAt: DateTime.parse(json['createdAt'].toString()),
        updatedAt: DateTime.parse(json['updatedAt'].toString()),
        checksVerdict: json['checksVerdict']?.toString() ?? 'None',
        checksSummary: json['checksSummary']?.toString() ?? '',
        checksNeedingAttention:
            (json['checksNeedingAttention'] as num?)?.toInt() ?? 0,
        checksUnreadable: (json['checksUnreadable'] as num?)?.toInt() ?? 0,
        waitingDays: (json['waitingDays'] as num?)?.toInt() ?? 0,
        topFinding: json['topFinding']?.toString(),
        topFindingSeverity: json['topFindingSeverity'] == null
            ? null
            : findingSeverity(json['topFindingSeverity'].toString()),
        flaggedCount: (json['flaggedCount'] as num?)?.toInt() ?? 0,
        isEBike: (json['isEBike'] as bool?) ?? false,
        eBikeInspectionDeadline: json['eBikeInspectionDeadline'] == null
            ? null
            : DateTime.tryParse(json['eBikeInspectionDeadline'].toString()),
        decidedAt: json['decidedAt'] == null
            ? null
            : DateTime.tryParse(json['decidedAt'].toString()),
        decidedByName: json['decidedByName']?.toString(),
        rejectionReason: json['rejectionReason']?.toString(),
        timesRejected: (json['timesRejected'] as num?)?.toInt() ?? 0,
      );
}
