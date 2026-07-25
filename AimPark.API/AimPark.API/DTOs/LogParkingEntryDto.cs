namespace AimPark.API.DTOs
{
    public class LogParkingEntryDto
    {
        // Either identifier can be used to find the user; at least one is required.
        public Guid? UserId { get; set; }
        public string? RfidTagId { get; set; }
        public Guid? SlotId { get; set; }
    }

    public class LogParkingExitDto
    {
        public Guid LogId { get; set; }
    }
}
