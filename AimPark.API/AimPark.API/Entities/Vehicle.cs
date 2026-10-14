using AimPark.API.Enums;

namespace AimPark.API.Entities
{
    public class Vehicle
    {
        public Guid Id { get; set; } = Guid.NewGuid();

        public string PlateNumber { get; set; } = string.Empty;

        public VehicleType VehicleType { get; set; }

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

        /// <summary>
        /// The <see cref="RegistrationValidThrough"/> the last "expiring soon" push
        /// was sent for. See <see cref="User.LicenseExpiryReminderSentFor"/>.
        /// </summary>
        public DateTime? RegistrationExpiryReminderSentFor { get; set; }

        /// <summary>
        /// An e-bike: not LTO-registered, so it has no real plate or receipt.
        /// <see cref="PlateNumber"/> then holds the temporary plate an admin issues
        /// at the in-person inspection, and <see cref="VehicleType"/> holds the size
        /// class the admin chose (Motorcycle = fits a motorcycle bay, Car = needs a
        /// car bay) so slot allocation needs no special case.
        /// </summary>
        public bool IsEBike { get; set; }

        /// <summary>Make of an e-bike, noted at inspection. With the colour and marks
        /// this stands in for the receipt as the e-bike's identity.</summary>
        public string? Brand { get; set; }

        /// <summary>Anything that tells this e-bike apart, e.g. "red sticker on left fender".</summary>
        public string? DistinguishingMarks { get; set; }

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        // Foreign key to User. Many vehicles per user: one RFID card covers every
        // vehicle its holder has registered, and the gate matches the plate the
        // camera reads against any of them.
        public Guid UserId { get; set; }
        public User User { get; set; } = null!;
    }
}
