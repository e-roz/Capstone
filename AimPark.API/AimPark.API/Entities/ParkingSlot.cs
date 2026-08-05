using AimPark.API.Enums;

namespace AimPark.API.Entities
{
    public class ParkingSlot
    {
        public Guid Id { get; set; } = Guid.NewGuid();

        public string SlotCode { get; set; } = string.Empty;

        // Which of the two entry gates this slot sits behind. Allocation steers
        // drivers to the gate with the most free capacity for their vehicle.
        public int Gate { get; set; } = 1;

        // null = any vehicle type
        public VehicleType? VehicleType { get; set; }

        public ParkingSlotStatus Status { get; set; } = ParkingSlotStatus.Available;

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
        public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
    }
}
