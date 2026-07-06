namespace AimPark.API.DTOs
{
    public class SuspendUserDto
    {
        /// <summary>Optional reason for the suspension (stored in audit log).</summary>
        public string? Reason { get; set; }
    }
}
