import 'package:aimpark_admin/models/parking_slot.dart';
import 'package:aimpark_admin/models/cash_summary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ActiveParkingSession.fromJson', () {
    test('reads a driver waiting at the exit with their bill', () {
      final s = ActiveParkingSession.fromJson({
        'logId': 'l1',
        'userId': 'u1',
        'userName': 'Derek Dela Cruz',
        'plateNumber': 'C113TJ',
        'entryTime': '2026-10-26T01:00:00Z',
        'gate': 1,
        'paymentId': 'p1',
        'amountDue': 40,
        'paymentStatus': 'Pending',
        'waitingSince': '2026-10-26T03:10:00Z',
        'waitingToLeave': true,
      });

      expect(s.waitingToLeave, isTrue);
      expect(s.amountDue, 40.0);
      expect(s.paymentId, 'p1');
      expect(s.gate, 1);
      expect(s.waitingSince, DateTime.utc(2026, 10, 26, 3, 10));
    });

    test('a car simply parked has no bill and is not waiting', () {
      final s = ActiveParkingSession.fromJson({
        'logId': 'l2',
        'userId': 'u2',
        'userName': 'Ana Reyes',
        'entryTime': '2026-10-26T01:00:00Z',
      });

      expect(s.waitingToLeave, isFalse);
      expect(s.paymentId, isNull);
      expect(s.amountDue, isNull);
    });
  });

  group('CashSummary.fromJson', () {
    test('reads the day total and the signed-in guard\'s own', () {
      final c = CashSummary.fromJson({
        'total': 320,
        'count': 7,
        'mine': {'total': 100, 'count': 2},
      });

      expect(c.total, 320.0);
      expect(c.count, 7);
      expect(c.mineTotal, 100.0);
      expect(c.mineCount, 2);
    });

    test('copes with a response with no "mine"', () {
      final c = CashSummary.fromJson({'total': 0, 'count': 0});

      expect(c.mineTotal, 0.0);
      expect(c.mineCount, 0);
    });
  });
}
