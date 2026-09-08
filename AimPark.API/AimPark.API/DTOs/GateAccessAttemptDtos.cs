namespace AimPark.API.DTOs
{
    /// <summary>
    /// A tap the automatic gate path turned away, for the guard's "needs a
    /// look" queue.
    /// </summary>
    public class GateAccessAttemptResponse
    {
        public Guid Id { get; set; }
        public int Gate { get; set; }
        public string RfidTagId { get; set; } = string.Empty;

        /// <summary>"User", "Visitor", or "Unknown" — mirrors TagLookupResponse.Holder.</summary>
        public string Holder { get; set; } = "Unknown";
        public string? HolderName { get; set; }

        /// <summary>"PLATE_MISMATCH" or "ALPR_UNAVAILABLE" — see AllocationResult.</summary>
        public string Outcome { get; set; } = string.Empty;

        public string? AlprPlateNumber { get; set; }
        public double? AlprConfidence { get; set; }

        public DateTime AttemptedAt { get; set; }

        public bool IsReviewed { get; set; }
        public string? ReviewedByName { get; set; }
        public DateTime? ReviewedAt { get; set; }
        public bool WasOverridden { get; set; }
    }

    public class GateAccessAttemptListResponse
    {
        public List<GateAccessAttemptResponse> Items { get; set; } = [];
        public int Page { get; set; }
        public int PageSize { get; set; }
        public int TotalCount { get; set; }
    }
}
