using AimPark.API.Enums;

namespace AimPark.API.Helpers
{
    /// <summary>
    /// Whether an account is left alone by a bulk archive, and why.
    /// </summary>
    /// <remarks>
    /// A sweep over dozens of accounts must never take someone who is in the
    /// middle of something: parked in the lot right now, owing money, or with a
    /// violation still undecided. They are skipped and listed, so the
    /// administrator can sort them out and run it again.
    /// </remarks>
    public static class BulkArchiveRules
    {
        /// <returns>The reason to skip, or null when the account may be archived.</returns>
        public static string? SkipReason(
            UserRole role, bool isSelf, bool isArchived,
            bool isInsideLot, bool owesMoney, bool hasOpenViolation)
        {
            if (isSelf) return "This is your own account.";
            if (role != UserRole.User) return "Staff and administrator accounts are not archived in bulk.";
            if (isArchived) return "Already archived.";
            if (isInsideLot) return "Currently parked in the lot.";
            if (owesMoney) return "Has an unpaid balance.";
            if (hasOpenViolation) return "Has a violation that is not yet decided.";
            return null;
        }

        /// <summary>Violations still moving toward a decision, as opposed to finished ones.</summary>
        public static bool IsOpen(ViolationStatus status) =>
            status is ViolationStatus.Issued or ViolationStatus.PendingAppeal or ViolationStatus.Appealed;
    }
}
