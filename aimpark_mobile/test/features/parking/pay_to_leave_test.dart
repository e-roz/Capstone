import 'package:aimpark_mobile/core/services/push_navigation.dart';
import 'package:aimpark_mobile/features/parking/data/models/parking_history_entry.dart';
import 'package:flutter_test/flutter_test.dart';

ParkingHistoryEntry _log(
  String id, {
  DateTime? exit,
  bool waiting = false,
  double? amount,
}) => ParkingHistoryEntry(
  logId: id,
  entryTime: DateTime(2026, 10, 26, 9),
  exitTime: exit,
  waitingToLeave: waiting,
  exitAmountDue: amount,
  paymentId: waiting ? 'bill-$id' : null,
);

void main() {
  group('ParkingHistoryEntry.fromJson', () {
    test('reads that the driver is held at the exit and what they owe', () {
      final entry = ParkingHistoryEntry.fromJson({
        'logId': 'a',
        'entryTime': '2026-10-26T01:00:00Z',
        'paymentId': 'bill-a',
        'waitingToLeave': true,
        'exitAmountDue': 40,
      });

      expect(entry.waitingToLeave, isTrue);
      expect(entry.exitAmountDue, 40.0);
      expect(entry.paymentId, 'bill-a');
    });

    test('an ordinary session is not waiting to leave', () {
      final entry = ParkingHistoryEntry.fromJson({
        'logId': 'a',
        'entryTime': '2026-10-26T01:00:00Z',
      });

      expect(entry.waitingToLeave, isFalse);
      expect(entry.exitAmountDue, isNull);
    });
  });

  group('ParkingHistoryResult.waitingToLeave', () {
    ParkingHistoryResult result(List<ParkingHistoryEntry> logs) =>
        ParkingHistoryResult(logs: logs, totalCount: logs.length);

    test('finds the open session held at the barrier', () {
      final held = _log('held', waiting: true, amount: 60);

      expect(result([held, _log('old', exit: DateTime(2026, 10, 25))]).waitingToLeave, held);
    });

    test('is null when nobody is held', () {
      expect(result([_log('parked')]).waitingToLeave, isNull);
    });

    test('a finished session is never waiting, even if flagged', () {
      final done = _log('done', exit: DateTime(2026, 10, 26, 11), waiting: true, amount: 60);

      expect(result([done]).waitingToLeave, isNull);
    });
  });

  test('the "Pay to leave" push opens that bill', () {
    expect(
      routeForPush({'paymentId': 'bill-a'}),
      '/home/user/payments/bill-a',
    );
  });
}
