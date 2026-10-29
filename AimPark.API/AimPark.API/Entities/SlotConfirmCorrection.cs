namespace AimPark.API.Entities
{
    /// <summary>
    /// An administrator moving a driver's confirmed bay to the one they were
    /// really in. Drivers cannot change a confirm themselves, so this is the only
    /// way a confirmed bay ever changes, and every change keeps the old bay, the
    /// new one, who did it and why.
    /// </summary>
    /// <remarks>
    /// Cloud only, like the confirm it corrects: the site server never sees
    /// confirms. <see cref="ParkingLog.SlotId"/> holds the corrected bay; the
    /// driver's own answer is the <see cref="FromSlotId"/> of the session's
    /// first correction.
    /// </remarks>
    public class SlotConfirmCorrection
    {
        public Guid Id { get; set; } = Guid.NewGuid();

        public Guid ParkingLogId { get; set; }
        public ParkingLog ParkingLog { get; set; } = null!;

        public Guid FromSlotId { get; set; }
        public ParkingSlot FromSlot { get; set; } = null!;

        public Guid ToSlotId { get; set; }
        public ParkingSlot ToSlot { get; set; } = null!;

        public string Reason { get; set; } = string.Empty;

        // Admin who made it — no FK, audit-style reference, as on Violation.
        public Guid CorrectedByUserId { get; set; }

        public DateTime CorrectedAt { get; set; } = DateTime.UtcNow;
    }
}
