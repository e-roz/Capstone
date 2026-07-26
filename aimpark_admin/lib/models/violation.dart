class PolicyRule {
  final String ruleId;
  final String title;
  final String description;
  final double defaultPenaltyAmount;
  final String defaultSuspensionType;
  final int? defaultSuspensionDays;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PolicyRule({
    required this.ruleId,
    required this.title,
    required this.description,
    required this.defaultPenaltyAmount,
    required this.defaultSuspensionType,
    required this.defaultSuspensionDays,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PolicyRule.fromJson(Map<String, dynamic> json) => PolicyRule(
        ruleId: json['ruleId']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        defaultPenaltyAmount:
            (json['defaultPenaltyAmount'] as num?)?.toDouble() ?? 0,
        defaultSuspensionType:
            json['defaultSuspensionType']?.toString() ?? 'None',
        defaultSuspensionDays: (json['defaultSuspensionDays'] as num?)?.toInt(),
        isActive: (json['isActive'] as bool?) ?? true,
        createdAt: DateTime.parse(json['createdAt'].toString()),
        updatedAt: DateTime.parse(json['updatedAt'].toString()),
      );
}

class ViolationSummary {
  final String violationId;
  final String policyRuleTitle;
  final String status;
  final double penaltyAmount;
  final String suspensionType;
  final DateTime createdAt;

  const ViolationSummary({
    required this.violationId,
    required this.policyRuleTitle,
    required this.status,
    required this.penaltyAmount,
    required this.suspensionType,
    required this.createdAt,
  });

  factory ViolationSummary.fromJson(Map<String, dynamic> json) =>
      ViolationSummary(
        violationId: json['violationId']?.toString() ?? '',
        policyRuleTitle: json['policyRuleTitle']?.toString() ?? '',
        status: json['status']?.toString() ?? '',
        penaltyAmount: (json['penaltyAmount'] as num?)?.toDouble() ?? 0,
        suspensionType: json['suspensionType']?.toString() ?? '',
        createdAt: DateTime.parse(json['createdAt'].toString()),
      );
}

class ViolationListPage {
  final List<ViolationSummary> violations;
  final int totalCount;
  final int page;
  final int pageSize;

  const ViolationListPage({
    required this.violations,
    required this.totalCount,
    required this.page,
    required this.pageSize,
  });

  factory ViolationListPage.fromJson(Map<String, dynamic> json) =>
      ViolationListPage(
        violations: (json['violations'] as List<dynamic>? ?? [])
            .map((v) => ViolationSummary.fromJson(v as Map<String, dynamic>))
            .toList(),
        totalCount: (json['totalCount'] as num?)?.toInt() ?? 0,
        page: (json['page'] as num?)?.toInt() ?? 1,
        pageSize: (json['pageSize'] as num?)?.toInt() ?? 20,
      );
}

class ViolationDetail {
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

  const ViolationDetail({
    required this.violationId,
    required this.policyRuleTitle,
    required this.description,
    required this.penaltyAmount,
    required this.suspensionType,
    required this.suspensionDays,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.appealStatus,
    required this.appealReasonText,
    required this.appealAdminNotes,
    required this.appealDecidedAt,
  });

  factory ViolationDetail.fromJson(Map<String, dynamic> json) =>
      ViolationDetail(
        violationId: json['violationId']?.toString() ?? '',
        policyRuleTitle: json['policyRuleTitle']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        penaltyAmount: (json['penaltyAmount'] as num?)?.toDouble() ?? 0,
        suspensionType: json['suspensionType']?.toString() ?? '',
        suspensionDays: (json['suspensionDays'] as num?)?.toInt(),
        status: json['status']?.toString() ?? '',
        createdAt: DateTime.parse(json['createdAt'].toString()),
        updatedAt: DateTime.parse(json['updatedAt'].toString()),
        appealStatus: json['appealStatus']?.toString(),
        appealReasonText: json['appealReasonText']?.toString(),
        appealAdminNotes: json['appealAdminNotes']?.toString(),
        appealDecidedAt: json['appealDecidedAt'] == null
            ? null
            : DateTime.parse(json['appealDecidedAt'].toString()),
      );
}

class ViolationAppeal {
  final String appealId;
  final String violationId;
  final String reasonText;
  final String status;
  final String? adminNotes;
  final DateTime createdAt;
  final DateTime? decidedAt;

  const ViolationAppeal({
    required this.appealId,
    required this.violationId,
    required this.reasonText,
    required this.status,
    required this.adminNotes,
    required this.createdAt,
    required this.decidedAt,
  });

  factory ViolationAppeal.fromJson(Map<String, dynamic> json) =>
      ViolationAppeal(
        appealId: json['appealId']?.toString() ?? '',
        violationId: json['violationId']?.toString() ?? '',
        reasonText: json['reasonText']?.toString() ?? '',
        status: json['status']?.toString() ?? '',
        adminNotes: json['adminNotes']?.toString(),
        createdAt: DateTime.parse(json['createdAt'].toString()),
        decidedAt: json['decidedAt'] == null
            ? null
            : DateTime.parse(json['decidedAt'].toString()),
      );
}

class ViolationAppealListPage {
  final List<ViolationAppeal> appeals;
  final int totalCount;
  final int page;
  final int pageSize;

  const ViolationAppealListPage({
    required this.appeals,
    required this.totalCount,
    required this.page,
    required this.pageSize,
  });

  factory ViolationAppealListPage.fromJson(Map<String, dynamic> json) =>
      ViolationAppealListPage(
        appeals: (json['appeals'] as List<dynamic>? ?? [])
            .map((a) => ViolationAppeal.fromJson(a as Map<String, dynamic>))
            .toList(),
        totalCount: (json['totalCount'] as num?)?.toInt() ?? 0,
        page: (json['page'] as num?)?.toInt() ?? 1,
        pageSize: (json['pageSize'] as num?)?.toInt() ?? 20,
      );
}
