import '../../parking/data/models/parking_history_entry.dart';
import '../../vehicles/data/models/vehicle.dart';

/// What the Home screen's vehicle card should say about one vehicle.
///
/// There's no VehicleId column on a parking log (see
/// ParkingHistoryService.cs's remarks on ParkingLog for why) — the server
/// works out attribution from the ALPR-confirmed plate at read time, which
/// means a session can come back genuinely unattributed. That's a real,
/// expected outcome rather than missing data, so it gets its own case
/// ([VehicleUnconfirmed]) instead of being folded into "not parked".
sealed class VehicleStatus {
  const VehicleStatus();
}

/// This vehicle is inside the lot right now.
class VehicleParked extends VehicleStatus {
  const VehicleParked(this.entry);
  final ParkingHistoryEntry entry;
}

/// The account has an open session, but it couldn't be tied to any specific
/// vehicle — only possible with 2+ vehicles on the account and a manually
/// logged entry (no camera reading to match against).
class VehicleUnconfirmed extends VehicleStatus {
  const VehicleUnconfirmed(this.entry);
  final ParkingHistoryEntry entry;
}

/// Not currently parked, but has visited before.
class VehicleAway extends VehicleStatus {
  const VehicleAway(this.lastSeen);
  final DateTime lastSeen;
}

/// No attributed session has ever been recorded for this vehicle.
class VehicleNeverSeen extends VehicleStatus {
  const VehicleNeverSeen();
}

abstract final class VehicleStatusResolver {
  VehicleStatusResolver._();

  /// Decides what the card should show for [vehicle].
  ///
  /// [accountOpenSession] is the account-wide open session, if any (from
  /// `parkingHistoryNotifierProvider`'s `currentlyParked`). [latestForVehicle]
  /// is that same vehicle's own most recent session (from
  /// `vehicleLatestSessionProvider`) — kept separate because the two requests
  /// can land a moment apart, and the vehicle's own lookup is what's actually
  /// authoritative for *this* vehicle.
  static VehicleStatus resolve({
    required Vehicle vehicle,
    required int vehicleCount,
    required ParkingHistoryEntry? accountOpenSession,
    required ParkingHistoryEntry? latestForVehicle,
  }) {
    if (accountOpenSession != null && accountOpenSession.vehicleId == vehicle.id) {
      return VehicleParked(accountOpenSession);
    }

    if (accountOpenSession != null &&
        accountOpenSession.vehicleId == null &&
        vehicleCount > 1) {
      return VehicleUnconfirmed(accountOpenSession);
    }

    // Covers a race between the two requests: the account-wide lookup may not
    // have caught this vehicle's just-opened session yet.
    if (latestForVehicle != null && latestForVehicle.isOpen) {
      return VehicleParked(latestForVehicle);
    }

    if (latestForVehicle != null) {
      return VehicleAway(latestForVehicle.exitTime ?? latestForVehicle.entryTime);
    }

    return const VehicleNeverSeen();
  }

  /// Which vehicle the card should show by default.
  ///
  /// There's no stored "primary vehicle" concept on this account, so this
  /// picks, in order: the explicitly [selectedId] if it still exists on the
  /// account; otherwise whichever vehicle the most recent *attributed* log in
  /// [recentLogs] belongs to (i.e. whichever car was actually driven last);
  /// otherwise the first vehicle on the account. Null only when there are no
  /// vehicles at all.
  static Vehicle? pickVehicle(
    List<Vehicle> vehicles,
    String? selectedId,
    List<ParkingHistoryEntry> recentLogs,
  ) {
    if (vehicles.isEmpty) return null;

    if (selectedId != null) {
      for (final vehicle in vehicles) {
        if (vehicle.id == selectedId) return vehicle;
      }
    }

    for (final log in recentLogs) {
      final vehicleId = log.vehicleId;
      if (vehicleId == null) continue;
      for (final vehicle in vehicles) {
        if (vehicle.id == vehicleId) return vehicle;
      }
    }

    return vehicles.first;
  }
}
