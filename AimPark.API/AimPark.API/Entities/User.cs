namespace AimPark.API.Entities
{
    public class User
    {
        public Guid Id { get; set; }

        public string FullName { get; set; } = string.Empty;

        public string Email { get; set; } = string.Empty;

        public string PasswordHash { get; set; } = string.Empty;

        //admin, security, user
        public string Role { get; set; } = string.Empty;

        //incomplete, pending, approved, rejected, suspended
        public string Status { get; set; } = string.Empty;

        //nullable - only filled when Status = "Rejected"
        public string? RejectionReason { get; set; }
        public bool IsFirstLogin { get; set; } = true;

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

    }
}
