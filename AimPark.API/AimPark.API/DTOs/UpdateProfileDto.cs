namespace AimPark.API.DTOs
{
    public class UpdateProfileDto
    {
        public string FullName { get; set; } = string.Empty;
        public string? PhoneNumber { get; set; }
    }
}
