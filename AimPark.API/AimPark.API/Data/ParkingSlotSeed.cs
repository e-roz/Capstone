using AimPark.API.Entities;
using AimPark.API.Enums;

namespace AimPark.API.Data
{
    // Fixed seed data for the project's known physical scale: two entry gates,
    // ten slots each — 2 four-wheel and 8 motorcycle per gate.
    //
    // The 20 Guids are unchanged from the original A1–A20 seed so that parking
    // logs already referencing a slot keep resolving. Guids and timestamp are
    // static so `dotnet ef migrations add` produces a stable diff.
    public static class ParkingSlotSeed
    {
        private static readonly DateTime SeedTimestamp = new(2026, 7, 23, 0, 0, 0, DateTimeKind.Utc);

        private const int Gates = 2;
        private const int CarSlotsPerGate = 2;
        private const int MotorcycleSlotsPerGate = 8;

        public static ParkingSlot[] GetSeedSlots()
        {
            var slots = new List<ParkingSlot>();
            var index = 1;

            for (var gate = 1; gate <= Gates; gate++)
            {
                for (var i = 1; i <= CarSlotsPerGate; i++)
                    slots.Add(Build(index++, gate, $"G{gate}-C{i}", VehicleType.Car));

                for (var i = 1; i <= MotorcycleSlotsPerGate; i++)
                    slots.Add(Build(index++, gate, $"G{gate}-M{i}", VehicleType.Motorcycle));
            }

            return [.. slots];
        }

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
