namespace AimPark.API.DTOs
{
    public class UserListResponse
    {
        public List<UserSummaryResponse> Users { get; set; } = [];
        public int TotalCount { get; set; }
        public int Page { get; set; }
        public int PageSize { get; set; }
    }

    public class UserSummaryResponse
    {
        public Guid UserId { get; set; }
        public string FullName { get; set; } = string.Empty;
        public string Email { get; set; } = string.Empty;
        public string Role { get; set; } = string.Empty;
        public string AccountStatus { get; set; } = string.Empty;
        public string RfidStatus { get; set; } = string.Empty;

        // Added for the Users list's Card column. Additive: older clients ignore it.
        public string? RfidTagId { get; set; }
        public bool IsDeleted { get; set; }
        public DateTime CreatedAt { get; set; }
    }
}
