namespace AimPark.API.Services
{
    /// <summary>Where a session stands on saying which bay it used.</summary>
    public static class BayConfirmState
    {
        /// <summary>Still inside and has not confirmed yet. Not a problem yet.</summary>
        public const string NotYet = "NotYet";

        public const string Confirmed = "Confirmed";

        /// <summary>Confirmed, but only after the vehicle had left.</summary>
        public const string ConfirmedLate = "ConfirmedLate";

        /// <summary>Left without confirming. Counts toward a warning and a strike.</summary>
        public const string Unconfirmed = "Unconfirmed";

        /// <summary>A visitor or a very short stay, who is never asked to confirm.</summary>
        public const string NotCounted = "NotCounted";
    }

    /// <summary>
    /// The rules for a driver who leaves without saying which bay they used,
    /// kept in one place so the Parking Logs page and the warnings agree on who
    /// "didn't confirm".
    /// </summary>
    public static class SlotConfirmPolicy
    {
        /// <summary>Manila has no daylight saving, so a fixed offset is exact.</summary>
        private static readonly TimeSpan Manila = TimeSpan.FromHours(8);

        /// <summary>
        /// A drop-off or a turn-around: too short to have parked and walked
        /// away, so not confirming is not held against anyone.
        /// </summary>
        public static readonly TimeSpan ShortStay = TimeSpan.FromMinutes(10);

        /// <summary>Unconfirmed sessions in <see cref="Window"/> that bring a warning.</summary>
        public const int WarnAt = 3;

        /// <summary>Unconfirmed sessions in <see cref="Window"/> that are sent to an admin as a possible strike.</summary>
        public const int ReviewAt = 5;

        public static readonly TimeSpan Window = TimeSpan.FromDays(30);

        /// <summary>
        /// Whether this session is one a driver is expected to confirm at all.
        /// Visitors have no app; a short stay never really parked.
        /// </summary>
        public static bool Counts(Guid? userId, DateTime entry, DateTime? exit)
            => userId is not null && (exit is null || exit.Value - entry >= ShortStay);

        public static string StateOf(Guid? userId, DateTime entry, DateTime? exit, DateTime? confirmedAt)
        {
            if (confirmedAt is not null)
                return exit is not null && confirmedAt > exit
                    ? BayConfirmState.ConfirmedLate
                    : BayConfirmState.Confirmed;

            if (!Counts(userId, entry, exit)) return BayConfirmState.NotCounted;

            return exit is null ? BayConfirmState.NotYet : BayConfirmState.Unconfirmed;
        }

        /// <summary>
        /// A driver may still confirm until midnight of the day they came in, so
        /// an unconfirmed session is only final, and only counted, after that.
        /// </summary>
        public static bool IsFinal(DateTime entry, DateTime now)
            => ManilaDay(now) > ManilaDay(entry);

        public static DateOnly ManilaDay(DateTime utc)
            => DateOnly.FromDateTime(DateTime.SpecifyKind(utc, DateTimeKind.Utc).Add(Manila));
    }
}
