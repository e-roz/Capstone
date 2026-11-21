using AimPark.API.Data;
using AimPark.API.Entities;
using AimPark.API.Enums;
using AimPark.API.Helpers;
using AimPark.API.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace AimPark.API.Services
{
    /// <summary>One visit, priced at a moment, with what is already settled.</summary>
    /// <param name="UnpaidFrom">
    /// Where the part nobody has paid for starts: the start of the first charged
    /// stretch after what earlier bills covered. A new bill covers from here.
    /// </param>
    public sealed record VisitPrice(
        FeeBreakdown Breakdown,
        decimal RatePerHour,
        decimal Settled,
        decimal OwedNow,
        DateTime UnpaidFrom,
        IReadOnlyList<PaymentTransaction> Bills,
        IReadOnlyList<PaymentTransaction> SettledBills,
        DateTime At)
    {
        /// <summary>Nothing owed: the barrier opens on a tap until this moment.</summary>
        public DateTime? CoveredUntil => OwedNow <= 0m ? Breakdown.NextChangeAt : null;
    }

    /// <summary>
    /// The one place a visit is priced against its bills. The gate, pay-ahead,
    /// checkout and the app's live fee all ask here.
    /// </summary>
    /// <remarks>
    /// "Settled" is asked of <see cref="IEntryDues"/>, not read from the status
    /// alone: on the site server a payment made in the app is known from the
    /// cloud's snapshot while the local row still says Pending. Such a row has no
    /// paid time here, so its grace starts at <c>at</c>: as far as the site can
    /// tell, it was just paid.
    /// </remarks>
    public sealed class VisitPricing
    {
        private readonly AppDbContext _db;
        private readonly IPaymentService _payments;
        private readonly IEntryDues _dues;
        private readonly int _graceMinutes;

        public VisitPricing(AppDbContext db, IPaymentService payments, IEntryDues dues, TimeSpan grace)
        {
            _db = db;
            _payments = payments;
            _dues = dues;
            _graceMinutes = (int)Math.Round(grace.TotalMinutes);
        }

        public async Task<VisitPrice> PriceAsync(ParkingLog log, DateTime at, CancellationToken ct)
        {
            var (rate, _) = await _payments.RateForAsync(log, ct);

            var bills = await _db.Set<PaymentTransaction>().AsNoTracking()
                .Where(p => p.ParkingLogId == log.Id)
                .OrderBy(p => p.CreatedAt)
                .ToListAsync(ct);

            var settled = new List<PaymentTransaction>();
            foreach (var bill in bills)
            {
                if (bill.Status is PaymentStatus.Paid or PaymentStatus.Waived)
                {
                    settled.Add(bill);
                }
                else if (!ExitPayment.IsReleased(bill) && bill.AmountDue > 0m
                         && await _dues.IsSettledAsync(bill.Id, ct))
                {
                    bill.PaidAt ??= at; // untracked copy: only this calculation sees it
                    settled.Add(bill);
                }
            }

            var breakdown = ParkingFeeMath.Breakdown(
                rate, log.EntryTime, at,
                settled.Select(b => b.PaidAt ?? b.CreatedAt).ToList(),
                _graceMinutes, open: log.ExitTime is null);

            var settledSum = settled.Sum(b => b.AmountDue);

            // What earlier bills covered. Bills from before CoversTo existed fall
            // back to their paid time. Any settled bill paid at least the first
            // hour, so coverage never ends before it.
            var coveredTo = settled.Count == 0
                ? log.EntryTime
                : settled.Max(b => b.CoversTo ?? b.PaidAt ?? b.CreatedAt);
            if (settled.Count > 0 && coveredTo < breakdown.FirstHourEndsAt)
                coveredTo = breakdown.FirstHourEndsAt;

            var next = breakdown.Segments.FirstOrDefault(s => s.Kind != FeeSegmentKind.Grace && s.To > coveredTo);
            var unpaidFrom = next is not null && next.From > coveredTo ? next.From : coveredTo;

            return new VisitPrice(breakdown, rate, settledSum,
                Math.Max(0m, breakdown.Total - settledSum), unpaidFrom, bills, settled, at);
        }
    }
}
