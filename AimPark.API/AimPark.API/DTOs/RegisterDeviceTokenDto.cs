namespace AimPark.API.DTOs
{
    public class RegisterDeviceTokenDto
    {
        public string Token { get; set; } = string.Empty;

        // "android" / "ios" — optional, informational only
        public string? Platform { get; set; }
    }
}
