namespace AimPark.API.DTOs
{
    public class ParkingRateResponse
    {
        public Guid RateId { get; set; }
        public string? VehicleType { get; set; }
        public decimal RatePerHour { get; set; }
        public decimal MinimumFee { get; set; }
        public DateTime UpdatedAt { get; set; }
    }
}
