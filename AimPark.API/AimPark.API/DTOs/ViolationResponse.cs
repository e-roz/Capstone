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

        /// <summary>
        /// Settlement state of the penalty: Pending, Paid, Waived, or null when
        /// no transaction was ever raised.
        ///
        /// Separate from <see cref="Status"/> on purpose. Status is the appeal
        /// lifecycle and payment is the money, and a violation can be Upheld and
        /// paid at the same time — folding one into the other would lose whichever
        /// half was written second.
        /// </summary>
        public string? PaymentStatus { get; set; }
        public DateTime? PaidAt { get; set; }
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

        /// <inheritdoc cref="ViolationSummaryResponse.PaymentStatus"/>
        public string? PaymentStatus { get; set; }
        public DateTime? PaidAt { get; set; }
        public decimal? AmountDue { get; set; }
        public DateTime? PaymentDueAt { get; set; }
        public Guid? PaymentId { get; set; }

        // Embedded appeal info, if one has been submitted
        public string? AppealStatus { get; set; }
        public string? AppealReasonText { get; set; }
        public string? AppealAdminNotes { get; set; }
        public DateTime? AppealDecidedAt { get; set; }

        /// <summary>Signed URLs for anything attached to the appeal.</summary>
        public List<string> AppealEvidenceUrls { get; set; } = [];
    }
}
