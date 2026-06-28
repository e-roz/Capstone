namespace AimPark.API.DTOs
{
    public class OAuthCallbackResponse
    {
        public string Message { get; set; } = string.Empty;
        public string? SessionToken { get; set; }
        public string? Token { get; set; }
    }
}
