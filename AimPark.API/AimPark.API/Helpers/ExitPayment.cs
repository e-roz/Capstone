using AimPark.API.Entities;
using AimPark.API.Enums;

namespace AimPark.API.Helpers
{
    /// <summary>
    /// How a driver stuck at the exit with a fee to pay gets out, other than by
    /// paying in the app: the guard takes cash, or lets them out still owing.
    /// </summary>
    /// <remarks>
    /// Both are written on the bill itself, in columns that already exist, so the
    /// record travels to the cloud with the bill and needs no table of its own.
    /// </remarks>
    public static class ExitPayment
    {
        /// <summary>The bill was settled in cash taken by a guard.</summary>
        public const string CashProvider = "Cash";

        /// <summary>
        /// A guard let the driver out without payment. The bill stays Pending, so
        /// entry stays blocked until it is settled; this only lets the next tap
        /// open the barrier.
        /// </summary>
        public const string ReleasedProvider = "Released";

        /// <summary>Manila has no daylight saving, so a fixed offset is exact.</summary>
        private static readonly TimeSpan Manila = TimeSpan.FromHours(8);

        public static DateOnly ManilaDay(DateTime utc)
            => DateOnly.FromDateTime(DateTime.SpecifyKind(utc, DateTimeKind.Utc).Add(Manila));

        /// <summary>The UTC span of one Manila calendar day.</summary>
        public static (DateTime FromUtc, DateTime ToUtc) DayRange(DateOnly manilaDay)
        {
            var start = DateTime.SpecifyKind(manilaDay.ToDateTime(TimeOnly.MinValue), DateTimeKind.Utc) - Manila;
            return (start, start.AddDays(1));
        }

        /// <summary>A receipt number the guard can read out: CASH-20261026-0007.</summary>
        public static string CashReference(DateTime paidAtUtc, int nthToday)
            => $"CASH-{ManilaDay(paidAtUtc):yyyyMMdd}-{nthToday:0000}";

        /// <summary>Does this bill let its driver through the exit barrier on the next tap?</summary>
        public static bool IsReleased(PaymentTransaction bill)
            => bill.Provider == ReleasedProvider && bill.Status is PaymentStatus.Pending or PaymentStatus.Processing;
    }
}
