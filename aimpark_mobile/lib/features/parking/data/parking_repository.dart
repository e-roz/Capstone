import 'package:dio/dio.dart';

import '../../../core/network/api_endpoints.dart';
import 'models/parking_history_entry.dart';
import 'models/parking_slot.dart';

class ParkingRepository {
  ParkingRepository(this._dio);

  final Dio _dio;

  Future<ParkingHistoryResult> getHistory({
    int page = 1,
    int pageSize = 20,
    String? vehicleId,
  }) async {
    final response = await _dio.get(
      ApiEndpoints.parkingHistory,
      queryParameters: {
        'page': page,
        'pageSize': pageSize,
        'vehicleId': ?vehicleId,
      },
    );
    return ParkingHistoryResult.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ParkingAvailability> getSlots() async {
    final response = await _dio.get(ApiEndpoints.parkingSlots);
    return ParkingAvailability.fromJson(response.data as Map<String, dynamic>);
  }

  /// Asks the server where to park. Advice only — nothing is held, so the slot
  /// may be gone by the time the driver arrives. Always returns 200; "lot full"
  /// is an outcome in the body, not an HTTP error.
  Future<SlotRecommendation> recommend() async {
    final response = await _dio.post(ApiEndpoints.parkingRecommend);
    return SlotRecommendation.fromJson(response.data as Map<String, dynamic>);
  }

  /// The driver says which bay they parked in. Safe to call again to change it.
  /// A refusal (bay already confirmed by someone else, session too old) comes
  /// back as a 400 whose message the caller shows as it is.
  Future<void> confirmSlot({
    required String logId,
    required String slotId,
  }) async {
    await _dio.post(
      ApiEndpoints.parkingConfirmSlot,
      data: {'logId': logId, 'slotId': slotId},
    );
  }
}
