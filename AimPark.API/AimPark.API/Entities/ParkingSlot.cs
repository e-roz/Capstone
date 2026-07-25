using AimPark.API.Enums;

namespace AimPark.API.Entities
{
    public class ParkingSlot
    {
        public Guid Id { get; set; } = Guid.NewGuid();

        public string SlotCode { get; set; } = string.Empty;

        // "Motor", "4 Wheels", null = any vehicle type
        public string? VehicleType { get; set; }

        public ParkingSlotStatus Status { get; set; } = ParkingSlotStatus.Available;

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
        public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
    }
}
