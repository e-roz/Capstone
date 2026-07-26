class IncidentSummary {
  final String incidentId;
  final String category;
  final String status;
  final DateTime createdAt;

  const IncidentSummary({
    required this.incidentId,
    required this.category,
    required this.status,
    required this.createdAt,
  });

  factory IncidentSummary.fromJson(Map<String, dynamic> json) =>
      IncidentSummary(
        incidentId: json['incidentId']?.toString() ?? '',
        category: json['category']?.toString() ?? '',
        status: json['status']?.toString() ?? '',
        createdAt: DateTime.parse(json['createdAt'].toString()),
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

class IncidentDetail {
  final String incidentId;
  final String category;
  final String description;
  final String? location;
  final String status;
  final String? adminNotes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> evidenceUrls;

  const IncidentDetail({
    required this.incidentId,
    required this.category,
    required this.description,
    required this.location,
    required this.status,
    required this.adminNotes,
    required this.createdAt,
    required this.updatedAt,
    required this.evidenceUrls,
  });

  factory IncidentDetail.fromJson(Map<String, dynamic> json) =>
      IncidentDetail(
        incidentId: json['incidentId']?.toString() ?? '',
        category: json['category']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        location: json['location']?.toString(),
        status: json['status']?.toString() ?? '',
        adminNotes: json['adminNotes']?.toString(),
        createdAt: DateTime.parse(json['createdAt'].toString()),
        updatedAt: DateTime.parse(json['updatedAt'].toString()),
        evidenceUrls: (json['evidenceUrls'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList(),
      );
}
