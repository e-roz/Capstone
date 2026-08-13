namespace AimPark.API.DTOs
{
    public class MyProfileResponse
    {
        public Guid UserId { get; set; }
        public string FullName { get; set; } = string.Empty;
        public string Email { get; set; } = string.Empty;
        public string Role { get; set; } = string.Empty;
        public string Affiliation { get; set; } = string.Empty;

        // Null for faculty and staff, who have no RAF — Affiliation is what makes
        // that readable rather than ambiguous.
        public string? StudentNumber { get; set; }
        public string? Section { get; set; }
        public DateTime? EnrollmentValidUntil { get; set; }

        public string AccountStatus { get; set; } = string.Empty;
        public DateTime CreatedAt { get; set; }
    }
}
