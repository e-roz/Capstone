namespace AimPark.API.DTOs
{
    public class PendingRegistrationResponse
    {
        public Guid UserId { get; set; }
        public string FullName { get; set; } = string.Empty;
        public string Email { get; set; } = string.Empty;

        /// <summary>Student, Faculty, or Staff.</summary>
        public string Affiliation { get; set; } = string.Empty;
        public DateTime CreatedAt { get; set; }
        public DateTime UpdatedAt { get; set; }

        // ── What the checks found, so the queue can be triaged ────────────────
        //
        // Counts rather than the whole panel: the list shows hundreds of rows and
        // only needs to say which ones deserve time. The detail screen carries the
        // evidence itself.

        /// <summary>Clear, LookCloser, Unreadable, or None when nothing was submitted.</summary>
        public string ChecksVerdict { get; set; } = "None";

        /// <summary>Ready to render: "2 need attention", "All 6 passed".</summary>
        public string ChecksSummary { get; set; } = string.Empty;

        public int ChecksTotal { get; set; }
        public int ChecksNeedingAttention { get; set; }
        public int ChecksUnreadable { get; set; }

        /// <summary>
        /// The most serious flagged finding in words ("Name mismatch"), or null
        /// when nothing was flagged. Same wording as the review screen's first row.
        /// </summary>
        public string? TopFinding { get; set; }

        /// <summary>Danger, Warning, or Neutral — the tone of <see cref="TopFinding"/>.</summary>
        public string? TopFindingSeverity { get; set; }

        /// <summary>How many findings were flagged, <see cref="TopFinding"/> included.</summary>
        public int FlaggedCount { get; set; }

        /// <summary>Whole days since the applicant submitted. Nothing else says this.</summary>
        public int WaitingDays { get; set; }
    }
}
