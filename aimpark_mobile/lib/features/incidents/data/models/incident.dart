class IncidentSummary {
  const IncidentSummary({
    required this.incidentId,
    required this.category,
    required this.status,
    required this.createdAt,
  });

  final String incidentId;
  final String category;
  final String status;
  final DateTime createdAt;

  factory IncidentSummary.fromJson(Map<String, dynamic> json) {
    return IncidentSummary(
      incidentId: json['incidentId'] as String,
      category: json['category'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
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

  /// Editable and withdrawable only before an admin starts reviewing —
  /// mirrors the server rule, so the buttons never offer something that fails.
  bool get canModify => status == 'Submitted';

  factory IncidentDetail.fromJson(Map<String, dynamic> json) {
    return IncidentDetail(
      incidentId: json['incidentId'] as String,
      category: json['category'] as String,
      description: json['description'] as String,
      location: json['location'] as String?,
      status: json['status'] as String,
      adminNotes: json['adminNotes'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      evidenceUrls: (json['evidenceUrls'] as List<dynamic>).map((e) => e as String).toList(),
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
