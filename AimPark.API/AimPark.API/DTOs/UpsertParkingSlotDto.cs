namespace AimPark.API.DTOs
{
    public class UpsertParkingSlotDto
    {
        public string SlotCode { get; set; } = string.Empty;
        public string? VehicleType { get; set; }

        // Which gate this bay sits behind. Defaults to gate 1 when omitted.
        public int? Gate { get; set; }
    }
}
