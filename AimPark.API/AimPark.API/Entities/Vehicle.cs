namespace AimPark.API.Entities
{
    public class Vehicle
    {
        public Guid Id { get; set; } = Guid.NewGuid();

        public string PlateNumber { get; set; } = string.Empty;

        //motor, 4 wheels
        public string VehicleType { get; set; } = string.Empty;

        public string Brand { get; set; } = string.Empty;

        public string Model { get; set; } = string.Empty;

        public string Color { get; set; } = string.Empty;

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        //Foreign key to User
        public Guid UserId { get; set; }
        public User User { get; set; } = null!;
    }
}
