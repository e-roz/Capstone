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
    /// The rule: a parking fee that is still <see cref="PaymentStatus.Pending"/>
    /// blocks entry straight away; a violation fine blocks only once its due date
    /// has passed, so a driver can still appeal and pay inside the window.
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
        public static bool BlocksEntry(PaymentTransaction bill, DateTime now) =>
            IsOwed(bill)
            && (bill.Source == PaymentSource.ParkingFee
                || (bill.DueAt is DateTime due && due <= now));

        public static Result Evaluate(IEnumerable<PaymentTransaction> bills, DateTime now)
        {
            var blocked = false;
            var outstanding = 0m;

            foreach (var bill in bills)
            {
                if (!IsOwed(bill)) continue;
                outstanding += bill.AmountDue;
                if (BlocksEntry(bill, now)) blocked = true;
            }

            return new Result(blocked, outstanding);
        }
    }
}
