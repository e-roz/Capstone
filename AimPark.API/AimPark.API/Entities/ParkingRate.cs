namespace AimPark.API.Entities
{
    public class ParkingRate
    {
        public Guid Id { get; set; } = Guid.NewGuid();

        // null = default/fallback rate, applied when no vehicle-type-specific rate matches
        public string? VehicleType { get; set; }

        public decimal RatePerHour { get; set; }

        public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
    }
}
