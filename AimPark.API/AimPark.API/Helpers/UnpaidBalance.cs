using AimPark.API.Entities;
using AimPark.API.Enums;

namespace AimPark.API.Helpers
{
    /// <summary>
    /// The one place that answers "does this person owe money the gate cares about?".
    /// </summary>
    /// <remarks>
    /// The cloud's entry check, the site server's entry check and the app's
    /// access-status all ask the same question, so they share this rather than
    /// each carrying their own copy of the rule.
    ///
    /// The rule: any bill that is still <see cref="PaymentStatus.Pending"/> blocks
    /// entry straight away — a parking fee, and a violation fine alike. A fine only
    /// exists once the violation is final (the appeal is over), so there is no
    /// window left to protect, and it is paid the same way as anything else owed.
    /// A suspension is a separate block that paying does not lift; this one is
    /// lifted by paying.
    /// <see cref="PaymentStatus.Processing"/> (checkout started, not yet confirmed),
    /// Paid, Waived and ₱0 bills never block. Exit is never blocked — this is
    /// consulted on the entry path only.
    /// </remarks>
    public static class UnpaidBalance
    {
        public readonly record struct Result(bool Blocked, decimal Outstanding)
        {
            public static readonly Result None = new(false, 0m);
        }

        /// <summary>Is this one bill an unpaid debt at all (blocking or not)?</summary>
        public static bool IsOwed(PaymentTransaction bill) =>
            bill.Status == PaymentStatus.Pending && bill.AmountDue > 0m;

        /// <summary>Does this one bill stop the holder from entering right now?</summary>
        public static bool BlocksEntry(PaymentTransaction bill) => IsOwed(bill);

        /// <param name="now">
        /// Not used by the rule any more: whether a bill blocks no longer depends
        /// on a date. Kept so the callers and the guard post's snapshots need no
        /// change.
        /// </param>
        public static Result Evaluate(IEnumerable<PaymentTransaction> bills, DateTime now)
        {
            var blocked = false;
            var outstanding = 0m;

            foreach (var bill in bills)
            {
                if (!IsOwed(bill)) continue;
                outstanding += bill.AmountDue;
                if (BlocksEntry(bill)) blocked = true;
            }

            return new Result(blocked, outstanding);
        }
    }
}
