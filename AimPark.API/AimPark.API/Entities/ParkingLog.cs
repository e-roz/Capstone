namespace AimPark.API.Entities
{
    public class ParkingLog
    {
        public Guid Id { get; set; } = Guid.NewGuid();

        /// <summary>
        /// The account this session belongs to, or null when it is a visitor's.
        /// </summary>
        /// <remarks>
        /// Nullable since visitor passes exist. Exactly one of this and
        /// <see cref="VisitorPassId"/> is set — a session always belongs to
        /// somebody, but not always to somebody with an account.
        ///
        /// Every query that counts a user's parking already filters on this, so
        /// visitor sessions drop out of streaks, history and points on their own
        /// and only occupancy — which asks about cars, not people — sees both.
        /// </remarks>
        public Guid? UserId { get; set; }
        public User? User { get; set; }

        /// <summary>The lent card this session was opened with, if any.</summary>
        public Guid? VisitorPassId { get; set; }
        public VisitorPass? VisitorPass { get; set; }

        //Foreign key to ParkingSlot (nullable — slot may not be tracked at log time)
        public Guid? SlotId { get; set; }
        public ParkingSlot? Slot { get; set; }

        public DateTime EntryTime { get; set; }
        public DateTime? ExitTime { get; set; }

        /// <summary>The camera reading this entry was checked against, if any.</summary>
        public Guid? AlprReadingId { get; set; }
        public AlprReading? AlprReading { get; set; }

        /// <summary>
        /// Denormalized copy of what was read, kept even if the AlprReading
        /// row is ever pruned — same reasoning as RfidCard.LastUserName.
        /// </summary>
        public string? AlprPlateNumber { get; set; }

        /// <summary>
        /// Null = no camera reading was available to check against. True =
        /// the read plate matched one registered to this card holder. False
        /// only reaches here via a guard's manual override — an automatic
        /// mismatch never becomes a ParkingLog row; see GateAccessAttempt.
        /// </summary>
        public bool? AlprMatched { get; set; }

        // Exactly one of these identifies who recorded the entry: a staff
        // account working the admin panel, or a gate device reporting a scan.
        public Guid? LoggedByUserId { get; set; }
        public Guid? LoggedByDeviceId { get; set; }

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    }
}
