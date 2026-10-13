namespace AimPark.API.DTOs
{
    public class RejectRegistrationDto
    {
        public string Reason { get; set; } = string.Empty;

        /// <summary>Ignored. A rejection no longer has a cooldown; the field stays so an
        /// admin panel that still sends it is not refused.</summary>
        public int? CooldownHours { get; set; }
    }
}
