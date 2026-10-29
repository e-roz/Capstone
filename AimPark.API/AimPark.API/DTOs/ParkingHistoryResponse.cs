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

        /// <summary>
        /// True when the driver said this is the bay they parked in. False means
        /// <see cref="SlotCode"/> is only the bay the gate suggested.
        /// </summary>
        public bool SlotConfirmed { get; set; }
        public DateTime EntryTime { get; set; }
        public DateTime? ExitTime { get; set; }

        // The fee raised for this session, so the app can link a history row
        // straight to its payment. Null while the session is still open, unless
        // the driver has tapped out or paid ahead from the app. The latest one
        // when a stay past the paid-ahead window added a second.
        public Guid? PaymentId { get; set; }

        // True while the driver is at the exit with a fee to pay, so the app can
        // say "pay to leave" instead of "you are parked". The amount is the fee
        // frozen when they tapped out.
        public bool WaitingToLeave { get; set; }
        public decimal? ExitAmountDue { get; set; }

        // The session is paid and still open: the barrier opens on a tap until
        // this time. Later than that, the rest of the stay is billed at the gate.
        public DateTime? LeaveBy { get; set; }

        // What came in, as the gate recorded it: the type of the plate read, or
        // the only type on the account. Null when the account has both and no
        // plate was read. The app only offers bays of this kind to confirm.
        public string? VehicleType { get; set; }

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

        /// <summary>The gate this car came in through, when known.</summary>
        public int? Gate { get; set; }

        /// <summary>This session's bill, once the driver has tapped out and been asked to pay.</summary>
        public Guid? PaymentId { get; set; }
        public decimal? AmountDue { get; set; }

        /// <summary>Pending, Processing, Paid or Waived. Null until a bill exists.</summary>
        public string? PaymentStatus { get; set; }

        /// <summary>When the bill was raised, which is when they tapped out.</summary>
        public DateTime? WaitingSince { get; set; }

        /// <summary>
        /// The driver has tapped out, owes a fee, and the barrier is shut until it
        /// is settled. The guard post lists these.
        /// </summary>
        public bool WaitingToLeave { get; set; }

        /// <summary>
        /// The bill was opened by the driver from the app while still parked, so
        /// an unpaid one is not a driver at the barrier.
        /// </summary>
        public bool PaidAhead { get; set; }
    }

    /// <summary>
    /// What a driver still parked is asked to pay before driving to the gate.
    /// </summary>
    public class PayAheadResponse
    {
        /// <summary>The bill to pay. Null when there is nothing to pay.</summary>
        public Guid? PaymentId { get; set; }

        public decimal AmountDue { get; set; }
        public int DurationMinutes { get; set; }

        /// <summary>Already paid: nothing more to do but leave by <see cref="LeaveBy"/>.</summary>
        public bool Paid { get; set; }

        /// <summary>When a paid session stops opening the barrier on its own.</summary>
        public DateTime? LeaveBy { get; set; }
    }
}
