namespace AimPark.API.DTOs
{
    /// <summary>
    /// Machine-readable outcome of a slot allocation. Gate hardware branches on
    /// this rather than parsing prose, so the values are part of the contract.
    /// </summary>
    public static class AllocationResult
    {
        public const string Assigned = "ASSIGNED";
        public const string LotFull = "LOT_FULL";
        public const string NoVehicleRegistered = "NO_VEHICLE_REGISTERED";

        // Gate outcomes. Firmware switches on these to decide whether to raise
        // the barrier, so they are a contract — never reword them, and never
        // ask the device to interpret the human-readable message instead.
        public const string UnknownTag = "UNKNOWN_TAG";
        public const string RfidSuspended = "RFID_SUSPENDED";
        public const string SlotUnavailable = "SLOT_UNAVAILABLE";
        public const string AlreadyInside = "ALREADY_INSIDE";
        public const string ExitLogged = "EXIT_LOGGED";
        public const string LogNotFound = "LOG_NOT_FOUND";
        public const string AlreadyExited = "ALREADY_EXITED";
    }

    public class SlotRecommendationResponse
    {
        public string Result { get; set; } = AllocationResult.Assigned;

        public Guid? SlotId { get; set; }
        public string? SlotCode { get; set; }
        public int? Gate { get; set; }

        /// <summary>
        /// Next-best slots, so the app can show "or try these" rather than a
        /// single take-it-or-leave-it answer.
        /// </summary>
        public List<SlotOptionResponse> Alternatives { get; set; } = [];

        /// <summary>Plain-language explanation of the pick, for the UI and the demo.</summary>
        public string? Reason { get; set; }
    }

    public class SlotOptionResponse
    {
        public Guid SlotId { get; set; }
        public string SlotCode { get; set; } = string.Empty;
        public int Gate { get; set; }
    }
}
