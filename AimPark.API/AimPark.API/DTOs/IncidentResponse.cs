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
    }
}
