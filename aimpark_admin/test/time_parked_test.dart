import 'package:aimpark_admin/widgets/parking/time_parked.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('minutes only under an hour', () {
    expect(formatStay(const Duration(minutes: 45, seconds: 59)), '45m');
  });

  test('hours and minutes', () {
    expect(formatStay(const Duration(hours: 1, minutes: 24)), '1h 24m');
  });

  test('days and hours past a day', () {
    expect(formatStay(const Duration(days: 2, hours: 3, minutes: 10)), '2d 3h');
  });

  test('a clock running behind never shows a negative time', () {
    expect(formatStay(const Duration(minutes: -3)), '0m');
  });
}
