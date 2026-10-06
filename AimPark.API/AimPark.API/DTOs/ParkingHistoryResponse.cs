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

        // The fee raised for this session, so the app can link a history row
        // straight to its payment. Null while the session is still open — the
        // transaction is only created on exit.
        public Guid? PaymentId { get; set; }

        // The ALPR-confirmed plate for this session. Null for a manually
        // logged entry (no camera involved) — never a mismatched plate, since
        // a mismatch is refused at the gate and never becomes a log at all.
        public string? AlprPlateNumber { get; set; }

        // Which of the caller's own vehicles this session is attributed to —
        // worked out from AlprPlateNumber at read time (see
        // ParkingHistoryService.AttributeVehicle). Null when it can't be
        // determined (no plate and more than one vehicle on the account, or a
        // plate that no longer matches any vehicle on file).
        public Guid? VehicleId { get; set; }
    }

    /// <summary>
    /// A parking session that has an entry but no exit yet — i.e. a vehicle
    /// currently inside. Powers the admin "Log Exit" picker so an operator
    /// never has to know a raw log ID.
    /// </summary>
    public class ActiveParkingSessionResponse
    {
        public Guid LogId { get; set; }

        /// <summary>Null when the session belongs to a visitor.</summary>
        public Guid? UserId { get; set; }

        /// <summary>The account holder, or the visitor's name.</summary>
        public string UserName { get; set; } = string.Empty;

        public string? PlateNumber { get; set; }
        public string? SlotCode { get; set; }
        public DateTime EntryTime { get; set; }

        /// <summary>
        /// Whether this car got in on a lent card. The guard needs it: a visitor
        /// pays cash on the way out and hands the card back, and neither is true
        /// of anybody else in the list.
        /// </summary>
        public bool IsVisitor { get; set; }
    }
}
