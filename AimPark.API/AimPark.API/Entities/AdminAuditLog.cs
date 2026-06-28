namespace AimPark.API.Entities
{
    public class AdminAuditLog
    {
        public Guid Id { get; set; }
        public Guid AdminUserId { get; set; }
        public Guid TargetUserId { get; set; }
        public string Action { get; set; } = string.Empty;
        public string? OldValue { get; set; }
        public string? NewValue { get; set; }
        public string? Reason { get; set; }
        public DateTime CreatedAt { get; set; }
    }
}
