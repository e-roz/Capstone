import 'dart:async';

import 'package:flutter/widgets.dart';
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

/// The lot's free count, kept live while anything on screen watches it.
///
/// Re-fetched every [pollEvery] while the app is in the foreground, so a bay
/// filling or emptying shows up without a pull-to-refresh. A poll that fails
/// keeps the last count on screen rather than swapping it for an error — the
/// freshness chip turns amber once that count is old enough to doubt.
@riverpod
class ParkingAvailabilityNotifier extends _$ParkingAvailabilityNotifier {
  static const pollEvery = Duration(seconds: 10);

  Timer? _timer;
  bool _disposed = false;

  @override
  Future<ParkingAvailability> build() {
    _disposed = false;
    _timer = Timer.periodic(pollEvery, (_) => _poll());
    ref.onDispose(() {
      _disposed = true;
      _timer?.cancel();
    });
    return ref.watch(parkingRepositoryProvider).getSlots();
  }

  Future<void> _poll() async {
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) return;
    if (state.isLoading) return;
    try {
      final fresh = await ref.read(parkingRepositoryProvider).getSlots();
      if (!_disposed) state = AsyncData(fresh);
    } catch (_) {
      // Offline for a moment: the last count stays, and ages visibly.
    }
  }
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

/// One vehicle's most recent session, for the Home screen's vehicle card.
///
/// Deliberately its own request rather than reading off
/// [parkingHistoryNotifierProvider]'s page of the 20 most recent
/// *account-wide* logs — a second vehicle's last visit can easily be older
/// than that, which would make its "last seen" come back empty even though a
/// session exists.
@riverpod
Future<ParkingHistoryEntry?> vehicleLatestSession(Ref ref, String vehicleId) async {
  final result = await ref
      .watch(parkingRepositoryProvider)
      .getHistory(vehicleId: vehicleId, pageSize: 1);
  return result.logs.isEmpty ? null : result.logs.first;
}

/// The parking-history screen, filtered to one vehicle.
@riverpod
Future<ParkingHistoryResult> vehicleHistory(Ref ref, String vehicleId) {
  return ref.watch(parkingRepositoryProvider).getHistory(vehicleId: vehicleId);
}
