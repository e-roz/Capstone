import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/network/dio_client.dart';
import '../../data/models/parking_history_entry.dart';
import '../../data/models/parking_slot.dart';
import '../../data/parking_repository.dart';

part 'parking_history_provider.g.dart';

@riverpod
ParkingRepository parkingRepository(Ref ref) {
  return ParkingRepository(ref.watch(dioProvider));
}

@riverpod
Future<ParkingAvailability> parkingAvailability(Ref ref) {
  return ref.watch(parkingRepositoryProvider).getSlots();
}

@riverpod
class ParkingHistoryNotifier extends _$ParkingHistoryNotifier {
  @override
  Future<ParkingHistoryResult> build() {
    return ref.read(parkingRepositoryProvider).getHistory();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(parkingRepositoryProvider).getHistory());
  }
}
