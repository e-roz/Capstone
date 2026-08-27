using AimPark.API.Entities;
using AimPark.API.Enums;

namespace AimPark.API.Helpers
{
    /// <summary>
    /// The one place that answers "is this card refused right now?".
    /// </summary>
    /// <remarks>
    /// Since violations schedule their suspension a few days ahead rather than
    /// applying it at once, <c>RfidStatus == Suspended</c> stopped being the
    /// same question as "refuse this tag". Three call sites compared the enum
    /// directly, and each would have had to grow the same two date checks —
    /// which is how they would have drifted apart.
    /// </remarks>
    public static class RfidAccess
    {
        /// <summary>The suspension is in force: the gate must refuse this tag.</summary>
        public static bool IsSuspendedNow(User user, DateTime now) =>
            user.RfidStatus == RfidStatus.Suspended
            && (user.RfidSuspendedFrom is null || now >= user.RfidSuspendedFrom)
            && !HasExpired(user, now);

        /// <summary>
        /// A suspension is on the books but has not started yet — the card still
        /// works, and the appeal window is still open.
        /// </summary>
        public static bool IsSuspensionPending(User user, DateTime now) =>
            user.RfidStatus == RfidStatus.Suspended
            && user.RfidSuspendedFrom is not null
            && now < user.RfidSuspendedFrom
            && !HasExpired(user, now);

        /// <summary>
        /// A temporary suspension whose end has passed. Callers that can save
        /// should clear it with <see cref="Reactivate"/> rather than only
        /// reading past it.
        /// </summary>
        public static bool HasExpired(User user, DateTime now) =>
            user.RfidStatus == RfidStatus.Suspended
            && user.RfidSuspendedUntil is not null
            && user.RfidSuspendedUntil <= now;

        /// <summary>Clears a finished or lifted suspension.</summary>
        public static void Reactivate(User user, DateTime now)
        {
            user.RfidStatus = RfidStatus.Active;
            user.RfidSuspendedFrom = null;
            user.RfidSuspendedUntil = null;
            user.UpdatedAt = now;
        }
    }
}
