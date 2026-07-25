namespace AimPark.API.DTOs
{
    public class AuditLogListResponse
    {
        public List<AuditLogEntryResponse> Logs { get; set; } = [];
        public int TotalCount { get; set; }
        public int Page { get; set; }
        public int PageSize { get; set; }
    }

    public class AuditLogEntryResponse
    {
        public Guid Id { get; set; }
        public Guid AdminUserId { get; set; }
        public string AdminName { get; set; } = string.Empty;
        public Guid TargetUserId { get; set; }
        public string TargetName { get; set; } = string.Empty;
        public string Action { get; set; } = string.Empty;
        public string? OldValue { get; set; }
        public string? NewValue { get; set; }
        public string? Reason { get; set; }
        public DateTime CreatedAt { get; set; }
    }
}
