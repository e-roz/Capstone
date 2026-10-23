namespace AimPark.API.DTOs
{
    public class IncidentListResponse
    {
        public List<IncidentSummaryResponse> Incidents { get; set; } = [];
        public int TotalCount { get; set; }
        public int Page { get; set; }
        public int PageSize { get; set; }
    }

    public class IncidentSummaryResponse
    {
        public Guid IncidentId { get; set; }
        public string Category { get; set; } = string.Empty;
        public string Status { get; set; } = string.Empty;
        public DateTime CreatedAt { get; set; }

        /// <summary>Longest preview before the ellipsis is added.</summary>
        public const int PreviewLength = 80;

        /// <summary>
        /// The first ~80 characters of the description, trimmed, with "…" added
        /// when cut. Lets two reports in the same category be told apart.
        /// </summary>
        public string? DescriptionPreview { get; set; }

        /// <summary>The report's location text as stored; null if none.</summary>
        public string? Location { get; set; }

        public static string? Preview(string? description)
        {
            var text = description?.Trim();
            if (string.IsNullOrEmpty(text)) return null;
            return text.Length <= PreviewLength ? text : text[..PreviewLength].TrimEnd() + "…";
        }

        // Filled for the staff queue; the reporter's own list does not need them.
        public string? ReportedByName { get; set; }
        public string? ReportedByRole { get; set; }
        public DateTime? ReviewedAt { get; set; }

        // Staff queue only. The reporter's own list leaves these at zero/false:
        // Security's notes are between Security and the administrator.
        public int FollowUpCount { get; set; }
        public bool HasNewFollowUp { get; set; }
    }

    public class IncidentEvidenceItem
    {
        public string Url { get; set; } = string.Empty;
        public string FileName { get; set; } = string.Empty;
    }

    public class IncidentDetailResponse
    {
        public Guid IncidentId { get; set; }
        public string Category { get; set; } = string.Empty;
        public string Description { get; set; } = string.Empty;
        public string? Location { get; set; }

        /// <summary>The bay the reporter picked, and its code for display. Null when none.</summary>
        public Guid? SlotId { get; set; }
        public string? SlotCode { get; set; }

        public string Status { get; set; } = string.Empty;
        public string? AdminNotes { get; set; }
        public DateTime CreatedAt { get; set; }
        public DateTime UpdatedAt { get; set; }
        public List<string> EvidenceUrls { get; set; } = [];

        // Same files as EvidenceUrls plus the name each was uploaded with, so
        // the panel can show what kind of file it is. EvidenceUrls stays for
        // the mobile app.
        public List<IncidentEvidenceItem> Evidence { get; set; } = [];

        public string? ReportedByName { get; set; }
        public string? ReportedByRole { get; set; }
        public DateTime? ReviewedAt { get; set; }

        /// <summary>
        /// Attachments that exist but could not be opened just now — at the
        /// guard post with no internet, the files are out of reach. Zero
        /// everywhere else.
        /// </summary>
        public int EvidenceUnavailable { get; set; }

        /// <summary>
        /// What Security found out, oldest first. Filled for staff only; empty
        /// on the reporter's own copy of the report.
        /// </summary>
        public List<IncidentFollowUpItem> FollowUps { get; set; } = [];
    }
}
