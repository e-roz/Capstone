namespace AimPark.API.Entities
{
    public class NotificationRead
    {
        public Guid Id { get; set; } = Guid.NewGuid();

        public Guid NotificationId { get; set; }
        public Notification Notification { get; set; } = null!;

        public Guid UserId { get; set; }
        public User User { get; set; } = null!;

        public DateTime ReadAt { get; set; } = DateTime.UtcNow;
    }
}
