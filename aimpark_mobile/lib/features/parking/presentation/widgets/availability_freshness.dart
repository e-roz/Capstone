import '../../../../core/theme/theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../data/models/parking_slot.dart';

/// How much to trust the slot count on screen.
///
/// The count polls every few seconds while the app is open, but a poll can
/// fail — no signal in the basement — and then the last count stays on
/// screen. Without a caveat that stale number reads as current.
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
/// Prefers the server's per-type counts; from a server too old to send them
/// it falls back to counting green bays. Anything that is not recognisably a
/// motorcycle counts as a car —
/// the lot has two categories and an unlabelled slot is far more likely to be
/// a car bay than a third kind of thing.
extension AvailabilityBreakdown on ParkingAvailability {
  bool _isFree(ParkingSlot s) => s.status.toLowerCase() == 'available';

  bool _isMotorcycle(ParkingSlot s) =>
      (s.vehicleType ?? '').toLowerCase().contains('motor');

  // The server's counts also leave out a green bay given to a car that is
  // still driving to it, which the slot list alone can't tell.
  int get freeMotorcycles =>
      availableMotorcycles ??
      slots.where((s) => _isFree(s) && _isMotorcycle(s)).length;

  int get freeCars =>
      availableCars ?? slots.where((s) => _isFree(s) && !_isMotorcycle(s)).length;

  bool get isLotFull => availableSlots <= 0;
}
