namespace AimPark.API.Entities
{
    /// <summary>
    /// An FCM registration token for one install of the mobile app.
    /// A user can have several (multiple devices), and a device can change hands,
    /// so the token itself is the unique key — re-registering an existing token
    /// just re-points it at whoever is logged in now.
    /// </summary>
    public class DeviceToken
    {
        public Guid Id { get; set; } = Guid.NewGuid();

        //Foreign key to User
        public Guid UserId { get; set; }
        public User User { get; set; } = null!;

        public string Token { get; set; } = string.Empty;

        // "android" / "ios" — informational, useful when debugging delivery
        public string? Platform { get; set; }

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
        public DateTime LastSeenAt { get; set; } = DateTime.UtcNow;
    }
}
