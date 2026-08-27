import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../data/models/vehicle.dart';

part 'vehicles_provider.g.dart';

@riverpod
Future<List<Vehicle>> myVehicles(Ref ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get(ApiEndpoints.vehicles);

  return [
    for (final entry in (response.data as List<dynamic>))
      Vehicle.fromJson(entry as Map<String, dynamic>),
  ];
}

/// The two calls that add a vehicle: read the documents, then commit what the
/// user agreed to.
///
/// Split for the same reason registration is split — the plate comes off the
/// receipt and is shown back before anything is stored, so the user confirms a
/// reading rather than supplying one.
@riverpod
VehiclesRepository vehiclesRepository(Ref ref) =>
    VehiclesRepository(ref.watch(dioProvider));

class VehiclesRepository {
  VehiclesRepository(this._dio);

  final Dio _dio;

  Future<Response<dynamic>> scanDocuments(FormData formData) =>
      _dio.post(ApiEndpoints.vehicleScan, data: formData);

  Future<Response<dynamic>> confirm(Map<String, dynamic> body) =>
      _dio.post(ApiEndpoints.vehicleConfirm, data: body);
}
