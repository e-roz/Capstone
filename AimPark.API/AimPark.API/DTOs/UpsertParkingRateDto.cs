namespace AimPark.API.DTOs
{
    public class UpsertParkingRateDto
    {
        // null = the default/fallback rate
        public string? VehicleType { get; set; }
        public decimal RatePerHour { get; set; }
    }
}
