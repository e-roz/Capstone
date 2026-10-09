using AimPark.API.Enums;

namespace AimPark.API.Entities
{
    /// <summary>
    /// "There may be the wrong kind of vehicle in this bay", raised by the
    /// guard post when a bay's sensor fills. See <see cref="Helpers.WrongBayRule"/>.
    /// </summary>
    /// <remarks>
    /// A warning for a guard to check, not an accusation: the sensor cannot
    /// say who is in the bay. A violation, if any, is issued by a person.
    ///
    /// Raised at the guard post and reviewed there or in the cloud, so it is
    /// kept in step both ways, newer edit wins — like <see cref="Incident"/>.
    /// </remarks>
    public class WrongBayFlag
    {
        public Guid Id { get; set; } = Guid.NewGuid();

        public Guid SlotId { get; set; }
        public ParkingSlot Slot { get; set; } = null!;

        public DateTime DetectedAt { get; set; } = DateTime.UtcNow;

        public WrongBayFlagStatus Status { get; set; } = WrongBayFlagStatus.Open;

        // Who looked — no FK, audit-style reference, as on Incident.
        public Guid? ReviewedByUserId { get; set; }
        public DateTime? ReviewedAt { get; set; }

        /// <summary>When the bay read empty again. The warning stops showing then.</summary>
        public DateTime? BayClearedAt { get; set; }

        public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
    }
}
