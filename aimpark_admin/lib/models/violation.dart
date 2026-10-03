/// The violation case lifecycle — `AimPark.API.Enums.ViolationStatus`.
///
/// Issued → PendingAppeal → Appealed (user won) or Accountable (user lost).
/// Issued also becomes Accountable when the appeal deadline passes or an admin
/// marks it. Issued and PendingAppeal can be Dismissed.
class ViolationStatuses {
  ViolationStatuses._();

  static const issued = 'Issued';
  static const pendingAppeal = 'PendingAppeal';
  static const appealed = 'Appealed';
  static const accountable = 'Accountable';
  static const dismissed = 'Dismissed';

  static const all = [issued, pendingAppeal, appealed, accountable, dismissed];

  /// Three Accountable violations revoke the user's RFID card.
  static const strikesBeforeRevoke = 3;

  static String label(String status) => switch (status) {
        pendingAppeal => 'Pending Appeal',
        _ => status,
      };

  static bool isOpen(String status) =>
      status == issued || status == pendingAppeal;
}

class PolicyRule {
  final String ruleId;
  final String title;
  final String description;

  /// Parking, Access, Conduct, Documentation or Other.
  final String category;

  final double defaultPenaltyAmount;
  final String defaultSuspensionType;
  final int? defaultSuspensionDays;

  /// Days the offender's card keeps working so they can appeal before the
  /// suspension starts. 0 means it starts immediately.
  final int appealWindowDays;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PolicyRule({
    required this.ruleId,
    required this.title,
    required this.description,
    required this.category,
    required this.defaultPenaltyAmount,
    required this.defaultSuspensionType,
    required this.defaultSuspensionDays,
    this.appealWindowDays = 3,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PolicyRule.fromJson(Map<String, dynamic> json) => PolicyRule(
        ruleId: json['ruleId']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        // Rules created before categories existed come back as Parking from the
        // database default; an older API that omits the field lands there too.
        category: json['category']?.toString() ?? 'Parking',
        defaultPenaltyAmount:
            (json['defaultPenaltyAmount'] as num?)?.toDouble() ?? 0,
        defaultSuspensionType:
            json['defaultSuspensionType']?.toString() ?? 'None',
        defaultSuspensionDays: (json['defaultSuspensionDays'] as num?)?.toInt(),
        appealWindowDays: (json['appealWindowDays'] as num?)?.toInt() ?? 3,
        isActive: (json['isActive'] as bool?) ?? true,
        createdAt: DateTime.parse(json['createdAt'].toString()),
        updatedAt: DateTime.parse(json['updatedAt'].toString()),
      );
}

class ViolationSummary {
  final String violationId;
  final String policyRuleId;
  final String policyRuleTitle;
  final String userId;
  final String userFullName;
  final String? studentNumber;
  final String? rfidTagId;

  /// Last moment the user can appeal; after it an Issued violation becomes
  /// Accountable on its own.
  final DateTime? appealDeadline;
  final String status;
  final double penaltyAmount;
  final String suspensionType;

  /// How long a Temporary suspension runs. Null for None and Permanent.
  final int? suspensionDays;

  final DateTime createdAt;

  const ViolationSummary({
    required this.violationId,
    required this.policyRuleId,
    required this.policyRuleTitle,
    required this.userId,
    required this.userFullName,
    required this.studentNumber,
    required this.rfidTagId,
    required this.appealDeadline,
    required this.status,
    required this.penaltyAmount,
    required this.suspensionType,
    required this.suspensionDays,
    required this.createdAt,
  });

  factory ViolationSummary.fromJson(Map<String, dynamic> json) =>
      ViolationSummary(
        violationId: json['violationId']?.toString() ?? '',
        policyRuleId: json['policyRuleId']?.toString() ?? '',
        policyRuleTitle: json['policyRuleTitle']?.toString() ?? '',
        userId: json['userId']?.toString() ?? '',
        userFullName: json['userFullName']?.toString() ?? '',
        studentNumber: json['studentNumber']?.toString(),
        rfidTagId: json['rfidTagId']?.toString(),
        appealDeadline: _date(json['appealDeadline']),
        status: json['status']?.toString() ?? '',
        penaltyAmount: (json['penaltyAmount'] as num?)?.toDouble() ?? 0,
        suspensionType: json['suspensionType']?.toString() ?? '',
        suspensionDays: (json['suspensionDays'] as num?)?.toInt(),
        createdAt: DateTime.parse(json['createdAt'].toString()),
      );
}

DateTime? _date(Object? value) =>
    value == null ? null : DateTime.parse(value.toString());

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

/// Everything about one violation — what the admin's View dialog shows and
/// decides from.
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
  final DateTime? appealDeadline;

  /// The rule as it stands now. Its description is what the case is judged
  /// against; the penalty above is the snapshot taken at issue.
  final PolicyRule? rule;

  final String userId;
  final String userFullName;
  final String? studentNumber;
  /// The card the user holds now — null once revoked.
  final String? rfidTagId;

  /// The card they held when this was issued.
  final String? rfidTagIdAtIssue;
  final String? rfidStatus;

  /// The user's Accountable violations, this one included if it is one.
  final int accountableCount;

  // Payment — only exists once the violation is Accountable.
  final String? paymentStatus;
  final double? amountDue;
  final DateTime? paymentDueAt;
  final DateTime? paidAt;

  // Timeline
  final String? issuedByName;
  final DateTime? accountableAt;
  final String? accountableReason;
  final String? accountableByName;
  final DateTime? dismissedAt;
  final String? dismissReason;
  final String? dismissedByName;
  final DateTime? rfidRevokedAt;

  // Appeal
  final String? appealId;
  final DateTime? appealCreatedAt;
  final String? appealStatus;
  final String? appealReasonText;
  final String? appealAdminNotes;
  final DateTime? appealDecidedAt;
  final String? appealDecidedByName;
  final List<String> appealEvidenceUrls;

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
    required this.appealDeadline,
    required this.rule,
    required this.userId,
    required this.userFullName,
    required this.studentNumber,
    required this.rfidTagId,
    required this.rfidTagIdAtIssue,
    required this.rfidStatus,
    required this.accountableCount,
    required this.paymentStatus,
    required this.amountDue,
    required this.paymentDueAt,
    required this.paidAt,
    required this.issuedByName,
    required this.accountableAt,
    required this.accountableReason,
    required this.accountableByName,
    required this.dismissedAt,
    required this.dismissReason,
    required this.dismissedByName,
    required this.rfidRevokedAt,
    required this.appealId,
    required this.appealCreatedAt,
    required this.appealStatus,
    required this.appealReasonText,
    required this.appealAdminNotes,
    required this.appealDecidedAt,
    required this.appealDecidedByName,
    required this.appealEvidenceUrls,
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
        appealDeadline: _date(json['appealDeadline']),
        rule: json['rule'] is Map<String, dynamic>
            ? PolicyRule.fromJson(json['rule'] as Map<String, dynamic>)
            : null,
        userId: json['userId']?.toString() ?? '',
        userFullName: json['userFullName']?.toString() ?? '',
        studentNumber: json['studentNumber']?.toString(),
        rfidTagId: json['rfidTagId']?.toString(),
        rfidTagIdAtIssue: json['rfidTagIdAtIssue']?.toString(),
        rfidStatus: json['rfidStatus']?.toString(),
        accountableCount: (json['accountableCount'] as num?)?.toInt() ?? 0,
        paymentStatus: json['paymentStatus']?.toString(),
        amountDue: (json['amountDue'] as num?)?.toDouble(),
        paymentDueAt: _date(json['paymentDueAt']),
        paidAt: _date(json['paidAt']),
        issuedByName: json['issuedByName']?.toString(),
        accountableAt: _date(json['accountableAt']),
        accountableReason: json['accountableReason']?.toString(),
        accountableByName: json['accountableByName']?.toString(),
        dismissedAt: _date(json['dismissedAt']),
        dismissReason: json['dismissReason']?.toString(),
        dismissedByName: json['dismissedByName']?.toString(),
        rfidRevokedAt: _date(json['rfidRevokedAt']),
        appealId: json['appealId']?.toString(),
        appealCreatedAt: _date(json['appealCreatedAt']),
        appealStatus: json['appealStatus']?.toString(),
        appealReasonText: json['appealReasonText']?.toString(),
        appealAdminNotes: json['appealAdminNotes']?.toString(),
        appealDecidedAt: _date(json['appealDecidedAt']),
        appealDecidedByName: json['appealDecidedByName']?.toString(),
        appealEvidenceUrls:
            (json['appealEvidenceUrls'] as List<dynamic>? ?? const [])
                .map((e) => e.toString())
                .toList(),
      );
}

class ViolationAppeal {
  final String appealId;
  final String violationId;

  // Enough of the violation to tell from the queue what the appeal is about.
  final String policyRuleTitle;
  final String userFullName;
  final String? rfidTagId;
  final String violationStatus;

  final String reasonText;
  final String status;
  final String? adminNotes;
  final DateTime createdAt;
  final DateTime? decidedAt;

  /// Photos the user attached to the appeal. The whole point of an appeal is
  /// often the photograph, and this list arrived empty until the API was taught
  /// to send it — so the queue was being decided on the text alone.
  final List<String> evidenceUrls;

  const ViolationAppeal({
    required this.appealId,
    required this.violationId,
    required this.policyRuleTitle,
    required this.userFullName,
    required this.rfidTagId,
    required this.violationStatus,
    required this.reasonText,
    required this.status,
    required this.adminNotes,
    required this.createdAt,
    required this.decidedAt,
    this.evidenceUrls = const [],
  });

  factory ViolationAppeal.fromJson(Map<String, dynamic> json) =>
      ViolationAppeal(
        appealId: json['appealId']?.toString() ?? '',
        violationId: json['violationId']?.toString() ?? '',
        policyRuleTitle: json['policyRuleTitle']?.toString() ?? '',
        userFullName: json['userFullName']?.toString() ?? '',
        rfidTagId: json['rfidTagId']?.toString(),
        violationStatus: json['violationStatus']?.toString() ?? '',
        reasonText: json['reasonText']?.toString() ?? '',
        status: json['status']?.toString() ?? '',
        adminNotes: json['adminNotes']?.toString(),
        createdAt: DateTime.parse(json['createdAt'].toString()),
        decidedAt: json['decidedAt'] == null
            ? null
            : DateTime.parse(json['decidedAt'].toString()),
        evidenceUrls: (json['evidenceUrls'] as List<dynamic>? ?? const [])
            .map((e) => e.toString())
            .toList(),
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
