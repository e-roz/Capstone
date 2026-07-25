import 'package:dio/dio.dart';

import '../../../core/network/api_endpoints.dart';
import 'models/parking_history_entry.dart';
import 'models/parking_slot.dart';

class ParkingRepository {
  ParkingRepository(this._dio);

  final Dio _dio;

  Future<ParkingHistoryResult> getHistory({int page = 1, int pageSize = 20}) async {
    final response = await _dio.get(
      ApiEndpoints.parkingHistory,
      queryParameters: {'page': page, 'pageSize': pageSize},
    );
    return ParkingHistoryResult.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ParkingAvailability> getSlots() async {
    final response = await _dio.get(ApiEndpoints.parkingSlots);
    return ParkingAvailability.fromJson(response.data as Map<String, dynamic>);
  }
}
