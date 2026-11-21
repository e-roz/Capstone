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
        /// How long the meter pauses after each payment: the grace. These minutes
        /// are never charged.
        /// </summary>
        /// <remarks>
        /// A driver can pay from the app while still parked. The fee covers the
        /// time up to the payment; the grace is the walk back to the car and the
        /// drive to the gate. Still inside after it, the meter runs again from the
        /// end of the grace, and the barrier waits for that extra.
        /// </remarks>
        public int PaidExitGraceMinutes { get; set; } = 7;
    }
}
