class ViolationSummary {
  const ViolationSummary({
    required this.violationId,
    required this.policyRuleTitle,
    required this.status,
    required this.penaltyAmount,
    required this.suspensionType,
    required this.createdAt,
  });

  final String violationId;
  final String policyRuleTitle;
  final String status;
  final double penaltyAmount;
  final String suspensionType;
  final DateTime createdAt;

  factory ViolationSummary.fromJson(Map<String, dynamic> json) {
    return ViolationSummary(
      violationId: json['violationId'] as String,
      policyRuleTitle: json['policyRuleTitle'] as String,
      status: json['status'] as String,
      penaltyAmount: (json['penaltyAmount'] as num).toDouble(),
      suspensionType: json['suspensionType'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
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
    this.appealStatus,
    this.appealReasonText,
    this.appealAdminNotes,
    this.appealDecidedAt,
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
  final String? appealStatus;
  final String? appealReasonText;
  final String? appealAdminNotes;
  final DateTime? appealDecidedAt;

  bool get canAppeal => appealStatus == null;

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
      appealStatus: json['appealStatus'] as String?,
      appealReasonText: json['appealReasonText'] as String?,
      appealAdminNotes: json['appealAdminNotes'] as String?,
      appealDecidedAt: json['appealDecidedAt'] == null
          ? null
          : DateTime.parse(json['appealDecidedAt'] as String),
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
