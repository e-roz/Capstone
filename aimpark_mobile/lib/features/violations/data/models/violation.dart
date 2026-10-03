/// A violation status as the user should read it — "Pending Appeal", not
/// "PendingAppeal". `Appealed` means the user won their appeal.
String violationStatusLabel(String status) => switch (status.toLowerCase()) {
      'pendingappeal' => 'Pending Appeal',
      _ => status,
    };

/// How long is left to appeal, in words: "3 days left", "1 day left",
/// "less than a day left", or "ended".
String appealTimeLeft(DateTime deadline, {DateTime? now}) {
  final remaining = deadline.difference(now ?? DateTime.now());
  if (remaining <= Duration.zero) return 'ended';
  if (remaining < const Duration(days: 1)) return 'less than a day left';
  final days = (remaining.inHours / 24).ceil();
  return '$days ${days == 1 ? 'day' : 'days'} left';
}

class ViolationSummary {
  const ViolationSummary({
    required this.violationId,
    required this.policyRuleTitle,
    required this.status,
    required this.penaltyAmount,
    required this.suspensionType,
    required this.createdAt,
    this.appealDeadline,
    this.paymentStatus,
    this.paidAt,
  });

  final String violationId;
  final String policyRuleTitle;
  final String status;
  final double penaltyAmount;
  final String suspensionType;
  final DateTime createdAt;

  /// Last moment the user can appeal. After it the violation becomes final.
  final DateTime? appealDeadline;

  /// Issued, not appealed yet, and the deadline has not passed.
  bool get canAppeal =>
      status.toLowerCase() == 'issued' &&
      (appealDeadline == null || DateTime.now().isBefore(appealDeadline!));

  /// Settlement state of the penalty: `Pending`, `Paid`, `Waived`, or null when
  /// no transaction was raised. Deliberately not folded into [status], which is
  /// the appeal lifecycle — a violation can be `Accountable` and paid at once.
  final String? paymentStatus;
  final DateTime? paidAt;

  bool get isPaid => paymentStatus?.toLowerCase() == 'paid';

  /// Whether there is anything left for the user to do about this violation.
  ///
  /// Settled covers both ways it can end: the fine was paid, or the violation
  /// itself went away (dismissed, appeal won, or the fee waived with it).
  bool get isSettled =>
      isPaid ||
      paymentStatus?.toLowerCase() == 'waived' ||
      const {'dismissed', 'appealed'}.contains(status.toLowerCase());

  /// What the badge should read. The payment outranks the appeal status once
  /// it is settled, because "Paid" is the answer to the question the user is
  /// actually asking when they open this list.
  String get displayStatus => isPaid ? 'Paid' : violationStatusLabel(status);

  factory ViolationSummary.fromJson(Map<String, dynamic> json) {
    return ViolationSummary(
      violationId: json['violationId'] as String,
      policyRuleTitle: json['policyRuleTitle'] as String,
      status: json['status'] as String,
      penaltyAmount: (json['penaltyAmount'] as num).toDouble(),
      suspensionType: json['suspensionType'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      appealDeadline: json['appealDeadline'] == null
          ? null
          : DateTime.parse(json['appealDeadline'] as String).toLocal(),
      paymentStatus: json['paymentStatus'] as String?,
      paidAt: json['paidAt'] == null
          ? null
          : DateTime.parse(json['paidAt'] as String),
    );
  }
}

class ViolationDetail {
  const ViolationDetail({
    required this.violationId,
    required this.policyRuleTitle,
    required this.description,
    required this.penaltyAmount,
    required this.suspensionType,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.appealDeadline,
    this.suspensionDays,
    this.paymentStatus,
    this.paidAt,
    this.amountDue,
    this.paymentDueAt,
    this.paymentId,
    this.appealStatus,
    this.appealReasonText,
    this.appealAdminNotes,
    this.appealDecidedAt,
    this.appealEvidenceUrls = const [],
  });

  final String violationId;
  final String policyRuleTitle;
  final String description;
  final double penaltyAmount;
  final String suspensionType;
  final int? suspensionDays;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Last moment the user can appeal. After it the violation becomes final
  /// (Accountable) and the fine is charged.
  final DateTime? appealDeadline;

  /// See [ViolationSummary.paymentStatus].
  final String? paymentStatus;
  final DateTime? paidAt;
  final double? amountDue;
  final DateTime? paymentDueAt;

  /// The transaction to open when the user taps through to settle this.
  final String? paymentId;

  final String? appealStatus;
  final String? appealReasonText;
  final String? appealAdminNotes;
  final DateTime? appealDecidedAt;
  final List<String> appealEvidenceUrls;

  /// Only an Issued violation with no appeal yet, before the deadline.
  bool get canAppeal =>
      appealStatus == null &&
      status.toLowerCase() == 'issued' &&
      (appealDeadline == null || DateTime.now().isBefore(appealDeadline!));

  bool get isPaid => paymentStatus?.toLowerCase() == 'paid';
  bool get isWaived => paymentStatus?.toLowerCase() == 'waived';

  /// Whether the penalty is still owed, and so worth offering a way to pay it.
  bool get isPayable => paymentStatus?.toLowerCase() == 'pending';

  /// See [ViolationSummary.displayStatus].
  String get displayStatus => isPaid ? 'Paid' : violationStatusLabel(status);

  factory ViolationDetail.fromJson(Map<String, dynamic> json) {
    return ViolationDetail(
      violationId: json['violationId'] as String,
      policyRuleTitle: json['policyRuleTitle'] as String,
      description: json['description'] as String,
      penaltyAmount: (json['penaltyAmount'] as num).toDouble(),
      suspensionType: json['suspensionType'] as String,
      suspensionDays: json['suspensionDays'] as int?,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      appealDeadline: json['appealDeadline'] == null
          ? null
          : DateTime.parse(json['appealDeadline'] as String).toLocal(),
      paymentStatus: json['paymentStatus'] as String?,
      paidAt: json['paidAt'] == null
          ? null
          : DateTime.parse(json['paidAt'] as String),
      amountDue: (json['amountDue'] as num?)?.toDouble(),
      paymentDueAt: json['paymentDueAt'] == null
          ? null
          : DateTime.parse(json['paymentDueAt'] as String),
      paymentId: json['paymentId'] as String?,
      appealStatus: json['appealStatus'] as String?,
      appealReasonText: json['appealReasonText'] as String?,
      appealAdminNotes: json['appealAdminNotes'] as String?,
      appealDecidedAt: json['appealDecidedAt'] == null
          ? null
          : DateTime.parse(json['appealDecidedAt'] as String),
      appealEvidenceUrls: (json['appealEvidenceUrls'] as List<dynamic>? ?? [])
          .map((e) => e as String)
          .toList(),
    );
  }
}

class ViolationListResult {
  const ViolationListResult({required this.violations, required this.totalCount});

  final List<ViolationSummary> violations;
  final int totalCount;

  factory ViolationListResult.fromJson(Map<String, dynamic> json) {
    return ViolationListResult(
      violations: (json['violations'] as List<dynamic>)
          .map((e) => ViolationSummary.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalCount: json['totalCount'] as int,
    );
  }
}
