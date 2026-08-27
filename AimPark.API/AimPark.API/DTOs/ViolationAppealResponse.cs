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

        /// <summary>
        /// The photos the user attached to the appeal.
        /// </summary>
        /// <remarks>
        /// The mobile app has shown these on the user's own violation detail
        /// since appeals were built, but the admin list they are decided from
        /// never carried them — so the one person whose job is to look at the
        /// evidence was the one person who could not. Signed URLs, generated
        /// per request like every other stored file.
        /// </remarks>
        public List<string> EvidenceUrls { get; set; } = [];
    }
}
