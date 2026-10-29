namespace AimPark.API.Services
{
    /// <summary>
    /// Switches for how the gate behaves, read from the <c>Gate</c> section of
    /// configuration. Each server, cloud or site, reads its own copy.
    /// </summary>
    public class GateOptions
    {
        public const string Section = "Gate";

        /// <summary>
        /// Refuse entry when the driver's licence has expired, or when the
        /// registration of the vehicle at the barrier has.
        /// </summary>
        /// <remarks>
        /// Off by default. While it is off the checks still run, and an expired
        /// document is written to the log, but nobody is turned away. That is how
        /// this is meant to be introduced: watch what it would have refused before
        /// it refuses anyone, because a wrong date turns a student away at the
        /// barrier and the only person who can fix it is a guard.
        /// </remarks>
        public bool EnforceExpiredDocuments { get; set; }

        /// <summary>
        /// How long a driver has, after paying, to reach the exit and tap out.
        /// </summary>
        /// <remarks>
        /// A driver can pay from the app while still parked. The fee covers the
        /// time up to the payment; this is the walk back to the car and the drive
        /// to the gate. Tapping out later than this raises a second bill for the
        /// time after it, and the barrier waits for that one.
        /// </remarks>
        public int PaidExitGraceMinutes { get; set; } = 15;
    }
}
