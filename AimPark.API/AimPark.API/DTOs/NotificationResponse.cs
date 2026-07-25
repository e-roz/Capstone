namespace AimPark.API.DTOs
{
    public class NotificationListResponse
    {
        public List<NotificationResponse> Notifications { get; set; } = [];
        public int TotalCount { get; set; }
        public int Page { get; set; }
        public int PageSize { get; set; }
        public int UnreadCount { get; set; }
    }

    public class NotificationResponse
    {
        public Guid NotificationId { get; set; }
        public string Title { get; set; } = string.Empty;
        public string Message { get; set; } = string.Empty;
        public string Type { get; set; } = string.Empty;
        public string? TargetRole { get; set; }
        public DateTime CreatedAt { get; set; }
        public bool IsRead { get; set; }
    }
}
