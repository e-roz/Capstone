namespace AimPark.API.Interfaces
{
    /// <summary>
    /// Records what happened to a user account, for the User Activity Logs tab
    /// of the System Logs module.
    ///
    /// Deliberately fire-and-forget from the caller's point of view: writing a
    /// log line must never be the reason a login or an approval fails, so
    /// implementations swallow their own errors.
    /// </summary>
    public interface IUserActivityLogger
    {
        Task LogAsync(
            Guid? userId,
            string email,
            string activity,
            string? detail = null,
            CancellationToken ct = default);
    }

    /// <summary>
    /// The activity names, so a typo in one controller cannot produce a second
    /// spelling that the filter dropdown never shows.
    /// </summary>
    public static class UserActivities
    {
        public const string Login = "Login";
        public const string LoginFailed = "LoginFailed";
        public const string Logout = "Logout";
        public const string Registered = "Registered";
        public const string StatusChanged = "StatusChanged";
        public const string Approved = "Approved";
        public const string Rejected = "Rejected";
        public const string RfidAssigned = "RfidAssigned";
        public const string RfidRevoked = "RfidRevoked";

        /// <summary>
        /// A registration step was stopped because the plate, student number or
        /// licence number it read already belongs to another account.
        /// </summary>
        public const string DuplicateIdentityBlocked = "DuplicateIdentityBlocked";

        /// <summary>The system approved a clean application without a reviewer.</summary>
        public const string AutoApproved = "AutoApproved";

        /// <summary>Everything above, for the admin panel's filter dropdown.</summary>
        public static readonly string[] All =
        [
            Login, LoginFailed, Logout, Registered, StatusChanged,
            Approved, Rejected, RfidAssigned, RfidRevoked,
            DuplicateIdentityBlocked, AutoApproved
        ];
    }
}
