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

        /// <summary>The bay is for the other kind of vehicle from the one that came in.</summary>
        public const string WrongVehicleType = "WRONG_VEHICLE_TYPE";

        /// <summary>
        /// The account has a car and a motorcycle, no plate was read at the gate,
        /// and the driver has not said which one they brought.
        /// </summary>
        public const string VehicleNeeded = "VEHICLE_NEEDED";

        public const string VehicleNotFound = "VEHICLE_NOT_FOUND";
    }

    public class ConfirmSlotRequest
    {
        public Guid LogId { get; set; }
        public Guid SlotId { get; set; }

        /// <summary>
        /// Which of the driver's vehicles they brought. Only read when the gate
        /// could not tell: an account with both kinds and no plate read.
        /// </summary>
        public Guid? VehicleId { get; set; }
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
