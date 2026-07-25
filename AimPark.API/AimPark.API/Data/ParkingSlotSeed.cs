using AimPark.API.Entities;
using AimPark.API.Enums;

namespace AimPark.API.Data
{
    // Fixed seed data for the project's known physical scale: 20 parking slots.
    // Guids and timestamp are static so `dotnet ef migrations add` produces a stable diff.
    public static class ParkingSlotSeed
    {
        private static readonly DateTime SeedTimestamp = new(2026, 7, 23, 0, 0, 0, DateTimeKind.Utc);

        public static ParkingSlot[] GetSeedSlots()
        {
            var slots = new ParkingSlot[20];

            for (var i = 1; i <= 20; i++)
            {
                slots[i - 1] = new ParkingSlot
                {
                    Id = new Guid($"00000000-0000-0000-0000-{i:D12}"),
                    SlotCode = $"A{i}",
                    VehicleType = null,
                    Status = ParkingSlotStatus.Available,
                    CreatedAt = SeedTimestamp,
                    UpdatedAt = SeedTimestamp
                };
            }

            return slots;
        }
    }
}
