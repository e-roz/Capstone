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
        public DateTime CreatedAt { get; set; }
        public DateTime? PaidAt { get; set; }
    }
}
