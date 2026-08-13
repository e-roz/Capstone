using AimPark.API.Enums;

namespace AimPark.API.Entities
{
    public class Vehicle
    {
        public Guid Id { get; set; } = Guid.NewGuid();

        public string PlateNumber { get; set; } = string.Empty;

        public VehicleType VehicleType { get; set; }

        public string Brand { get; set; } = string.Empty;

        public string Model { get; set; } = string.Empty;

        public string Color { get; set; } = string.Empty;

        /// <summary>
        /// When this vehicle's registration runs out, worked out at enrolment from
        /// the plate's last digit and the receipt's year rather than read off the
        /// receipt's small print, which does not survive photography.
        /// </summary>
        public DateTime? RegistrationValidThrough { get; set; }

        /// <summary>
        /// 1–12, from the plate's last digit under the LTO's staggered renewal
        /// scheme. A property of the plate, so it stays true without re-reading
        /// anything — which is what makes lapse checking a query, not a job.
        /// </summary>
        public int? RegistrationRenewalMonth { get; set; }

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        // Foreign key to User. Many vehicles per user: one RFID card covers every
        // vehicle its holder has registered, and the gate matches the plate the
        // camera reads against any of them.
        public Guid UserId { get; set; }
        public User User { get; set; } = null!;
    }
}
