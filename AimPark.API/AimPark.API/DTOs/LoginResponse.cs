namespace AimPark.API.DTOs
{
    public class LoginResponse
    {
        public string Message { get; set; } = string.Empty;
        public string? Token { get; set; }
        public string? Role { get; set; }
        public string? FullName { get; set; }
        public string? RejectionReason { get; set; }
        public DateTime? CanReapplyAt { get; set; }
        public RegistrationStatusResponse? RegistrationStatus { get; set; }
    }
}
