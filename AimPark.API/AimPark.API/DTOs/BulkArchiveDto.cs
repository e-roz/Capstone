namespace AimPark.API.DTOs
{
    /// <summary>
    /// Archives many accounts at once, built for the end of a semester.
    /// </summary>
    /// <remarks>
    /// Two ways to say who: <see cref="UserIds"/> names them outright, which is
    /// what the panel sends after the administrator has looked at the preview;
    /// with none, the filters pick them. A preview (<see cref="DryRun"/>) never
    /// changes anything and needs no password.
    /// </remarks>
    public class BulkArchiveDto
    {
        public List<Guid> UserIds { get; set; } = [];

        /// <summary>"Student", "Faculty" or "Staff". Empty means everyone.</summary>
        public string? Affiliation { get; set; }

        /// <summary>
        /// Only accounts with no parking session or gate tap since this moment.
        /// An account that has never been used counts from the day it was made.
        /// </summary>
        public DateTime? InactiveBefore { get; set; }

        public bool DryRun { get; set; }

        /// <summary>Why, for the audit log. Required to archive.</summary>
        public string Reason { get; set; } = string.Empty;

        /// <summary>The acting administrator's password. Required to archive.</summary>
        public string Password { get; set; } = string.Empty;
    }

    public class BulkArchiveUser
    {
        public Guid UserId { get; set; }
        public string FullName { get; set; } = string.Empty;
        public string Email { get; set; } = string.Empty;
        public string Affiliation { get; set; } = string.Empty;
        public bool HasCard { get; set; }
        public DateTime LastActiveAt { get; set; }
    }

    public class BulkArchiveSkip
    {
        public Guid UserId { get; set; }
        public string FullName { get; set; } = string.Empty;
        public string Reason { get; set; } = string.Empty;
    }

    public class BulkArchiveResponse
    {
        public bool DryRun { get; set; }

        /// <summary>The accounts that are archived, or would be on a preview.</summary>
        public List<BulkArchiveUser> Users { get; set; } = [];

        public List<BulkArchiveSkip> Skipped { get; set; } = [];

        /// <summary>Cards handed back to the pool along the way. Zero on a preview.</summary>
        public int CardsRevoked { get; set; }
    }
}
