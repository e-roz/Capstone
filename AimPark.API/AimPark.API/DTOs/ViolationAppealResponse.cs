namespace AimPark.API.DTOs
{
    public class ViolationAppealListResponse
    {
        public List<ViolationAppealResponse> Appeals { get; set; } = [];
        public int TotalCount { get; set; }
        public int Page { get; set; }
        public int PageSize { get; set; }
    }

    public class ViolationAppealResponse
    {
        public Guid AppealId { get; set; }
        public Guid ViolationId { get; set; }
        public string ReasonText { get; set; } = string.Empty;
        public string Status { get; set; } = string.Empty;
        public string? AdminNotes { get; set; }
        public DateTime CreatedAt { get; set; }
        public DateTime? DecidedAt { get; set; }
    }
}
