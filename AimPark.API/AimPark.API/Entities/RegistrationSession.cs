using AimPark.API.Enums;

namespace AimPark.API.Entities
{
    public class RegistrationSession
    {
        public Guid Id { get; set; }
        public string? PhoneNumber { get; set; }
        public bool IsPhoneVerified { get; set; }
        public string? Email { get; set; }
        public bool IsEmailVerified { get; set; }
        public string? OtpHash { get; set; }
        public OtpChannel LastOtpChannel { get; set; }
        public DateTime? OtpExpiresAt { get; set; }
        public int OtpAttempts { get; set; }
        public bool IsLocked { get; set; }
        public AuthProvider? PendingAuthProvider { get; set; }
        public string? PendingExternalProviderId { get; set; }
        public DateTime CreatedAt { get; set; }
        public DateTime ExpiresAt { get; set; }
    }
}
