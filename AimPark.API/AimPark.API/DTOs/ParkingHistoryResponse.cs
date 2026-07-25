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
}
