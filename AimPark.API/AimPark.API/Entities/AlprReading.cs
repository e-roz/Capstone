namespace AimPark.API.Entities
{
    /// <summary>
    /// One plate the ALPR camera read, independent of whether an RFID tap
    /// ever shows up to match against it.
    /// </summary>
    public class AlprReading
    {
        public Guid Id { get; set; } = Guid.NewGuid();

        /// <summary>
        /// Which barrier, taken from the device's own claim rather than
        /// trusted from the request body — same rule ParkingLog's gate
        /// devices already follow.
        /// </summary>
        public int Gate { get; set; }

        /// <summary>Normalized uppercase/unspaced, matching Vehicle.PlateNumber.</summary>
        public string PlateNumber { get; set; } = string.Empty;

        /// <summary>fast-alpr's OCR confidence (0–1), if it reports one.</summary>
        public double? Confidence { get; set; }

        public Guid DeviceId { get; set; }
        public GateDevice Device { get; set; } = null!;

        public DateTime ReadAt { get; set; } = DateTime.UtcNow;

        /// <summary>
        /// Set once an RFID entry has matched against this reading, so the
        /// same camera frame can't be reused to wave through a second car.
        /// </summary>
        public DateTime? ConsumedAt { get; set; }

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    }
}
