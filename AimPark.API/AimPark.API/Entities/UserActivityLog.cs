namespace AimPark.API.Entities
{
    /// <summary>
    /// A thing a user account did, or had done to it — the capstone document's
    /// "User Activity Logs: records user actions such as login/logout,
    /// registration, and account status changes (approved, suspended, revoked)".
    ///
    /// Deliberately separate from <see cref="AdminAuditLog"/>. That table answers
    /// "what did this administrator do", indexed by the admin; this one answers
    /// "what happened to this account", indexed by the user. A status change
    /// writes to both, from the two different points of view, because an auditor
    /// asks the question in both directions.
    /// </summary>
    public class UserActivityLog
    {
        public Guid Id { get; set; } = Guid.NewGuid();

        /// <summary>
        /// The account the activity concerns. Not a foreign key on purpose: a
        /// failed login attempt against an address that does not exist still
        /// deserves a row, and an archived account must not cascade its history
        /// away.
        /// </summary>
        public Guid? UserId { get; set; }

        /// <summary>
        /// Kept alongside <see cref="UserId"/> so a row stays readable when the
        /// account is gone, and so failed logins against unknown addresses have
        /// something to show.
        /// </summary>
        public string EmailAtTime { get; set; } = string.Empty;

        /// <summary>Login, LoginFailed, Logout, Registered, StatusChanged, RfidAssigned…</summary>
        public string Activity { get; set; } = string.Empty;

        /// <summary>Free text: the old→new status, the rejection reason, why a login failed.</summary>
        public string? Detail { get; set; }

        /// <summary>
        /// Where it came from. Useful for the one question this table gets asked
        /// in anger: "was somebody trying passwords against this account?"
        /// </summary>
        public string? IpAddress { get; set; }

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    }
}
