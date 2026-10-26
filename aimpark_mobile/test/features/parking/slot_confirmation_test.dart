import 'package:aimpark_mobile/core/services/push_navigation.dart';
import 'package:aimpark_mobile/features/parking/data/models/parking_history_entry.dart';
import 'package:aimpark_mobile/features/parking/data/models/parking_slot.dart';
import 'package:aimpark_mobile/features/parking/presentation/widgets/parking_map.dart';
import 'package:flutter_test/flutter_test.dart';

ParkingHistoryEntry _log(
  String id, {
  required DateTime entry,
  DateTime? exit,
  bool confirmed = false,
}) => ParkingHistoryEntry(
  logId: id,
  entryTime: entry,
  exitTime: exit,
  slotCode: 'M1',
  slotConfirmed: confirmed,
);

ParkingSlot _slot(String code, String status) => ParkingSlot(
  slotId: 'id-$code',
  slotCode: code,
  gate: 1,
  vehicleType: 'Motorcycle',
  status: status,
);

void main() {
  // Noon, so a few hours either side is the same calendar day on any device.
  final now = DateTime(2026, 10, 20, 12);

  group('ParkingHistoryEntry.fromJson', () {
    test('reads slotConfirmed', () {
      final entry = ParkingHistoryEntry.fromJson({
        'logId': 'a',
        'slotCode': 'M2',
        'slotConfirmed': true,
        'entryTime': '2026-10-20T01:00:00Z',
      });
      expect(entry.slotConfirmed, isTrue);
    });

    test('treats a missing slotConfirmed as not confirmed', () {
      final entry = ParkingHistoryEntry.fromJson({
        'logId': 'a',
        'entryTime': '2026-10-20T01:00:00Z',
      });
      expect(entry.slotConfirmed, isFalse);
    });
  });

  group('awaitingSlotConfirmation', () {
    ParkingHistoryResult result(List<ParkingHistoryEntry> logs) =>
        ParkingHistoryResult(logs: logs, totalCount: logs.length);

    test('an open session with no confirmed bay is waiting', () {
      final open = _log('open', entry: now.subtract(const Duration(hours: 1)));
      expect(result([open]).awaitingSlotConfirmation(now: now), open);
    });

    test('a confirmed session is not asked about again', () {
      final done = _log(
        'done',
        entry: now.subtract(const Duration(hours: 1)),
        confirmed: true,
      );
      expect(result([done]).awaitingSlotConfirmation(now: now), isNull);
    });

    test('a session that ended earlier today is still waiting', () {
      final left = _log(
        'left',
        entry: DateTime(2026, 10, 20, 9),
        exit: DateTime(2026, 10, 20, 10),
      );
      expect(result([left]).awaitingSlotConfirmation(now: now), left);
    });

    test('a session from an earlier day is not asked about', () {
      final old = _log(
        'old',
        entry: DateTime(2026, 10, 18, 9),
        exit: DateTime(2026, 10, 18, 10),
      );
      expect(result([old]).awaitingSlotConfirmation(now: now), isNull);
    });
  });

  group('BayState.of', () {
    test('the confirmed bay wins over the sensor and over the suggestion', () {
      final taken = _slot('M2', 'Occupied');
      expect(
        BayState.of(taken, suggestedCode: 'M2', confirmedCode: 'M2'),
        BayState.confirmed,
      );
    });

    test('other bays keep reading from the sensor', () {
      expect(
        BayState.of(_slot('M3', 'Occupied'), confirmedCode: 'M2'),
        BayState.taken,
      );
      expect(
        BayState.of(_slot('M4', 'Available'), confirmedCode: 'M2'),
        BayState.free,
      );
    });
  });

  group('routeForPush', () {
    test('the slot reminder opens the parking map', () {
      expect(
        routeForPush({'screen': 'parking-slots', 'logId': 'abc'}),
        '/home/user/parking-slots',
      );
    });
  });
}
