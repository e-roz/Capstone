namespace AimPark.API.DTOs
{
    /// <summary>
    /// One RFID entry/exit event, as the System Logs module shows it.
    ///
    /// This is a projection over <c>ParkingLog</c> rather than a table of its
    /// own: every field the capstone document asks for in "RFID Access Logs —
    /// tracks vehicle entry and exit using RFID, including timestamps and user
    /// identification" is already recorded when a gate reports a scan.
    /// </summary>
    public class RfidAccessLogEntryResponse
    {
        public Guid Id { get; set; }
        public Guid UserId { get; set; }
        public string UserName { get; set; } = string.Empty;
        public string? RfidTagId { get; set; }
        public string? SlotCode { get; set; }
        public int? Gate { get; set; }

        public DateTime EntryTime { get; set; }
        public DateTime? ExitTime { get; set; }

        /// <summary>"Device" when a reader reported it, "Manual" when a member
        /// of staff logged it from the panel. This is the difference between a
        /// real RFID scan and a keyed-in correction, so it is worth a column.</summary>
        public string Source { get; set; } = string.Empty;

        /// <summary>Reader name, or the staff account that keyed it in.</summary>
        public string? RecordedBy { get; set; }

        public DateTime CreatedAt { get; set; }
    }

    public class RfidAccessLogListResponse
    {
        public List<RfidAccessLogEntryResponse> Logs { get; set; } = [];
        public int TotalCount { get; set; }
        public int Page { get; set; }
        public int PageSize { get; set; }
    }

    public class UserActivityLogEntryResponse
    {
        public Guid Id { get; set; }
        public Guid? UserId { get; set; }
        public string EmailAtTime { get; set; } = string.Empty;

        /// <summary>Resolved at read time; falls back to the stored email when
        /// the account is gone or never existed.</summary>
        public string UserName { get; set; } = string.Empty;

        public string Activity { get; set; } = string.Empty;
        public string? Detail { get; set; }
        public string? IpAddress { get; set; }
        public DateTime CreatedAt { get; set; }
    }

    public class UserActivityLogListResponse
    {
        public List<UserActivityLogEntryResponse> Logs { get; set; } = [];
        public int TotalCount { get; set; }
        public int Page { get; set; }
        public int PageSize { get; set; }
    }

    public class SystemErrorLogEntryResponse
    {
        public Guid Id { get; set; }
        public string ErrorType { get; set; } = string.Empty;
        public string Message { get; set; } = string.Empty;
        public string? StackTrace { get; set; }
        public string? Path { get; set; }
        public int StatusCode { get; set; }
        public string? TraceId { get; set; }
        public DateTime CreatedAt { get; set; }
    }

    public class SystemErrorLogListResponse
    {
        public List<SystemErrorLogEntryResponse> Logs { get; set; } = [];
        public int TotalCount { get; set; }
        public int Page { get; set; }
        public int PageSize { get; set; }
    }
}
