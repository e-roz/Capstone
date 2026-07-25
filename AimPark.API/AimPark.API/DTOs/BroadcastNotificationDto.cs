namespace AimPark.API.DTOs
{
    public class BroadcastNotificationDto
    {
        public string Title { get; set; } = string.Empty;
        public string Message { get; set; } = string.Empty;
        public string Type { get; set; } = string.Empty;

        // null/omitted = all roles
        public string? TargetRole { get; set; }
    }
}
