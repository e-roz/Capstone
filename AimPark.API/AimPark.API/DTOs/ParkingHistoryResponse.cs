namespace AimPark.API.DTOs
{
    public class ParkingHistoryResponse
    {
        public List<ParkingHistoryEntryResponse> Logs { get; set; } = [];
        public int TotalCount { get; set; }
        public int Page { get; set; }
        public int PageSize { get; set; }
    }

    public class ParkingHistoryEntryResponse
    {
        public Guid LogId { get; set; }
        public string? SlotCode { get; set; }
        public DateTime EntryTime { get; set; }
        public DateTime? ExitTime { get; set; }
    }

    /// <summary>
    /// A parking session that has an entry but no exit yet — i.e. a vehicle
    /// currently inside. Powers the admin "Log Exit" picker so an operator
    /// never has to know a raw log ID.
    /// </summary>
    public class ActiveParkingSessionResponse
    {
        public Guid LogId { get; set; }
        public Guid UserId { get; set; }
        public string UserName { get; set; } = string.Empty;
        public string? PlateNumber { get; set; }
        public string? SlotCode { get; set; }
        public DateTime EntryTime { get; set; }
    }
}
