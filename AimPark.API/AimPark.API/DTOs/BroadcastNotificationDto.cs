namespace AimPark.API.DTOs
{
    public class BroadcastNotificationDto
    {
        public string Title { get; set; } = string.Empty;
        public string Message { get; set; } = string.Empty;

        // Announcement or PolicyUpdate. A broadcast always reaches everyone.
        public string Type { get; set; } = string.Empty;
    }
}
