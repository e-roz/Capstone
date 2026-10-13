namespace AimPark.API.DTOs
{
    /// <summary>
    /// One vehicle's stay in the lot, as the Parking Logs page shows it.
    ///
    /// This is a projection over <c>ParkingLog</c> rather than a table of its
    /// own: the entry and exit times, who came in and what they drove are all
    /// recorded when a gate reports a scan. The gate is shown instead of a bay
    /// because the bay is only a suggestion; the gate is where the vehicle was seen.
    /// </summary>
    public class RfidAccessLogEntryResponse
    {
        public Guid Id { get; set; }

        /// <summary>Null for a visitor, who has no account.</summary>
        public Guid? UserId { get; set; }

        /// <summary>The account holder, or the visitor's name.</summary>
        public string UserName { get; set; } = string.Empty;

        /// <summary>True when the card was one lent to a visitor.</summary>
        public bool IsVisitor { get; set; }

        /// <summary>What a visitor is here for, as the guard wrote it. Null for members.</summary>
        public string? VisitorPurpose { get; set; }

        public string? RfidTagId { get; set; }

        /// <summary>"Car" or "Motorcycle"; null when it cannot be told.</summary>
        public string? VehicleType { get; set; }

        /// <summary>The plate the camera read, else the registered one; null when neither is known.</summary>
        public string? PlateNumber { get; set; }

        public int? Gate { get; set; }

        public DateTime EntryTime { get; set; }
        public DateTime? ExitTime { get; set; }

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
