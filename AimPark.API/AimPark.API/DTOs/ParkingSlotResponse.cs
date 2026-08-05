namespace AimPark.API.DTOs
{
    public class ParkingAvailabilityResponse
    {
        public List<ParkingSlotResponse> Slots { get; set; } = [];
        public int TotalSlots { get; set; }
        public int AvailableSlots { get; set; }
    }

    public class ParkingSlotResponse
    {
        public Guid SlotId { get; set; }
        public string SlotCode { get; set; } = string.Empty;
        public int Gate { get; set; }
        public string? VehicleType { get; set; }
        public string Status { get; set; } = string.Empty;
    }
}
