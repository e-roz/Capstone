import 'package:flutter_test/flutter_test.dart';

import 'package:aimpark_mobile/features/dashboard/domain/vehicle_status.dart';
import 'package:aimpark_mobile/features/parking/data/models/parking_history_entry.dart';
import 'package:aimpark_mobile/features/vehicles/data/models/vehicle.dart';

Vehicle _vehicle(String id, {String plate = 'ABC123'}) => Vehicle(
      id: id,
      plateNumber: plate,
      vehicleType: 'Car',
      color: 'White',
      createdAt: DateTime(2026, 1, 1),
    );

ParkingHistoryEntry _entry({
  String logId = 'log-1',
  DateTime? entryTime,
  DateTime? exitTime,
  String? vehicleId,
}) =>
    ParkingHistoryEntry(
      logId: logId,
      entryTime: entryTime ?? DateTime(2026, 1, 1, 8),
      exitTime: exitTime,
      vehicleId: vehicleId,
    );

void main() {
  group('VehicleStatusResolver.resolve', () {
    test('parked when the account-wide open session belongs to this vehicle', () {
      final vehicle = _vehicle('v1');
      final session = _entry(vehicleId: 'v1');

      final status = VehicleStatusResolver.resolve(
        vehicle: vehicle,
        vehicleCount: 1,
        accountOpenSession: session,
        latestForVehicle: null,
      );

      expect(status, isA<VehicleParked>());
      expect((status as VehicleParked).entry, session);
    });

    test('unconfirmed when the open session has no vehicle and there are 2+ vehicles', () {
      final vehicle = _vehicle('v1');
      final session = _entry();

      final status = VehicleStatusResolver.resolve(
        vehicle: vehicle,
        vehicleCount: 2,
        accountOpenSession: session,
        latestForVehicle: null,
      );

      expect(status, isA<VehicleUnconfirmed>());
    });

    test('parked when only the vehicle-specific lookup shows it open (race with account lookup)', () {
      final vehicle = _vehicle('v1');
      final latest = _entry(vehicleId: 'v1');

      final status = VehicleStatusResolver.resolve(
        vehicle: vehicle,
        vehicleCount: 1,
        accountOpenSession: null,
        latestForVehicle: latest,
      );

      expect(status, isA<VehicleParked>());
    });

    test('away with the exit time when the latest session is closed', () {
      final vehicle = _vehicle('v1');
      final exitTime = DateTime(2026, 1, 2, 9);
      final latest = _entry(exitTime: exitTime, vehicleId: 'v1');

      final status = VehicleStatusResolver.resolve(
        vehicle: vehicle,
        vehicleCount: 1,
        accountOpenSession: null,
        latestForVehicle: latest,
      );

      expect(status, isA<VehicleAway>());
      expect((status as VehicleAway).lastSeen, exitTime);
    });

    test('never seen when there is no session at all for this vehicle', () {
      final vehicle = _vehicle('v1');

      final status = VehicleStatusResolver.resolve(
        vehicle: vehicle,
        vehicleCount: 1,
        accountOpenSession: null,
        latestForVehicle: null,
      );

      expect(status, isA<VehicleNeverSeen>());
    });
  });

  group('VehicleStatusResolver.pickVehicle', () {
    test('returns null when there are no vehicles', () {
      expect(VehicleStatusResolver.pickVehicle([], null, []), isNull);
    });

    test('prefers the explicitly selected vehicle if it still exists', () {
      final a = _vehicle('a');
      final b = _vehicle('b');

      final picked = VehicleStatusResolver.pickVehicle([a, b], 'b', []);

      expect(picked, b);
    });

    test('falls back to the most recently driven vehicle when selection is gone', () {
      final a = _vehicle('a');
      final b = _vehicle('b');
      final logs = [_entry(vehicleId: 'b'), _entry(vehicleId: 'a')];

      // 'c' no longer exists on the account.
      final picked = VehicleStatusResolver.pickVehicle([a, b], 'c', logs);

      expect(picked, b);
    });

    test('skips unattributed logs when picking the most recently driven vehicle', () {
      final a = _vehicle('a');
      final b = _vehicle('b');
      final logs = [_entry(vehicleId: null), _entry(vehicleId: 'b')];

      final picked = VehicleStatusResolver.pickVehicle([a, b], null, logs);

      expect(picked, b);
    });

    test('falls back to the first vehicle when nothing else applies', () {
      final a = _vehicle('a');
      final b = _vehicle('b');

      final picked = VehicleStatusResolver.pickVehicle([a, b], null, []);

      expect(picked, a);
    });
  });
}
