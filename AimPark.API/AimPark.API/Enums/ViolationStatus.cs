namespace AimPark.API.Enums
{
    /// <summary>
    /// Where a violation is in its case.
    /// </summary>
    /// <remarks>
    /// Issued → PendingAppeal → Appealed (user won) or Accountable (user lost).
    /// Issued also becomes Accountable on its own when the appeal deadline
    /// passes, or when an admin marks it so. Issued and PendingAppeal can be
    /// Dismissed when the violation should never have been issued.
    ///
    /// Appealed, Accountable and Dismissed are final.
    /// </remarks>
    public enum ViolationStatus
    {
        /// <summary>Issued; the user has not appealed and the deadline has not passed.</summary>
        Issued,

        /// <summary>The user appealed and no admin has decided it yet.</summary>
        PendingAppeal,

        /// <summary>The appeal was accepted. No penalty applies.</summary>
        Appealed,

        /// <summary>The user is at fault: appeal rejected, deadline lapsed, or marked by an admin.</summary>
        Accountable,

        /// <summary>Issued by mistake and cleared by an admin.</summary>
        Dismissed
    }
}
