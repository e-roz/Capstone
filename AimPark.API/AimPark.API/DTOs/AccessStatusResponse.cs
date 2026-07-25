namespace AimPark.API.DTOs
{
    public class AccessStatusResponse
    {
        public string? RfidTagId { get; set; }
        public string RfidStatus { get; set; } = string.Empty;
        public string AccountStatus { get; set; } = string.Empty;
    }
}
