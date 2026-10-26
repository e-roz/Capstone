namespace AimPark.API.DTOs
{
    /// <summary>
    /// Machine-readable outcome of a driver confirming where they parked. Kept
    /// apart from <see cref="AllocationResult"/>, whose values are a contract
    /// with the gate firmware.
    /// </summary>
    public static class SlotConfirmResult
    {
        public const string Confirmed = "CONFIRMED";
        public const string LogNotFound = "LOG_NOT_FOUND";
        public const string SlotNotFound = "SLOT_NOT_FOUND";

        /// <summary>The session ended on an earlier day, so it can no longer be confirmed.</summary>
        public const string TooLate = "TOO_LATE";

        /// <summary>Another driver's confirmed session already holds that bay at the same time.</summary>
        public const string SlotTaken = "SLOT_TAKEN";
    }

    public class ConfirmSlotRequest
    {
        public Guid LogId { get; set; }
        public Guid SlotId { get; set; }
    }

    public class ConfirmSlotResponse
    {
        public string Result { get; set; } = SlotConfirmResult.Confirmed;
        public Guid? SlotId { get; set; }
        public string? SlotCode { get; set; }

        /// <summary>True when the driver confirmed after leaving.</summary>
        public bool Late { get; set; }

        public string? Message { get; set; }
    }
}
