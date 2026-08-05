namespace AimPark.API.DTOs
{
    public class ViolationListResponse
    {
        public List<ViolationSummaryResponse> Violations { get; set; } = [];
        public int TotalCount { get; set; }
        public int Page { get; set; }
        public int PageSize { get; set; }
    }

    public class ViolationSummaryResponse
    {
        public Guid ViolationId { get; set; }
        public string PolicyRuleTitle { get; set; } = string.Empty;
        public string Status { get; set; } = string.Empty;
        public decimal PenaltyAmount { get; set; }
        public string SuspensionType { get; set; } = string.Empty;
        public DateTime CreatedAt { get; set; }
    }

    public class ViolationDetailResponse
    {
        public Guid ViolationId { get; set; }
        public string PolicyRuleTitle { get; set; } = string.Empty;
        public string Description { get; set; } = string.Empty;
        public decimal PenaltyAmount { get; set; }
        public string SuspensionType { get; set; } = string.Empty;
        public int? SuspensionDays { get; set; }
        public string Status { get; set; } = string.Empty;
        public DateTime CreatedAt { get; set; }
        public DateTime UpdatedAt { get; set; }

        // Embedded appeal info, if one has been submitted
        public string? AppealStatus { get; set; }
        public string? AppealReasonText { get; set; }
        public string? AppealAdminNotes { get; set; }
        public DateTime? AppealDecidedAt { get; set; }

        /// <summary>Signed URLs for anything attached to the appeal.</summary>
        public List<string> AppealEvidenceUrls { get; set; } = [];
    }
}
