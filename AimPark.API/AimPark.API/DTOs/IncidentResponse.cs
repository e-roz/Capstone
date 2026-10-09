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
    }

    public class IncidentDetailResponse
    {
        public Guid IncidentId { get; set; }
        public string Category { get; set; } = string.Empty;
        public string Description { get; set; } = string.Empty;
        public string? Location { get; set; }
        public string Status { get; set; } = string.Empty;
        public string? AdminNotes { get; set; }
        public DateTime CreatedAt { get; set; }
        public DateTime UpdatedAt { get; set; }
        public List<string> EvidenceUrls { get; set; } = [];

        /// <summary>
        /// Attachments that exist but could not be opened just now — at the
        /// guard post with no internet, the files are out of reach. Zero
        /// everywhere else.
        /// </summary>
        public int EvidenceUnavailable { get; set; }
    }
}
