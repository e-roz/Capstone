namespace AimPark.API.Entities
{
    /// <summary>
    /// What Security found out about a report: who, where, which plate. Added
    /// to, never edited or removed, so the admin deciding it can trust the trail.
    /// The reporter never sees these.
    /// </summary>
    public class IncidentFollowUp
    {
        public Guid Id { get; set; } = Guid.NewGuid();

        //Foreign key to Incident
        public Guid IncidentId { get; set; }
        public Incident Incident { get; set; } = null!;

        // The guard who wrote it - no FK, audit-style reference like Incident.ReviewedByUserId
        public Guid AuthorUserId { get; set; }

        public string Note { get; set; } = string.Empty;

        // At most one photo or PDF per note. Stored under the incident-evidence/
        // prefix, the only place the guard post's server may write files.
        public string? AttachmentPath { get; set; }
        public string? AttachmentName { get; set; }

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        // Set in the cloud when an administrator opens the report, so the queue
        // can flag the ones with something they have not read yet.
        public DateTime? SeenByAdminAt { get; set; }
    }
}
