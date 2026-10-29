import 'package:aimpark_mobile/features/parking/data/models/parking_history_entry.dart';
import 'package:aimpark_mobile/features/parking/data/models/parking_slot.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ParkingHistoryEntry, paid ahead', () {
    test('reads when a paid session has to leave by, and what came in', () {
      final entry = ParkingHistoryEntry.fromJson({
        'logId': 'a',
        'entryTime': '2026-10-29T01:00:00Z',
        'paymentId': 'bill-a',
        'leaveBy': '2026-10-29T03:15:00Z',
        'vehicleType': 'Motorcycle',
      });

      expect(entry.leaveBy, DateTime.utc(2026, 10, 29, 3, 15));
      expect(entry.cameInOnMotorcycle, isTrue);
    });

    test('is paid to leave only until the time runs out', () {
      final entry = ParkingHistoryEntry(
        logId: 'a',
        entryTime: DateTime.utc(2026, 10, 29, 1),
        leaveBy: DateTime.utc(2026, 10, 29, 3, 15),
      );

      expect(entry.isPaidToLeave(now: DateTime.utc(2026, 10, 29, 3)), isTrue);
      expect(entry.isPaidToLeave(now: DateTime.utc(2026, 10, 29, 3, 20)), isFalse);
    });

    test('an unknown vehicle is not guessed', () {
      final entry = ParkingHistoryEntry.fromJson({
        'logId': 'a',
        'entryTime': '2026-10-29T01:00:00Z',
      });

      expect(entry.cameInOnMotorcycle, isNull);
      expect(entry.isPaidToLeave(), isFalse);
    });
  });

  group('PayAheadResult.fromJson', () {
    test('a bill to pay', () {
      final result = PayAheadResult.fromJson({
        'paymentId': 'bill-a',
        'amountDue': 60,
        'durationMinutes': 120,
        'paid': false,
      });

      expect(result.paymentId, 'bill-a');
      expect(result.amountDue, 60.0);
      expect(result.paid, isFalse);
    });

    test('already paid, with the time to leave by', () {
      final result = PayAheadResult.fromJson({
        'paymentId': null,
        'amountDue': 0,
        'paid': true,
        'leaveBy': '2026-10-29T03:15:00Z',
      });

      expect(result.paymentId, isNull);
      expect(result.paid, isTrue);
      expect(result.leaveBy, DateTime.utc(2026, 10, 29, 3, 15));
    });
  });

  group('ParkingSlot.takes', () {
    const car = ParkingSlot(slotId: '1', slotCode: 'C1', status: 'Available', vehicleType: 'Car');
    const moto = ParkingSlot(slotId: '2', slotCode: 'M1', status: 'Available', vehicleType: 'Motorcycle');
    const any = ParkingSlot(slotId: '3', slotCode: 'X1', status: 'Available');

    test('a bay only takes its own kind', () {
      expect(car.takes(motorcycle: true), isFalse);
      expect(car.takes(motorcycle: false), isTrue);
      expect(moto.takes(motorcycle: false), isFalse);
      expect(moto.takes(motorcycle: true), isTrue);
    });

    test('a bay with no kind set takes either', () {
      expect(any.takes(motorcycle: true), isTrue);
      expect(any.takes(motorcycle: false), isTrue);
    });
  });
}
