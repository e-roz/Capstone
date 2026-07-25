using AimPark.API.Enums;

namespace AimPark.API.Entities
{
    public class ViolationAppeal
    {
        public Guid Id { get; set; } = Guid.NewGuid();

        //Foreign key to Violation (one appeal per violation)
        public Guid ViolationId { get; set; }
        public Violation Violation { get; set; } = null!;

        public string ReasonText { get; set; } = string.Empty;
        public AppealStatus Status { get; set; } = AppealStatus.Pending;
        public string? AdminNotes { get; set; }

        // Admin who decided this — no FK, audit-style reference
        public Guid? DecidedByUserId { get; set; }

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
        public DateTime? DecidedAt { get; set; }
    }
}
