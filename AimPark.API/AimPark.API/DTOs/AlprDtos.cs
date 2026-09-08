namespace AimPark.API.DTOs
{
    /// <summary>
    /// What the ALPR desktop app posts. Sent on a steady interval whether or
    /// not a plate was seen — a null <see cref="PlateNumber"/> is just a
    /// liveness ping, so <c>GateDevice.LastSeenAt</c> stays fresh even
    /// through a stretch with no cars.
    /// </summary>
    public class SubmitAlprReadingDto
    {
        public string? PlateNumber { get; set; }

        /// <summary>fast-alpr's OCR confidence (0–1), if it reports one.</summary>
        public double? Confidence { get; set; }
    }

    public class AlprReadingResponse
    {
        public Guid? ReadingId { get; set; }

        /// <summary>False for a bare heartbeat ping — nothing was recorded.</summary>
        public bool Recorded { get; set; }
    }
}
