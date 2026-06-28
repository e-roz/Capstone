using AimPark.API.Enums;

namespace AimPark.API.Entities
{
    public class User
    {
        public Guid Id { get; set; }
        public string FullName { get; set; } = string.Empty;

        public string Email { get; set; } = string.Empty;
        public bool IsEmailVerified { get; set; }

        public string? PhoneNumber { get; set; }
        public bool IsPhoneVerified { get; set; }

        public string? PasswordHash { get; set; }

        public AuthProvider AuthProvider { get; set; }
        public string? ExternalProviderId { get; set; }

        public UserRole Role { get; set; }
        public RegistrationStep RegistrationStep { get; set; }
        public AccountStatus AccountStatus { get; set; }

        public VerificationStatus VerificationStatus { get; set; }

        public string? RejectionReason { get; set; }
        public DateTime? RejectedAt { get; set; }
        public int RejectionCount { get; set; }
        public DateTime? CanReapplyAt { get; set; }

        public bool IsFirstLogin { get; set; } = true;
        public DateTime CreatedAt { get; set; }
        public DateTime UpdatedAt { get; set; }
    }
}
