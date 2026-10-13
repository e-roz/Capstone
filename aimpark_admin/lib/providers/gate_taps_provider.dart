import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/constants/api_endpoints.dart';
import '../core/network/dio_client.dart';
import '../models/gate_tap_event.dart';
import '../router/destinations.dart';
import 'auth_provider.dart';

part 'gate_taps_provider.g.dart';

class GateTapsQuery {
  final int page;
  final int pageSize;

  /// "entered", "exited", "denied", "manual", or null for all.
  final String? result;
  final int? gate;

  /// "match", "mismatch", or null for all.
  final String? plate;

  /// Matches a name, a card or a plate; null means no search.
  final String? search;
  final DateTime? from;
  final DateTime? to;

  const GateTapsQuery({
    this.page = 1,
    this.pageSize = 25,
    this.result,
    this.gate,
    this.plate,
    this.search,
    this.from,
    this.to,
  });

  GateTapsQuery copyWith({
    int? page,
    String? Function()? result,
    int? Function()? gate,
    String? Function()? plate,
    String? Function()? search,
    DateTime? Function()? from,
    DateTime? Function()? to,
  }) => GateTapsQuery(
    page: page ?? this.page,
    pageSize: pageSize,
    result: result != null ? result() : this.result,
    gate: gate != null ? gate() : this.gate,
    plate: plate != null ? plate() : this.plate,
    search: search != null ? search() : this.search,
    from: from != null ? from() : this.from,
    to: to != null ? to() : this.to,
  );
}

@riverpod
class GateTapsQueryNotifier extends _$GateTapsQueryNotifier {
  @override
  GateTapsQuery build() {
    // See ParkingLogsQueryNotifier: a guard starts on today.
    if (ref.read(staffRoleProvider) != StaffRole.security) {
      return const GateTapsQuery();
    }
    final today = DateTime.now();
    return GateTapsQuery(
      from: DateTime(today.year, today.month, today.day),
      to: DateTime(today.year, today.month, today.day, 23, 59, 59),
    );
  }

  /// One whole day, for the guard's picker.
  void setDay(DateTime day) => setDateRange(
        DateTime(day.year, day.month, day.day),
        DateTime(day.year, day.month, day.day, 23, 59, 59),
      );

  void setPage(int page) => state = state.copyWith(page: page);

  // Every filter change goes back to page 1, so the page you were on cannot
  // fall past the end of a shorter result.
  void setResult(String? value) =>
      state = state.copyWith(page: 1, result: () => value);

  void setGate(int? value) => state = state.copyWith(page: 1, gate: () => value);

  void setPlate(String? value) =>
      state = state.copyWith(page: 1, plate: () => value);

  void setSearch(String value) => state = state.copyWith(
    page: 1,
    search: () => value.isEmpty ? null : value,
  );

  void setDateRange(DateTime? from, DateTime? to) =>
      state = state.copyWith(page: 1, from: () => from, to: () => to);
}

@riverpod
Future<GateTapPage> gateTaps(Ref ref) async {
  final query = ref.watch(gateTapsQueryNotifierProvider);
  final dio = ref.watch(dioProvider);

  final response = await dio.get(
    ApiEndpoints.liveGateHistory,
    queryParameters: {
      'page': query.page,
      'pageSize': query.pageSize,
      'result': ?query.result,
      'gate': ?query.gate,
      'plate': ?query.plate,
      'search': ?query.search,
      // UTC, so the server reads the same moment the picker meant.
      'from': ?query.from?.toUtc().toIso8601String(),
      'to': ?query.to?.toUtc().toIso8601String(),
    },
  );
  return GateTapPage.fromJson(response.data as Map<String, dynamic>);
}
