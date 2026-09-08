using AimPark.API.Enums;

namespace AimPark.API.Entities
{
    /// <summary>
    /// A tap that should have opened the barrier but didn't, because ALPR
    /// disagreed or wasn't available to check.
    /// </summary>
    /// <remarks>
    /// Deliberately not a row in <see cref="ParkingLog"/>. That table's
    /// invariant, leaned on by occupancy counts, active-session lists and fee
    /// calculation, is "this vehicle actually got in" — a denied car never
    /// did. Only a granted or guard-overridden attempt writes to ParkingLog;
    /// this table is the record of everything that didn't make it there on
    /// its own.
    /// </remarks>
    public class GateAccessAttempt
    {
        public Guid Id { get; set; } = Guid.NewGuid();

        public int Gate { get; set; }

        public string RfidTagId { get; set; } = string.Empty;

        /// <summary>
        /// Whoever the tag resolved to — exactly one of these two, the same
        /// split ParkingLog uses between an account and a visitor pass.
        /// </summary>
        public Guid? UserId { get; set; }
        public User? User { get; set; }

        public Guid? VisitorPassId { get; set; }
        public VisitorPass? VisitorPass { get; set; }

        /// <summary>What the camera read, if anything arrived in time.</summary>
        public string? AlprPlateNumber { get; set; }
        public double? AlprConfidence { get; set; }

        public GateAccessOutcome Outcome { get; set; }

        /// <summary>Set once a guard has looked at this and made a call.</summary>
        public Guid? ReviewedByUserId { get; set; }
        public User? ReviewedByUser { get; set; }
        public DateTime? ReviewedAt { get; set; }

        /// <summary>
        /// Set if a guard overrode this and let the vehicle in — points at
        /// the ParkingLog row Gate Check created, so the attempt and the
        /// eventual entry stay traceable to each other.
        /// </summary>
        public Guid? ResultingLogId { get; set; }
        public ParkingLog? ResultingLog { get; set; }

        public DateTime AttemptedAt { get; set; } = DateTime.UtcNow;
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    }
}
