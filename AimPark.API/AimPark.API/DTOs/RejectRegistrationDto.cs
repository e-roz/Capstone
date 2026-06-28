namespace AimPark.API.DTOs
{
    public class RejectRegistrationDto
    {
        public string Reason { get; set; } = string.Empty;
        public int? CooldownHours { get; set; }
    }
}
