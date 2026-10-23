class IncidentSummary {
  final String incidentId;
  final String category;
  final String status;
  final DateTime createdAt;

  /// The account that filed it, as shown in the queue.
  final String reportedByName;
  final String reportedByRole;

  /// When an administrator resolved or dismissed it. Null until decided, and
  /// for reports decided before the date was recorded.
  final DateTime? reviewedAt;

  /// Notes Security added, and whether an administrator has yet to read any.
  final int followUpCount;
  final bool hasNewFollowUp;

  const IncidentSummary({
    required this.incidentId,
    required this.category,
    required this.status,
    required this.createdAt,
    this.reportedByName = '',
    this.reportedByRole = '',
    this.reviewedAt,
    this.followUpCount = 0,
    this.hasNewFollowUp = false,
  });

  factory IncidentSummary.fromJson(Map<String, dynamic> json) =>
      IncidentSummary(
        incidentId: json['incidentId']?.toString() ?? '',
        category: json['category']?.toString() ?? '',
        status: json['status']?.toString() ?? '',
        createdAt: DateTime.parse(json['createdAt'].toString()),
        reportedByName: json['reportedByName']?.toString() ?? '',
        reportedByRole: json['reportedByRole']?.toString() ?? '',
        reviewedAt: json['reviewedAt'] == null
            ? null
            : DateTime.parse(json['reviewedAt'].toString()),
        followUpCount: (json['followUpCount'] as num?)?.toInt() ?? 0,
        hasNewFollowUp: json['hasNewFollowUp'] == true,
      );
}

class IncidentListPage {
  final List<IncidentSummary> incidents;
  final int totalCount;
  final int page;
  final int pageSize;

  const IncidentListPage({
    required this.incidents,
    required this.totalCount,
    required this.page,
    required this.pageSize,
  });

  factory IncidentListPage.fromJson(Map<String, dynamic> json) =>
      IncidentListPage(
        incidents: (json['incidents'] as List<dynamic>? ?? [])
            .map((i) => IncidentSummary.fromJson(i as Map<String, dynamic>))
            .toList(),
        totalCount: (json['totalCount'] as num?)?.toInt() ?? 0,
        page: (json['page'] as num?)?.toInt() ?? 1,
        pageSize: (json['pageSize'] as num?)?.toInt() ?? 20,
      );
}

/// One attached file: where to fetch it and the name it was uploaded with.
class IncidentEvidenceItem {
  final String url;
  final String fileName;

  const IncidentEvidenceItem({required this.url, required this.fileName});

  /// `PNG`, `JPG` or `PDF` - what kind of file this is, from the uploaded name.
  String get typeLabel {
    final dot = fileName.lastIndexOf('.');
    if (dot < 0 || dot == fileName.length - 1) return 'FILE';
    final ext = fileName.substring(dot + 1).toLowerCase();
    return ext == 'jpeg' ? 'JPG' : ext.toUpperCase();
  }

  bool get isPdf => typeLabel == 'PDF';

  factory IncidentEvidenceItem.fromJson(Map<String, dynamic> json) =>
      IncidentEvidenceItem(
        url: json['url']?.toString() ?? '',
        fileName: json['fileName']?.toString() ?? '',
      );
}

/// One note Security added to a report: what they found out, and optionally
/// one photo or PDF. Added to, never edited.
class IncidentFollowUp {
  final String followUpId;
  final String authorName;
  final String note;
  final DateTime createdAt;
  final IncidentEvidenceItem? attachment;

  /// No administrator has opened the report since it was added.
  final bool isNew;

  const IncidentFollowUp({
    required this.followUpId,
    required this.authorName,
    required this.note,
    required this.createdAt,
    this.attachment,
    this.isNew = false,
  });

  factory IncidentFollowUp.fromJson(Map<String, dynamic> json) {
    final url = json['attachmentUrl']?.toString();
    return IncidentFollowUp(
      followUpId: json['followUpId']?.toString() ?? '',
      authorName: json['authorName']?.toString() ?? '',
      note: json['note']?.toString() ?? '',
      createdAt: DateTime.parse(json['createdAt'].toString()),
      attachment: url == null || url.isEmpty
          ? null
          : IncidentEvidenceItem(
              url: url,
              fileName: json['attachmentName']?.toString() ?? '',
            ),
      isNew: json['isNew'] == true,
    );
  }
}

class IncidentDetail {
  final String incidentId;
  final String category;
  final String description;
  final String? location;

  /// The bay the reporter picked, if any, and its code for display.
  final String? slotId;
  final String? slotCode;

  final String status;
  final String? adminNotes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? reviewedAt;
  final String reportedByName;
  final String reportedByRole;
  final List<IncidentEvidenceItem> evidence;

  /// Attachments that exist but could not be opened just now - the guard
  /// post's server with no internet cannot reach the files.
  final int evidenceUnavailable;

  /// What Security found out, oldest first.
  final List<IncidentFollowUp> followUps;

  const IncidentDetail({
    required this.incidentId,
    required this.category,
    required this.description,
    required this.location,
    required this.status,
    required this.adminNotes,
    required this.createdAt,
    required this.updatedAt,
    required this.evidence,
    this.slotId,
    this.slotCode,
    this.reviewedAt,
    this.reportedByName = '',
    this.reportedByRole = '',
    this.evidenceUnavailable = 0,
    this.followUps = const [],
  });

  bool get hasNewFollowUp => followUps.any((f) => f.isNew);

  /// Resolved, dismissed or withdrawn: nothing left for anyone to decide.
  bool get isClosed =>
      status == 'Resolved' || status == 'Dismissed' || status == 'Withdrawn';

  factory IncidentDetail.fromJson(Map<String, dynamic> json) {
    final items = (json['evidence'] as List<dynamic>? ?? [])
        .map((e) => IncidentEvidenceItem.fromJson(e as Map<String, dynamic>))
        .toList();

    // An API that predates `evidence` only sends bare URLs. Showing those
    // beats showing nothing; the type is then read from the URL's path.
    final evidence = items.isNotEmpty
        ? items
        : (json['evidenceUrls'] as List<dynamic>? ?? [])
            .map((u) => IncidentEvidenceItem(
                  url: u.toString(),
                  fileName: Uri.tryParse(u.toString())?.path.split('/').last ??
                      '',
                ))
            .toList();

    return IncidentDetail(
      incidentId: json['incidentId']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      location: json['location']?.toString(),
      slotId: json['slotId']?.toString(),
      slotCode: json['slotCode']?.toString(),
      status: json['status']?.toString() ?? '',
      adminNotes: json['adminNotes']?.toString(),
      createdAt: DateTime.parse(json['createdAt'].toString()),
      updatedAt: DateTime.parse(json['updatedAt'].toString()),
      reviewedAt: json['reviewedAt'] == null
          ? null
          : DateTime.parse(json['reviewedAt'].toString()),
      reportedByName: json['reportedByName']?.toString() ?? '',
      reportedByRole: json['reportedByRole']?.toString() ?? '',
      evidence: evidence,
      evidenceUnavailable: (json['evidenceUnavailable'] as num?)?.toInt() ?? 0,
      followUps: (json['followUps'] as List<dynamic>? ?? [])
          .map((f) => IncidentFollowUp.fromJson(f as Map<String, dynamic>))
          .toList(),
    );
  }
}
