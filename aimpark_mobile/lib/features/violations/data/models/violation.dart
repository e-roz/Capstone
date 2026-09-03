class ViolationSummary {
  const ViolationSummary({
    required this.violationId,
    required this.policyRuleTitle,
    required this.status,
    required this.penaltyAmount,
    required this.suspensionType,
    required this.createdAt,
    this.paymentStatus,
    this.paidAt,
  });

  final String violationId;
  final String policyRuleTitle;
  final String status;
  final double penaltyAmount;
  final String suspensionType;
  final DateTime createdAt;

  /// Settlement state of the penalty: `Pending`, `Paid`, `Waived`, or null when
  /// no transaction was raised. Deliberately not folded into [status], which is
  /// the appeal lifecycle — a violation can be `Upheld` and paid at once.
  final String? paymentStatus;
  final DateTime? paidAt;

  bool get isPaid => paymentStatus?.toLowerCase() == 'paid';

  /// Whether there is anything left for the user to do about this violation.
  ///
  /// Settled covers both ways it can end: the fine was paid, or the violation
  /// itself went away (dismissed, overturned, or the fee waived with it).
  bool get isSettled =>
      isPaid ||
      paymentStatus?.toLowerCase() == 'waived' ||
      const {'dismissed', 'overturned'}.contains(status.toLowerCase());

  /// What the badge should read. The payment outranks the appeal status once
  /// it is settled, because "Paid" is the answer to the question the user is
  /// actually asking when they open this list.
  String get displayStatus => isPaid ? 'Paid' : status;

  factory ViolationSummary.fromJson(Map<String, dynamic> json) {
    return ViolationSummary(
      violationId: json['violationId'] as String,
      policyRuleTitle: json['policyRuleTitle'] as String,
      status: json['status'] as String,
      penaltyAmount: (json['penaltyAmount'] as num).toDouble(),
      suspensionType: json['suspensionType'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
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

  bool get canAppeal => appealStatus == null;

  bool get isPaid => paymentStatus?.toLowerCase() == 'paid';
  bool get isWaived => paymentStatus?.toLowerCase() == 'waived';

  /// Whether the penalty is still owed, and so worth offering a way to pay it.
  bool get isPayable => paymentStatus?.toLowerCase() == 'pending';

  /// See [ViolationSummary.displayStatus].
  String get displayStatus => isPaid ? 'Paid' : status;

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
