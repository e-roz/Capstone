namespace AimPark.API.DTOs
{
    public class ParkingAvailabilityResponse
    {
        public List<ParkingSlotResponse> Slots { get; set; } = [];
        public int TotalSlots { get; set; }

        /// <summary>
        /// Free bays: in-service bays less the cars inside the lot, not the
        /// green bays. See <see cref="Services.ParkingCapacity"/>.
        /// </summary>
        public int AvailableSlots { get; set; }

        public int AvailableCars { get; set; }
        public int AvailableMotorcycles { get; set; }
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
