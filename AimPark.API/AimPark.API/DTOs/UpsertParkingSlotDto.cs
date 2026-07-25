namespace AimPark.API.DTOs
{
    public class UpsertParkingSlotDto
    {
        public string SlotCode { get; set; } = string.Empty;
        public string? VehicleType { get; set; }
    }
}
