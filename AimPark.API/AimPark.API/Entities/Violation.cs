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

        // Snapshot from the rule at issue time — admin-overridable, and later rule
        // changes never retroactively alter an already-issued violation.
        public decimal PenaltyAmount { get; set; }
        public SuspensionType SuspensionType { get; set; }
        public int? SuspensionDays { get; set; }

        public ViolationStatus Status { get; set; } = ViolationStatus.Issued;

        // Admin who issued this — no FK, audit-style reference
        public Guid IssuedByUserId { get; set; }

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
        public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
    }
}
