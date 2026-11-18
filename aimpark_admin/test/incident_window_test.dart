import 'package:aimpark_admin/core/utils/incident_window.dart';
import 'package:flutter_test/flutter_test.dart';

/// Manila wall time, as the UTC instant the server sends.
DateTime manilaAt(int day, int hour, [int minute = 0]) =>
    DateTime.utc(2026, 11, day, hour, minute).subtract(const Duration(hours: 8));

void main() {
  test('an afternoon report looks back to midnight', () {
    expect(incidentWindowStart(manilaAt(18, 15)), manilaAt(18, 0));
  });

  test('a report just after midnight still reaches the evening before', () {
    expect(incidentWindowStart(manilaAt(18, 0, 30)), manilaAt(17, 18, 30));
  });
}
