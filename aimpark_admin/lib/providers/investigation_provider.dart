import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/api_endpoints.dart';
import '../core/network/dio_client.dart';
import '../models/investigation.dart';

/// Results for what was typed in the Overview's search box. The box debounces,
/// so this is asked once the admin stops typing.
final overviewSearchProvider = FutureProvider.autoDispose
    .family<List<SearchResult>, String>((ref, query) async {
  final response = await ref
      .watch(dioProvider)
      .get(ApiEndpoints.adminSearch, queryParameters: {'q': query});
  final data = response.data as Map<String, dynamic>;
  return [
    for (final r in data['results'] as List? ?? const [])
      SearchResult.fromJson(r as Map<String, dynamic>),
  ];
});

/// Everything held about one subject, for the investigation panel.
final investigationProfileProvider = FutureProvider.autoDispose
    .family<InvestigationProfile, InvestigationSubject>((ref, subject) async {
  final response = await ref
      .watch(dioProvider)
      .get(ApiEndpoints.adminSearchProfile, queryParameters: subject.query);
  return InvestigationProfile.fromJson(response.data as Map<String, dynamic>);
});
