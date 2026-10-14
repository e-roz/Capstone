namespace AimPark.API.DTOs
{
    public class VehicleDetailResponse
    {
        public Guid Id { get; set; }
        public string PlateNumber { get; set; } = string.Empty;
        public string VehicleType { get; set; } = string.Empty;
        public string Color { get; set; } = string.Empty;

        // Null until pre-screening reads an Official Receipt for this vehicle.
        public DateTime? RegistrationValidThrough { get; set; }

        /// <summary>An e-bike has no registration, so there is none to run out.</summary>
        public bool IsEBike { get; set; }

        public DateTime CreatedAt { get; set; }
    }
}
