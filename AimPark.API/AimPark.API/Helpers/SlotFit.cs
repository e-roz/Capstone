using AimPark.API.Enums;

namespace AimPark.API.Helpers
{
    /// <summary>
    /// Whether a vehicle may occupy a given bay.
    /// </summary>
    /// <remarks>
    /// The automatic allocator already encodes this, but as a preference order
    /// rather than a yes or no — see <c>ParkingAllocationService.TiersFor</c>.
    /// The manual paths, where an admin names the slot themselves, had no check
    /// at all, so the panel would happily put a car in a motorcycle bay. The
    /// rule lives here so the two cannot drift apart.
    /// </remarks>
    public static class SlotFit
    {
        /// <summary>
        /// A bay with no type takes anything. Otherwise a vehicle needs its own
        /// kind of bay, except that a motorcycle also fits a four-wheel one —
        /// which is overflow, and <see cref="IsOverflow"/> is what tells the
        /// difference.
        /// </summary>
        public static bool Accepts(VehicleType? slotType, VehicleType vehicleType) =>
            slotType is null
            || slotType == vehicleType
            || (slotType == VehicleType.Car && vehicleType == VehicleType.Motorcycle);

        /// <summary>
        /// True when the only reason this fits is the motorcycle-into-a-car-bay
        /// fallback. The allocator takes it only once every motorcycle bay is
        /// gone, so a manual placement has to check the same thing or one admin
        /// eats the four scarce car bays while motorcycle bays sit empty.
        /// </summary>
        public static bool IsOverflow(VehicleType? slotType, VehicleType vehicleType) =>
            slotType == VehicleType.Car && vehicleType == VehicleType.Motorcycle;

        /// <summary>For error messages.</summary>
        public static string Describe(VehicleType? slotType) => slotType switch
        {
            null => "any vehicle",
            VehicleType.Motorcycle => "motorcycles",
            _ => "four-wheel vehicles",
        };
    }
}
