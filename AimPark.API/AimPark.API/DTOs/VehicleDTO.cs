namespace AimPark.API.DTOs
{
    public class VehicleDTO
    {
        public string PlateNumber{ get; set; } = string.Empty;
        public string VehicleType { get; set; } = string.Empty;
        public string Color { get; set; } = string.Empty;
        public bool IsEBike { get; set; }

        /// <summary>The registration expiry on file now, which a renewal replaces.</summary>
        public DateTime? RegistrationValidThrough { get; set; }
        public string? Brand { get; set; }
        public string? DistinguishingMarks { get; set; }
    }
}
