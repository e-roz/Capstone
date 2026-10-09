using AimPark.API.Enums;

namespace AimPark.API.Helpers
{
    /// <summary>
    /// Whether a bay that just filled probably holds the wrong kind of vehicle:
    /// a motorcycle in a four-wheel bay, or a car in a motorcycle bay.
    /// </summary>
    /// <remarks>
    /// The sensor only says "something is here", never who. So this does not
    /// accuse anybody; it raises a warning for a guard to walk over and check.
    /// Two ways to get there:
    ///
    /// - By count, which is sure: more bays of this type are taken than there
    ///   are vehicles inside that belong in them. Something else is in one.
    /// - By timing, which is a good guess: a vehicle of the other type came in
    ///   in the last few minutes and has not reached the bay it was given,
    ///   and no vehicle of this type is on its way to a bay.
    ///
    /// A different bay of the right type is never a warning: the bay given at
    /// the gate is only a suggestion. Nor is a motorcycle in a four-wheel bay
    /// once every motorcycle bay is taken, which is the overflow
    /// <see cref="SlotFit"/> allows.
    /// </remarks>
    public static class WrongBayRule
    {
        /// <summary>How long after entry a vehicle counts as still looking for its bay.</summary>
        public static readonly TimeSpan StillParking = TimeSpan.FromMinutes(10);

        public readonly record struct Bay(Guid Id, VehicleType? Type, ParkingSlotStatus Status);

        /// <param name="Type">Null when it could not be told: a holder of both kinds, with no plate read.</param>
        /// <param name="GivenBayId">The bay the gate suggested, if it gave one.</param>
        public readonly record struct Session(VehicleType? Type, Guid? GivenBayId, DateTime EntryTime);

        /// <param name="filled">The bay whose sensor just read Occupied.</param>
        /// <param name="bays">Every bay, <paramref name="filled"/> included.</param>
        /// <param name="inside">Every open session.</param>
        public static bool ShouldWarn(Bay filled, IReadOnlyList<Bay> bays, IReadOnlyList<Session> inside, DateTime now)
        {
            if (filled.Type is not VehicleType bayType)
                return false; // Takes any vehicle.

            if (bayType == VehicleType.Car
                && !bays.Any(b => b.Type == VehicleType.Motorcycle && b.Status == ParkingSlotStatus.Available))
                return false; // Motorcycle overflow is allowed.

            var byId = bays.ToDictionary(b => b.Id);
            VehicleType? GivenType(Session s) =>
                s.GivenBayId is Guid id && byId.TryGetValue(id, out var b) ? b.Type : null;

            // Unknown counts as belonging, so a guess never tips the count.
            // So does a motorcycle the gate itself sent to a car bay.
            bool Belongs(Session s) => s.Type is null || s.Type == bayType || GivenType(s) == bayType;

            var taken = bays.Count(b => b.Type == bayType && b.Status == ParkingSlotStatus.Occupied);
            if (taken > inside.Count(Belongs))
                return true;

            // Still looking for a bay: came in lately and is not in the one it
            // was given. A given bay without a sensor reads Occupied from the
            // moment it is given, so that vehicle counts as parked.
            var parking = inside
                .Where(s => now - s.EntryTime <= StillParking
                         && !(s.GivenBayId is Guid id && byId.TryGetValue(id, out var b) && b.Status == ParkingSlotStatus.Occupied))
                .ToList();

            return parking.Any(s => !Belongs(s)) && !parking.Any(Belongs);
        }
    }
}
