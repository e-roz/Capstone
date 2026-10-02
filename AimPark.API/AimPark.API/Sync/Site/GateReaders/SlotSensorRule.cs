using AimPark.API.Enums;

namespace AimPark.API.Sync.Site.GateReaders
{
    /// <summary>
    /// What a slot sensor's reading does to its <see cref="Entities.ParkingSlot"/>.
    /// </summary>
    /// <remarks>
    /// The status of a bay with a sensor is what the sensor sees: a car makes
    /// it Occupied, an empty bay is Available — even one given to a driver at
    /// the gate. The bay given at the gate is only a recommendation; drivers
    /// park where they like. That a car is still inside the lot is counted by
    /// its open parking session, not by its bay (see
    /// <see cref="Services.ParkingCapacity"/>), and the allocator never offers
    /// a bay an open session was given.
    ///
    /// Out of service is the admin's call and the sensor never overrides it.
    /// A sensor that goes offline proves nothing either way, so it is never
    /// fed through here at all.
    /// </remarks>
    public static class SlotSensorRule
    {
        /// <returns>The status to set, or null to leave the slot as it is.</returns>
        public static ParkingSlotStatus? Next(ParkingSlotStatus current, bool occupied)
        {
            if (current == ParkingSlotStatus.OutOfService)
                return null;

            var seen = occupied ? ParkingSlotStatus.Occupied : ParkingSlotStatus.Available;
            return current == seen ? null : seen;
        }
    }
}
