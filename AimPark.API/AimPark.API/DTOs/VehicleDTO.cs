namespace AimPark.API.DTOs
{
    public class VehicleDTO
    {
        public string PlateNumber{ get; set; } = string.Empty;
        public string VehicleType { get; set; } = string.Empty;

        public string Brand { get; set; } = string.Empty;
        public string Model { get; set; } = string.Empty;
        public string Color { get; set; } = string.Empty;
    }
}
