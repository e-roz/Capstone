using AimPark.API.Entities;
using AimPark.API.Enums;

namespace AimPark.API.Data
{
    // Fixed seed data for the physical model: 18 bays in two columns of nine
    // facing each other across the drive lane. Gate 1's bays are the left
    // column, with its three four-wheel bays at the top; Gate 2's are the right
    // column, with its three four-wheel bays at the bottom.
    //
    // Guids are kept from the original 20-bay seed so parking logs that already
    // reference a bay keep resolving. When the lot went from 20 bays to 18, the
    // eighth motorcycle bay at each gate (…010, …020) became that gate's third
    // four-wheel bay and the seventh (…009, …019) was removed. Guids and the
    // timestamp are static so `dotnet ef migrations add` produces a stable diff.
    public static class ParkingSlotSeed
    {
        private static readonly DateTime SeedTimestamp = new(2026, 7, 23, 0, 0, 0, DateTimeKind.Utc);

        public static ParkingSlot[] GetSeedSlots() =>
        [
            // Gate 1 — left column
            Build(1, 1, "G1-C1", VehicleType.Car),
            Build(2, 1, "G1-C2", VehicleType.Car),
            Build(10, 1, "G1-C3", VehicleType.Car),
            Build(3, 1, "G1-M1", VehicleType.Motorcycle),
            Build(4, 1, "G1-M2", VehicleType.Motorcycle),
            Build(5, 1, "G1-M3", VehicleType.Motorcycle),
            Build(6, 1, "G1-M4", VehicleType.Motorcycle),
            Build(7, 1, "G1-M5", VehicleType.Motorcycle),
            Build(8, 1, "G1-M6", VehicleType.Motorcycle),

            // Gate 2 — right column
            Build(13, 2, "G2-M1", VehicleType.Motorcycle),
            Build(14, 2, "G2-M2", VehicleType.Motorcycle),
            Build(15, 2, "G2-M3", VehicleType.Motorcycle),
            Build(16, 2, "G2-M4", VehicleType.Motorcycle),
            Build(17, 2, "G2-M5", VehicleType.Motorcycle),
            Build(18, 2, "G2-M6", VehicleType.Motorcycle),
            Build(11, 2, "G2-C1", VehicleType.Car),
            Build(12, 2, "G2-C2", VehicleType.Car),
            Build(20, 2, "G2-C3", VehicleType.Car),
        ];

        private static ParkingSlot Build(int index, int gate, string slotCode, VehicleType vehicleType) => new()
        {
            Id = new Guid($"00000000-0000-0000-0000-{index:D12}"),
            SlotCode = slotCode,
            Gate = gate,
            VehicleType = vehicleType,
            Status = ParkingSlotStatus.Available,
            CreatedAt = SeedTimestamp,
            UpdatedAt = SeedTimestamp
        };
    }
}
