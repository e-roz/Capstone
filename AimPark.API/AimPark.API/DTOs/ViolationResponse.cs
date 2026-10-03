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
        public Guid PolicyRuleId { get; set; }
        public string PolicyRuleTitle { get; set; } = string.Empty;

        // Who it was issued to — the admin table has to say whose violation
        // a row is without opening it.
        public Guid UserId { get; set; }
        public string UserFullName { get; set; } = string.Empty;
        public string? StudentNumber { get; set; }
        public string? RfidTagId { get; set; }

        /// <summary>Last moment the user can appeal; after it, Issued becomes Accountable.</summary>
        public DateTime AppealDeadline { get; set; }

        public string Status { get; set; } = string.Empty;
        public decimal PenaltyAmount { get; set; }
        public string SuspensionType { get; set; } = string.Empty;

        /// <summary>
        /// How long a Temporary suspension runs. Null for None and Permanent,
        /// where there is no length to state.
        /// </summary>
        /// <remarks>
        /// The list carried the type but not the length, so a row could say
        /// "Temporary" and leave the reviewer to open the violation to find out
        /// whether that meant three days or thirty.
        /// </remarks>
        public int? SuspensionDays { get; set; }

        public DateTime CreatedAt { get; set; }

        /// <summary>
        /// Settlement state of the penalty: Pending, Paid, Waived, or null when
        /// no transaction was ever raised.
        ///
        /// Separate from <see cref="Status"/> on purpose. Status is the appeal
        /// lifecycle and payment is the money, and a violation can be Accountable and
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
        public DateTime AppealDeadline { get; set; }

        /// <summary>The full rule as it stands now — its description is what the admin judges against.</summary>
        public PolicyRuleResponse? Rule { get; set; }

        // The user it was issued to.
        public Guid UserId { get; set; }
        public string UserFullName { get; set; } = string.Empty;
        public string? StudentNumber { get; set; }
        /// <summary>The card the user holds now. Null once revoked.</summary>
        public string? RfidTagId { get; set; }

        /// <summary>The card they held when this was issued.</summary>
        public string? RfidTagIdAtIssue { get; set; }
        public string? RfidStatus { get; set; }

        /// <summary>
        /// How many of this user's violations are Accountable. The third
        /// revokes their card, so the admin sees it before deciding.
        /// </summary>
        public int AccountableCount { get; set; }

        // Timeline. Every action keeps when it happened and, for admin
        // actions, who did it. The *Name fields are filled for admins only.
        public string? IssuedByName { get; set; }
        public DateTime? AccountableAt { get; set; }
        public string? AccountableReason { get; set; }
        public string? AccountableByName { get; set; }
        public DateTime? DismissedAt { get; set; }
        public string? DismissReason { get; set; }
        public string? DismissedByName { get; set; }
        public DateTime? RfidRevokedAt { get; set; }

        /// <inheritdoc cref="ViolationSummaryResponse.PaymentStatus"/>
        public string? PaymentStatus { get; set; }
        public DateTime? PaidAt { get; set; }
        public decimal? AmountDue { get; set; }
        public DateTime? PaymentDueAt { get; set; }
        public Guid? PaymentId { get; set; }

        // Embedded appeal info, if one has been submitted
        public Guid? AppealId { get; set; }
        public DateTime? AppealCreatedAt { get; set; }
        public string? AppealDecidedByName { get; set; }
        public string? AppealStatus { get; set; }
        public string? AppealReasonText { get; set; }
        public string? AppealAdminNotes { get; set; }
        public DateTime? AppealDecidedAt { get; set; }

        /// <summary>Signed URLs for anything attached to the appeal.</summary>
        public List<string> AppealEvidenceUrls { get; set; } = [];
    }
}
