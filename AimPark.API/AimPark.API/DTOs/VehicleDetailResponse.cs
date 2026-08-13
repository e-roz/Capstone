namespace AimPark.API.DTOs
{
    public class VehicleDetailResponse
    {
        public Guid Id { get; set; }
        public string PlateNumber { get; set; } = string.Empty;
        public string VehicleType { get; set; } = string.Empty;
        public string Brand { get; set; } = string.Empty;
        public string Model { get; set; } = string.Empty;
        public string Color { get; set; } = string.Empty;

        // Null until pre-screening reads an Official Receipt for this vehicle.
        public DateTime? RegistrationValidThrough { get; set; }

        public DateTime CreatedAt { get; set; }
    }
}
