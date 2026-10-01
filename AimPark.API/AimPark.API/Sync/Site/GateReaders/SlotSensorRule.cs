using AimPark.API.Enums;

namespace AimPark.API.Sync.Site.GateReaders
{
    /// <summary>
    /// What a slot sensor's reading does to its <see cref="Entities.ParkingSlot"/>.
    /// </summary>
    /// <remarks>
    /// A car the sensor sees always makes the slot Occupied, allocated or not:
    /// a bay with a car in it must never be handed to the next driver.
    ///
    /// An empty reading frees the slot only when no open parking session holds
    /// it. The allocator claims a bay at the gate, before the car has driven
    /// to it; freeing it then would give the same bay to two drivers. The exit
    /// at the gate is what releases a session's bay, as it is for the manual
    /// status change in <see cref="Services.ParkingSlotService"/>.
    ///
    /// Out of service is the admin's call and the sensor never overrides it.
    /// A sensor that goes offline proves nothing either way, so it is never
    /// fed through here at all.
    /// </remarks>
    public static class SlotSensorRule
    {
        /// <returns>The status to set, or null to leave the slot as it is.</returns>
        public static ParkingSlotStatus? Next(ParkingSlotStatus current, bool occupied, bool heldBySession)
        {
            if (current == ParkingSlotStatus.OutOfService)
                return null;

            if (occupied)
                return current == ParkingSlotStatus.Occupied ? null : ParkingSlotStatus.Occupied;

            if (heldBySession)
                return null;

            return current == ParkingSlotStatus.Available ? null : ParkingSlotStatus.Available;
        }
    }
}
