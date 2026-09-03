namespace AimPark.API.DTOs
{
    public class PaymentListResponse
    {
        public List<PaymentResponse> Payments { get; set; } = [];
        public int TotalCount { get; set; }
        public int Page { get; set; }
        public int PageSize { get; set; }
    }

    public class PaymentResponse
    {
        public Guid PaymentId { get; set; }
        public string Source { get; set; } = string.Empty;
        public Guid? ParkingLogId { get; set; }
        public Guid? ViolationId { get; set; }
        public string? SlotCode { get; set; }
        public DateTime? EntryTime { get; set; }
        public DateTime? ExitTime { get; set; }
        public int DurationMinutes { get; set; }
        public decimal RatePerHourApplied { get; set; }
        public decimal AmountDue { get; set; }
        public string Status { get; set; } = string.Empty;
        public DateTime? DueAt { get; set; }
        public DateTime CreatedAt { get; set; }
        public DateTime? PaidAt { get; set; }

        /// <summary>Cash, GCash, Maya or Card. Null while unpaid.</summary>
        public string? Method { get; set; }

        /// <summary>What the payer can quote when a payment is disputed.</summary>
        public string? ReferenceNumber { get; set; }

        /// <summary>Which provider handled it, or <c>Simulated</c>.</summary>
        public string? Provider { get; set; }

        /// <summary>
        /// The admin who took the money, on the payments no provider ever sees.
        /// </summary>
        /// <remarks>
        /// The answer to "who received this". Online money lands in the school's
        /// merchant account with a provider's record behind it; cash lands in
        /// somebody's hand, and this is the only thing that says whose.
        /// </remarks>
        public string? ConfirmedBy { get; set; }
    }

    /// <summary>Where to send the payer, once a checkout is open.</summary>
    public class CheckoutResponse
    {
        public Guid PaymentId { get; set; }

        /// <summary>Opened outside the app: the provider hosts this page, not us.</summary>
        public string CheckoutUrl { get; set; } = string.Empty;

        public string Provider { get; set; } = string.Empty;
        public decimal AmountDue { get; set; }
    }

    /// <summary>An admin recording money taken by hand.</summary>
    public class MarkPaidDto
    {
        /// <summary>Cash unless stated — the only method that reaches a person.</summary>
        public string? Method { get; set; }

        /// <summary>An OR number, or whatever the payer was given.</summary>
        public string? ReferenceNumber { get; set; }
    }
}
