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

        /// <summary>
        /// The driver already confirmed a bay for this session. A confirm makes
        /// them answerable for that bay, so it is final; an administrator can
        /// correct a genuine mistake.
        /// </summary>
        public const string AlreadyConfirmed = "ALREADY_CONFIRMED";
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

    /// <summary>Outcome codes for an administrator correcting a confirmed bay.</summary>
    public static class BayCorrectResult
    {
        public const string Corrected = "CORRECTED";
        public const string LogNotFound = "LOG_NOT_FOUND";
        public const string SlotNotFound = "SLOT_NOT_FOUND";

        /// <summary>Only a confirmed bay is corrected; an unconfirmed session has nothing to correct.</summary>
        public const string NotConfirmed = "NOT_CONFIRMED";

        public const string SameBay = "SAME_BAY";
        public const string ReasonRequired = "REASON_REQUIRED";

        /// <summary>Another driver's confirmed session holds the new bay at the same time; correct that one first.</summary>
        public const string SlotTaken = "SLOT_TAKEN";

        /// <summary>Confirms live in the cloud, so they are corrected there, not at the guard post.</summary>
        public const string NotInCloud = "NOT_IN_CLOUD";
    }

    public class CorrectBayRequest
    {
        public Guid SlotId { get; set; }
        public string Reason { get; set; } = string.Empty;
    }

    public class CorrectBayResponse
    {
        public string Result { get; set; } = BayCorrectResult.Corrected;
        public string? SlotCode { get; set; }
        public string? Message { get; set; }
    }

    /// <summary>
    /// A session's confirmed bay as the driver gave it and every correction an
    /// administrator made after, for the Parking Logs page.
    /// </summary>
    public class BayConfirmHistoryResponse
    {
        public Guid LogId { get; set; }

        /// <summary>The bay the driver confirmed, before any correction.</summary>
        public string? DriverSlotCode { get; set; }
        public DateTime? DriverConfirmedAt { get; set; }

        /// <summary>The bay the session holds now: the driver's, or the last correction's.</summary>
        public string? CurrentSlotCode { get; set; }

        /// <summary>One of <see cref="Services.BayConfirmState"/>.</summary>
        public string State { get; set; } = string.Empty;

        public List<BayCorrectionResponse> Corrections { get; set; } = [];
    }

    public class BayCorrectionResponse
    {
        public string FromSlotCode { get; set; } = string.Empty;
        public string ToSlotCode { get; set; } = string.Empty;
        public string Reason { get; set; } = string.Empty;
        public string CorrectedByName { get; set; } = string.Empty;
        public DateTime CorrectedAt { get; set; }
    }
}
