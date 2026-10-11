import '../../data/models/parking_slot.dart';
import 'availability_freshness.dart';

/// How full the lot is, in the three words a driver actually decides on.
///
/// This is a product rule, not a measurement, and it is stated here so it is
/// stated once. The lot is *filling* once a fifth of its bays or fewer are free
/// — four of the eighteen, today. That is a judgement about when a person should
/// start to hurry; if the lot grows or the school wants a different warning
/// point, [fillingFraction] is the one number to change.
///
/// Based on the total only. Whether the *right kind* of bay is free for a
/// particular vehicle is a separate question, which Home answers beside this.
enum AvailabilityLevel {
  open,
  filling,
  full,

  /// The live feed has gone quiet, so the count cannot be trusted either way.
  paused;

  /// The share of bays at or under which the lot counts as filling.
  static const double fillingFraction = 0.2;

  static AvailabilityLevel of(ParkingAvailability availability) {
    if (availability.isPaused) return AvailabilityLevel.paused;
    if (availability.availableSlots <= 0) return AvailabilityLevel.full;
    final threshold = (availability.totalSlots * fillingFraction).ceil();
    return availability.availableSlots <= threshold
        ? AvailabilityLevel.filling
        : AvailabilityLevel.open;
  }

  /// The word on the card. A label as well as a colour, so the state survives
  /// greyscale and a screen reader.
  String get label => switch (this) {
        AvailabilityLevel.open => 'Open',
        AvailabilityLevel.filling => 'Filling up',
        AvailabilityLevel.full => 'Full',
        AvailabilityLevel.paused => 'Live updates paused',
      };
}
