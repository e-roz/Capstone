namespace AimPark.API.DTOs
{
    public class CompleteProfileDto
    {
        public string FullName { get; set; } = string.Empty;
        public string Password { get; set; } = string.Empty;
        public string? PhoneNumber { get; set; }
    }
}
