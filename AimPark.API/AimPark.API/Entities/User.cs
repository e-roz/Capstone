using AimPark.API.Enums;
namespace AimPark.API.Entities
{
    public class User
    {
        public Guid Id { get; set; } = Guid.NewGuid();

        public string FullName { get; set; } = string.Empty;

        public string Email { get; set; } = string.Empty;

        public string PasswordHash { get; set; } = string.Empty;

        public UserRole Role { get; set; }

        public UserStatus Status { get; set; }

        //nullable - only filled when Status = "Rejected"
        public string? RejectionReason { get; set; }
        public bool IsFirstLogin { get; set; } = true;

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

    }
}
