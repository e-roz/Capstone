using AimPark.API.Enums;

namespace AimPark.API.Entities
{
    /// <summary>
    /// A spare RFID card lent to somebody with no AimPark account, for one visit.
    /// </summary>
    /// <remarks>
    /// Deliberately not a <see cref="User"/> with a short life. A visitor has no
    /// email, verifies no documents, owns no registered vehicle and cannot be
    /// issued a violation — modelling them as a user would have meant every one
    /// of those columns being nullable, and every query about real users having
    /// to remember to exclude them.
    ///
    /// The card is the link to the gate: <see cref="RfidTagId"/> is the same
    /// physical tag id a registered user carries, so the reader does not know or
    /// care which kind it just scanned. Only one pass may hold a given tag at a
    /// time — see the filtered unique index in <c>AppDbContext</c>.
    ///
    /// Parking on this pass is free, by design — a guest here for a specific
    /// purpose, not a campus regular. <c>ParkingHistoryService.LogExitAsync</c>
    /// skips the fee quote entirely for a log with no <c>UserId</c>; that is
    /// deliberate and not a gap to close.
    /// </remarks>
    public class VisitorPass
    {
        public Guid Id { get; set; } = Guid.NewGuid();

        /// <summary>
        /// The physical card handed over — always a registered
        /// <see cref="VisitorCard"/>. Freed again on exit.
        /// </summary>
        public string RfidTagId { get; set; } = string.Empty;

        public string VisitorName { get; set; } = string.Empty;

        /// <summary>
        /// Stored uppercase and unspaced, matching how registered plates are
        /// held, so the two can be compared when a guard checks a car.
        /// </summary>
        public string PlateNumber { get; set; } = string.Empty;

        /// <summary>
        /// Decides which bays the allocator may pick from, exactly as a
        /// registered vehicle's type does.
        /// </summary>
        public VehicleType VehicleType { get; set; } = VehicleType.Car;

        /// <summary>Who or what they are here for. Free text, for the log.</summary>
        public string? Purpose { get; set; }

        public string? ContactNumber { get; set; }

        /// <summary>The security or admin account that handed the card over.</summary>
        public Guid IssuedByUserId { get; set; }

        public DateTime IssuedAt { get; set; } = DateTime.UtcNow;

        /// <summary>
        /// When the card stops opening the barrier. Defaults to the end of the
        /// issuing day: a pass with no end is a spare card that works forever.
        /// </summary>
        public DateTime ExpiresAt { get; set; }

        /// <summary>
        /// When the pass stopped holding the card: the exit tap, or a guard
        /// taking it back before the car ever went in. Null while it is still out.
        /// </summary>
        public DateTime? ReturnedAt { get; set; }

        /// <summary>
        /// When a guard confirmed the physical card was back in the drawer.
        /// The exit tap releases the pass but cannot see whether the visitor
        /// handed the card over, so until this is set the card reads
        /// "Not yet returned". Lending the card again sets it too — tapping it
        /// proves it came back.
        /// </summary>
        public DateTime? CardCollectedAt { get; set; }

        public Guid? CardCollectedByUserId { get; set; }

        public VisitorPassStatus Status { get; set; } = VisitorPassStatus.Active;

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
        public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
    }
}
