import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/constants/api_endpoints.dart';
import '../core/network/dio_client.dart';
import '../models/parking_log.dart';
import '../router/destinations.dart';
import 'auth_provider.dart';

part 'parking_logs_provider.g.dart';

class ParkingLogsQuery {
  final int page;
  final int pageSize;

  /// Matches a name or a plate number; null or empty means no search.
  final String? search;
  final int? gate;

  /// "Car", "Motorcycle", or null for both.
  final String? vehicleType;

  /// True for visitors only, false for members only, null for both.
  final bool? visitor;
  final DateTime? from;
  final DateTime? to;

  const ParkingLogsQuery({
    this.page = 1,
    this.pageSize = 20,
    this.search,
    this.gate,
    this.vehicleType,
    this.visitor,
    this.from,
    this.to,
  });
}

@riverpod
class ParkingLogsQueryNotifier extends _$ParkingLogsQueryNotifier {
  @override
  ParkingLogsQuery build() {
    // A guard at the gate wants what is happening now, not every record there
    // has ever been. An administrator reviewing reports still starts with all.
    if (ref.read(staffRoleProvider) != StaffRole.security) {
      return const ParkingLogsQuery();
    }
    final today = DateTime.now();
    return ParkingLogsQuery(
      from: DateTime(today.year, today.month, today.day),
      to: DateTime(today.year, today.month, today.day, 23, 59, 59),
    );
  }

  // Every filter change goes back to page 1, so the page you were on cannot
  // fall past the end of a shorter result.
  void _set({
    int? page,
    String? search,
    int? gate,
    String? vehicleType,
    bool? visitor,
    DateTime? from,
    DateTime? to,
  }) =>
      state = ParkingLogsQuery(
        page: page ?? 1,
        pageSize: state.pageSize,
        search: search,
        gate: gate,
        vehicleType: vehicleType,
        visitor: visitor,
        from: from,
        to: to,
      );

  void setPage(int page) => _set(
        page: page,
        search: state.search,
        gate: state.gate,
        vehicleType: state.vehicleType,
        visitor: state.visitor,
        from: state.from,
        to: state.to,
      );

  void setSearch(String value) => _set(
        search: value.isEmpty ? null : value,
        gate: state.gate,
        vehicleType: state.vehicleType,
        visitor: state.visitor,
        from: state.from,
        to: state.to,
      );

  void setGate(int? gate) => _set(
        search: state.search,
        gate: gate,
        vehicleType: state.vehicleType,
        visitor: state.visitor,
        from: state.from,
        to: state.to,
      );

  void setVehicleType(String? vehicleType) => _set(
        search: state.search,
        gate: state.gate,
        vehicleType: vehicleType,
        visitor: state.visitor,
        from: state.from,
        to: state.to,
      );

  void setVisitor(bool? visitor) => _set(
        search: state.search,
        gate: state.gate,
        vehicleType: state.vehicleType,
        visitor: visitor,
        from: state.from,
        to: state.to,
      );

  /// One whole day, for the guard's picker.
  void setDay(DateTime day) => setDateRange(
        DateTime(day.year, day.month, day.day),
        DateTime(day.year, day.month, day.day, 23, 59, 59),
      );

  void setDateRange(DateTime? from, DateTime? to) => _set(
        search: state.search,
        gate: state.gate,
        vehicleType: state.vehicleType,
        visitor: state.visitor,
        from: from,
        to: to,
      );
}

@riverpod
Future<ParkingLogPage> parkingLogs(Ref ref) async {
  final query = ref.watch(parkingLogsQueryNotifierProvider);
  final dio = ref.watch(dioProvider);

  final params = <String, dynamic>{
    'page': query.page,
    'pageSize': query.pageSize,
    'search': ?query.search,
    'gate': ?query.gate,
    'vehicleType': ?query.vehicleType,
    'visitor': ?query.visitor,
    // UTC, so the server reads the same moment the picker meant.
    'from': ?query.from?.toUtc().toIso8601String(),
    'to': ?query.to?.toUtc().toIso8601String(),
  };

  final response =
      await dio.get(ApiEndpoints.parkingLogs, queryParameters: params);
  return ParkingLogPage.fromJson(response.data as Map<String, dynamic>);
}
