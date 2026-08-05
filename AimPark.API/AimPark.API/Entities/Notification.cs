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

        // Set when this notification is addressed to one person — a violation
        // issued against them, a fee raised, a registration decision. When set,
        // TargetRole is ignored and nobody else ever sees the row.
        //
        // Without this the table could only ever broadcast, which is why a user
        // was never told about their own violation and the appeal feature had
        // nothing to appeal against.
        public Guid? TargetUserId { get; set; }

        // Admin who broadcast this, or Guid.Empty when the system raised it
        // automatically — no FK, audit-style reference
        public Guid CreatedByUserId { get; set; }

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    }
}
