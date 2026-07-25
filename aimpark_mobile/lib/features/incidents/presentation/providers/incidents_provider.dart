import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/network/dio_client.dart';
import '../../data/incidents_repository.dart';
import '../../data/models/incident.dart';

part 'incidents_provider.g.dart';

@riverpod
IncidentsRepository incidentsRepository(Ref ref) {
  return IncidentsRepository(ref.watch(dioProvider));
}

@riverpod
class IncidentsNotifier extends _$IncidentsNotifier {
  @override
  Future<IncidentListResult> build() {
    return ref.read(incidentsRepositoryProvider).list();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(incidentsRepositoryProvider).list());
  }
}

@riverpod
Future<IncidentDetail> incidentDetail(Ref ref, String incidentId) {
  return ref.watch(incidentsRepositoryProvider).getDetail(incidentId);
}
