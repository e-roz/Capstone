using AimPark.API.Enums;

namespace AimPark.API.Entities
{
    public class Notification
    {
        public Guid Id { get; set; } = Guid.NewGuid();

        public string Title { get; set; } = string.Empty;
        public string Message { get; set; } = string.Empty;
        public NotificationType Type { get; set; }

        // null = all roles
        public UserRole? TargetRole { get; set; }

        // Admin who broadcast this — no FK, audit-style reference
        public Guid CreatedByUserId { get; set; }

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    }
}
