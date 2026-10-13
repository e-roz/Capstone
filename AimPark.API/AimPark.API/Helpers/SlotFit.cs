using AimPark.API.Enums;

namespace AimPark.API.Helpers
{
    /// <summary>
    /// Whether a vehicle may occupy a given bay.
    /// </summary>
    /// <remarks>
    /// There is no overflow: a full set of motorcycle bays means no more
    /// motorcycles, and a full set of car bays means no more cars. The
    /// automatic allocator (<c>ParkingAllocationService</c>) and the manual
    /// paths, where an admin names the slot themselves, both follow this rule.
    /// </remarks>
    public static class SlotFit
    {
        /// <summary>
        /// A bay with no type takes anything. Otherwise a vehicle needs its own
        /// kind of bay.
        /// </summary>
        public static bool Accepts(VehicleType? slotType, VehicleType vehicleType) =>
            slotType is null || slotType == vehicleType;

        /// <summary>For error messages.</summary>
        public static string Describe(VehicleType? slotType) => slotType switch
        {
            null => "any vehicle",
            VehicleType.Motorcycle => "motorcycles",
            _ => "four-wheel vehicles",
        };
    }
}
