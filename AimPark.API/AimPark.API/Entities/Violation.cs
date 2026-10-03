using AimPark.API.Enums;

namespace AimPark.API.Entities
{
    public class Violation
    {
        public Guid Id { get; set; } = Guid.NewGuid();

        //Foreign key to User
        public Guid UserId { get; set; }
        public User User { get; set; } = null!;

        //Foreign key to PolicyRule
        public Guid PolicyRuleId { get; set; }
        public PolicyRule PolicyRule { get; set; } = null!;

        //Foreign key to ParkingLog (nullable — the session it happened during, if any)
        public Guid? ParkingLogId { get; set; }
        public ParkingLog? ParkingLog { get; set; }

        public string Description { get; set; } = string.Empty;

        // Snapshot from the rule at issue time, so later rule changes never
        // retroactively alter an already-issued violation. Never overridden:
        // the rule is the penalty.
        public decimal PenaltyAmount { get; set; }
        public SuspensionType SuspensionType { get; set; }
        public int? SuspensionDays { get; set; }

        public ViolationStatus Status { get; set; } = ViolationStatus.Issued;

        // Admin who issued this — no FK, audit-style reference
        public Guid IssuedByUserId { get; set; }

        /// <summary>
        /// The card the user held when this was issued. Kept because the card
        /// can change — and the third strike takes it away — and the record
        /// should still say which card it was.
        /// </summary>
        public string? RfidTagIdAtIssue { get; set; }

        /// <summary>
        /// Last moment the user can appeal. If they have not by then, the
        /// violation becomes Accountable on its own.
        /// </summary>
        public DateTime AppealDeadline { get; set; }

        // When and why it became Accountable. AccountableByUserId is null when
        // the deadline lapsed — nobody pressed anything.
        public DateTime? AccountableAt { get; set; }
        public Guid? AccountableByUserId { get; set; }
        public string? AccountableReason { get; set; }

        public DateTime? DismissedAt { get; set; }
        public Guid? DismissedByUserId { get; set; }
        public string? DismissReason { get; set; }

        /// <summary>
        /// Set on the violation that was the user's third Accountable one and
        /// cost them their RFID card.
        /// </summary>
        public DateTime? RfidRevokedAt { get; set; }

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
        public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
    }
}
