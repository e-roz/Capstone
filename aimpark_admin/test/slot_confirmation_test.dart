import 'package:aimpark_admin/widgets/slot_confirmation_pill.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final entry = DateTime.utc(2026, 10, 20, 1);
  final exit = entry.add(const Duration(hours: 1));

  test('no confirmation reads as unconfirmed', () {
    expect(SlotConfirmation.of(confirmedAt: null, exitTime: exit),
        SlotConfirmation.none);
  });

  test('confirming while inside is confirmed', () {
    expect(
      SlotConfirmation.of(
          confirmedAt: entry.add(const Duration(minutes: 5)), exitTime: null),
      SlotConfirmation.confirmed,
    );
    expect(
      SlotConfirmation.of(
          confirmedAt: entry.add(const Duration(minutes: 5)), exitTime: exit),
      SlotConfirmation.confirmed,
    );
  });

  test('confirming after leaving is late', () {
    expect(
      SlotConfirmation.of(
          confirmedAt: exit.add(const Duration(minutes: 30)), exitTime: exit),
      SlotConfirmation.late,
    );
  });
}
