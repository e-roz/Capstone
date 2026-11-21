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

        /// <summary>The bay on this session: the confirmed one, or only the gate's suggestion.</summary>
        public Guid? SlotId { get; set; }
        public string? SlotCode { get; set; }

        /// <summary>
        /// When the driver confirmed <see cref="SlotId"/> in the app. Null = the
        /// bay is only the one the gate suggested, which the map labels as such.
        /// </summary>
        public DateTime? SlotConfirmedAt { get; set; }

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

    /// <summary>
    /// What an open session costs right now, for the app's live fee card. Read
    /// only: asking never raises or reprices a bill.
    /// </summary>
    public class LiveFeeResponse
    {
        public Guid LogId { get; set; }
        public DateTime EntryTime { get; set; }

        /// <summary>The server's clock when this was priced. The phone counts time from here, not from its own clock.</summary>
        public DateTime AsOf { get; set; }

        /// <summary>Minutes charged so far. A started minute counts as a whole one.</summary>
        public int DurationMinutes { get; set; }

        public decimal RatePerHour { get; set; }

        /// <summary>What the whole stay would cost if the driver left now.</summary>
        public decimal TotalSoFar { get; set; }

        /// <summary>Paid or waived already for this session.</summary>
        public decimal AlreadyPaid { get; set; }

        /// <summary><see cref="TotalSoFar"/> less <see cref="AlreadyPaid"/>, never below zero.</summary>
        public decimal OwedNow { get; set; }

        /// <summary>A checkout for this session is open and the provider has not answered yet.</summary>
        public bool PaymentProcessing { get; set; }

        /// <summary>Nothing owed: the barrier opens on a tap until this time. Null while something is owed.</summary>
        public DateTime? LeaveBy { get; set; }

        /// <summary>When <see cref="TotalSoFar"/> next goes up. Null when it never will (no rate set).</summary>
        public DateTime? NextChangeAt { get; set; }

        /// <summary>What <see cref="TotalSoFar"/> goes up to at <see cref="NextChangeAt"/>.</summary>
        public decimal? NextTotal { get; set; }

        /// <summary>Set when the visit is over; then everything is priced at this time.</summary>
        public DateTime? ExitTime { get; set; }

        public DateTime FirstHourEndsAt { get; set; }

        /// <summary>The latest grace's end, if any payment was made.</summary>
        public DateTime? GraceUntil { get; set; }

        /// <summary>Free, FirstHour, Running or Paused.</summary>
        public string MeterState { get; set; } = "FirstHour";

        /// <summary>The visit in time order: first hour, per-minute runs, grace pauses.</summary>
        public List<FeeSegmentResponse> Segments { get; set; } = [];

        /// <summary>Settled bills, oldest first.</summary>
        public List<FeePaymentResponse> Payments { get; set; } = [];

        /// <summary>
        /// False for an old finished visit whose bills were worked out under the
        /// previous rules: the app then shows the bills and hides the timeline.
        /// </summary>
        public bool BreakdownMatchesBills { get; set; } = true;

        /// <summary>
        /// What this visit's bills come to, paid or not. For an old visit priced
        /// under the earlier rules this, not <see cref="TotalSoFar"/>, is its total.
        /// </summary>
        public decimal BilledTotal { get; set; }
    }

    /// <summary>One stretch of a visit and what it cost.</summary>
    public class FeeSegmentResponse
    {
        /// <summary>FirstHour, PerMinute or Grace.</summary>
        public string Kind { get; set; } = string.Empty;
        public DateTime From { get; set; }
        public DateTime To { get; set; }
        public int Minutes { get; set; }
        public decimal Amount { get; set; }
    }

    /// <summary>A settled bill on a visit, and the stretch it paid for.</summary>
    public class FeePaymentResponse
    {
        public Guid PaymentId { get; set; }
        public decimal Amount { get; set; }
        public DateTime? PaidAt { get; set; }
        public string? Method { get; set; }
        public DateTime? CoversFrom { get; set; }
        public DateTime? CoversTo { get; set; }
    }
}
