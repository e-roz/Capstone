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

        /// <summary>
        /// On the real run: the people the preview had to skip. Saved with the
        /// run so the panel can later tell which of them have become clear.
        /// </summary>
        public List<Guid> LeftAloneUserIds { get; set; } = [];

        /// <summary>
        /// On the real run: archive the people left alone later, once they are
        /// clear and have stayed away from the lot. Off by default.
        /// </summary>
        public bool AutoArchive { get; set; }

        /// <summary>Days of notice before an auto-archive. Defaults to 7.</summary>
        public int? GraceDays { get; set; }

        /// <summary>When auto-archive stops. Defaults to 60 days after the run.</summary>
        public DateTime? AutoArchiveUntil { get; set; }
    }

    /// <summary>
    /// Turns a run's "archive when clear" on or off, or changes its grace
    /// period or end date. Fields left null keep their current value.
    /// </summary>
    public class BulkArchiveAutoSettingsDto
    {
        public bool? Enabled { get; set; }
        public int? GraceDays { get; set; }
        public DateTime? AutoArchiveUntil { get; set; }
    }

    /// <summary>A run's "archive when clear" settings as they stand.</summary>
    public class BulkArchiveAutoSettings
    {
        public bool Enabled { get; set; }
        public int GraceDays { get; set; }
        public DateTime? AutoArchiveUntil { get; set; }
        public DateTime? StoppedAt { get; set; }
    }

    /// <summary>One person on a run's "archive when clear" list.</summary>
    public class BulkArchivePendingItem
    {
        public Guid Id { get; set; }
        public Guid UserId { get; set; }
        public string FullName { get; set; } = string.Empty;
        public string Email { get; set; } = string.Empty;

        /// <summary>Waiting, Warned, Archived, Kept, Cancelled or Expired.</summary>
        public string State { get; set; } = string.Empty;

        public string? Note { get; set; }
        public DateTime? WarnedAt { get; set; }
        public DateTime? ArchiveAt { get; set; }
        public DateTime? ResolvedAt { get; set; }
    }

    /// <summary>
    /// The newest real bulk archive, with a fresh look at the people it left alone.
    /// </summary>
    public class BulkArchiveLastRunResponse
    {
        public Guid RunId { get; set; }

        public DateTime RanAt { get; set; }

        public string Reason { get; set; } = string.Empty;

        public BulkArchiveAutoSettings Auto { get; set; } = new();

        /// <summary>The run's "archive when clear" list. Empty when it was never turned on.</summary>
        public List<BulkArchivePendingItem> Pending { get; set; } = [];

        public int ArchivedCount { get; set; }

        /// <summary>How many were left alone at the time of the run.</summary>
        public int LeftAloneCount { get; set; }

        /// <summary>
        /// A preview over those people as they stand today: Users are now clear
        /// to archive, Skipped still are not (with today's reason).
        /// </summary>
        public BulkArchiveResponse Ready { get; set; } = new();
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
