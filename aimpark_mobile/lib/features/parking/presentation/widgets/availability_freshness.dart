import '../../../../core/theme/theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../data/models/parking_slot.dart';

/// How much to trust the slot count on screen.
///
/// `parkingAvailability` is a plain auto-dispose future with no polling, and
/// the four tabs live in an `IndexedStack` that keeps every one of them alive.
/// So a user who opens Parking, wanders off and comes back is looking at
/// whatever the count was when they first arrived — possibly half an hour ago,
/// with no indication that anything has moved.
///
/// The freshness chip is a peer of the number, not a footnote: it changes
/// colour *and* wording together, so staleness survives being printed in
/// greyscale or read by someone who cannot separate amber from green.
enum AvailabilityFreshness {
  fresh,
  stale;

  /// Five minutes. A campus lot turns over fast enough that a count this old is
  /// worth a caveat, and slow enough that a chip flipping to amber inside a
  /// minute would just be noise.
  static const Duration _staleAfter = Duration(minutes: 5);

  static AvailabilityFreshness of(DateTime fetchedAt) {
    return DateTime.now().difference(fetchedAt) < _staleAfter ? fresh : stale;
  }

  StatusIntent get intent => switch (this) {
        AvailabilityFreshness.fresh => StatusIntent.success,
        AvailabilityFreshness.stale => StatusIntent.warning,
      };

  String label(DateTime fetchedAt) => switch (this) {
        AvailabilityFreshness.fresh => 'Updated just now',
        AvailabilityFreshness.stale =>
          'Last updated ${Formatters.relativeTime(fetchedAt)}',
      };
}

/// The per-vehicle-type breakdown of what is free, derived from the slot list.
///
/// The API returns slots, not counts, so this is the only place the split
/// exists. Anything that is not recognisably a motorcycle counts as a car —
/// the lot has two categories and an unlabelled slot is far more likely to be
/// a car bay than a third kind of thing.
extension AvailabilityBreakdown on ParkingAvailability {
  bool _isFree(ParkingSlot s) => s.status.toLowerCase() == 'available';

  bool _isMotorcycle(ParkingSlot s) =>
      (s.vehicleType ?? '').toLowerCase().contains('motor');

  int get freeMotorcycles =>
      slots.where((s) => _isFree(s) && _isMotorcycle(s)).length;

  int get freeCars => slots.where((s) => _isFree(s) && !_isMotorcycle(s)).length;

  bool get isLotFull => availableSlots <= 0;
}
