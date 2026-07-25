using AimPark.API.Enums;

namespace AimPark.API.Entities
{
    public class Incident
    {
        public Guid Id { get; set; } = Guid.NewGuid();

        //Foreign key to User
        public Guid ReportedByUserId { get; set; }
        public User ReportedByUser { get; set; } = null!;

        public IncidentCategory Category { get; set; }
        public string Description { get; set; } = string.Empty;
        public string? Location { get; set; }

        public IncidentStatus Status { get; set; } = IncidentStatus.Submitted;
        public string? AdminNotes { get; set; }

        // Admin who reviewed this — no FK, audit-style reference
        public Guid? ReviewedByUserId { get; set; }

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
        public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
    }
}
