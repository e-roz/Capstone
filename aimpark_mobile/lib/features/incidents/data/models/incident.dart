import '../../domain/incident_stage.dart';

class IncidentSummary {
  const IncidentSummary({
    required this.incidentId,
    required this.category,
    required this.status,
    required this.createdAt,
    this.descriptionPreview,
    this.location,
  });

  final String incidentId;

  /// The API's category name, e.g. `BlockedSlot`. Turn it into words with
  /// `incidentCategoryLabel`.
  final String category;
  final String status;

  /// Local time. Parsed from the server's timestamp and converted once, here, so
  /// no screen shows a UTC time as though it were the viewer's own.
  final DateTime createdAt;

  /// The first line or so of the description, so two reports in the same
  /// category can be told apart in the list. Null from a server that does not
  /// send it yet — the row then simply shows no preview.
  final String? descriptionPreview;

  /// Where it happened, when the server includes it in the list.
  final String? location;

  IncidentStage get stage => IncidentStage.fromApi(status);

  factory IncidentSummary.fromJson(Map<String, dynamic> json) {
    return IncidentSummary(
      incidentId: json['incidentId'] as String,
      category: json['category'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      descriptionPreview: json['descriptionPreview'] as String?,
      location: json['location'] as String?,
    );
  }
}

class IncidentDetail {
  const IncidentDetail({
    required this.incidentId,
    required this.category,
    required this.description,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.evidenceUrls,
    this.evidenceUnavailable = 0,
    this.location,
    this.adminNotes,
  });

  final String incidentId;
  final String category;
  final String description;
  final String? location;
  final String status;
  final String? adminNotes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> evidenceUrls;

  /// Photos that exist but could not be opened just now — the server says so when
  /// it cannot reach the files. Zero everywhere else, and from a server that does
  /// not send the field.
  final int evidenceUnavailable;

  IncidentStage get stage => IncidentStage.fromApi(status);

  /// Editable and withdrawable only before an admin starts reviewing —
  /// mirrors the server rule, so the buttons never offer something that fails.
  bool get canModify => stage.canModify;

  /// Changed since it was filed. Compared to the minute: a report saved a second
  /// after it was created has not meaningfully been "updated".
  bool get wasUpdated => updatedAt.difference(createdAt).inMinutes.abs() >= 1;

  factory IncidentDetail.fromJson(Map<String, dynamic> json) {
    return IncidentDetail(
      incidentId: json['incidentId'] as String,
      category: json['category'] as String,
      description: json['description'] as String,
      location: json['location'] as String?,
      status: json['status'] as String,
      adminNotes: json['adminNotes'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      updatedAt: DateTime.parse(json['updatedAt'] as String).toLocal(),
      evidenceUrls:
          (json['evidenceUrls'] as List<dynamic>).map((e) => e as String).toList(),
      evidenceUnavailable: (json['evidenceUnavailable'] as num?)?.toInt() ?? 0,
    );
  }
}

class IncidentListResult {
  const IncidentListResult({required this.incidents, required this.totalCount});

  final List<IncidentSummary> incidents;
  final int totalCount;

  factory IncidentListResult.fromJson(Map<String, dynamic> json) {
    return IncidentListResult(
      incidents: (json['incidents'] as List<dynamic>)
          .map((e) => IncidentSummary.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalCount: json['totalCount'] as int,
    );
  }
}
