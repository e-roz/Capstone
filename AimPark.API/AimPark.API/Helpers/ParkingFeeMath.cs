namespace AimPark.API.Helpers
{
    public enum FeeSegmentKind { FirstHour, PerMinute, Grace }

    /// <summary>What the meter is doing right now.</summary>
    public enum MeterState { Free, FirstHour, Running, Paused }

    /// <summary>
    /// A settled payment as the meter sees it: the bill was priced up to
    /// <see cref="PricedTo"/> and the money arrived at <see cref="PaidAt"/>.
    /// </summary>
    public sealed record SettledPayment(DateTime PricedTo, DateTime PaidAt);

    /// <summary>One stretch of a visit and what it costs. Grace stretches cost nothing.</summary>
    public sealed record FeeSegment(FeeSegmentKind Kind, DateTime From, DateTime To, int Minutes, decimal Amount);

    /// <summary>A whole visit, priced. <see cref="Segments"/> is in time order.</summary>
    public sealed record FeeBreakdown(
        decimal Total,
        int ChargedMinutes,
        int PerMinuteMinutes,
        IReadOnlyList<FeeSegment> Segments,
        DateTime FirstHourEndsAt,
        DateTime? GraceUntil,
        MeterState State,
        DateTime? NextChangeAt,
        decimal? NextTotal)
    {
        /// <summary>
        /// Charged minutes (first hour and per-minute, not grace) inside
        /// [<paramref name="from"/>, <paramref name="to"/>). What one bill covers.
        /// </summary>
        public int ChargeableMinutesBetween(DateTime from, DateTime to) =>
            Segments.Where(s => s.Kind != FeeSegmentKind.Grace)
                .Sum(s =>
                {
                    var start = s.From > from ? s.From : from;
                    var end = s.To < to ? s.To : to;
                    return end > start ? (int)Math.Round((end - start).TotalMinutes) : 0;
                });
    }

    /// <summary>
    /// How a visit is priced, as plain arithmetic with no database. The gate,
    /// pay-ahead, checkout, the live fee and every receipt use this, so they
    /// can never disagree about what a stay costs.
    /// </summary>
    /// <remarks>
    /// First hour: one hour's rate, flat, from the first second. After minute 60
    /// every started minute costs rate ÷ 60.
    ///
    /// Each settled payment starts a grace period of 7 minutes, counted from the
    /// moment the money arrived. A driver who leaves inside it pays nothing more:
    /// the meter is paused from the end of what the bill was priced to. A driver
    /// still inside when it ends loses it: the grace minutes, and the minutes the
    /// payment took to go through, are charged like any other. Every payment
    /// gets its own grace period by the same rule.
    ///
    /// The time a payment takes is only ever paused for up to
    /// <see cref="MaxPaymentDelayMinutes"/>: a checkout left open for hours does
    /// not make those hours free even for a driver who leaves in time.
    /// </remarks>
    public static class ParkingFeeMath
    {
        public const int FirstHourMinutes = 60;

        /// <summary>At most this much time before a payment counts as it going through.</summary>
        public const int MaxPaymentDelayMinutes = 15;

        /// <summary>
        /// The minute <paramref name="at"/> falls in, counted from entry. A started
        /// minute is a charged minute.
        /// </summary>
        public static int ChargedMinutes(DateTime entry, DateTime at)
            => Math.Max(0, (int)Math.Ceiling((at - entry).TotalMinutes));

        /// <param name="settled">Each settled payment. Each starts a grace period (see remarks).</param>
        /// <param name="open">
        /// True while the car is inside: a grace period still running is shown to its end.
        /// False for a finished visit: the grace period stops at the exit.
        /// </param>
        public static FeeBreakdown Breakdown(
            decimal ratePerHour, DateTime entry, DateTime at,
            IReadOnlyList<SettledPayment> settled, int graceMinutes, bool open = true)
        {
            var firstHourEnd = entry.AddMinutes(FirstHourMinutes);
            var n = Math.Max(1, ChargedMinutes(entry, at));

            if (ratePerHour <= 0m)
                return new FeeBreakdown(0m, n, 0, [], firstHourEnd, null, MeterState.Free, null, null);

            var grace = TimeSpan.FromMinutes(graceMinutes);

            // Minutes paused by a grace period that is still holding at `at`.
            // A grace period that has already ended pauses nothing: the driver
            // stayed past it, so its minutes are charged.
            var paused = new HashSet<int>();
            var pausedTo = 0;
            DateTime? graceUntil = null;
            DateTime? holdingUntil = null;
            foreach (var payment in settled)
            {
                var ends = payment.PaidAt + grace;
                if (graceUntil is null || ends > graceUntil)
                    graceUntil = ends;
                if (at > ends)
                    continue;

                if (holdingUntil is null || ends > holdingUntil)
                    holdingUntil = ends;

                var paid = ChargedMinutes(entry, payment.PaidAt);
                var from = Math.Max(
                    Math.Min(ChargedMinutes(entry, payment.PricedTo), paid),
                    paid - MaxPaymentDelayMinutes);
                var to = open ? Math.Max(n, ChargedMinutes(entry, ends)) : n;
                for (var m = from + 1; m <= to; m++)
                    paused.Add(m);
                pausedTo = Math.Max(pausedTo, to);
            }

            bool Chargeable(int m) => m > FirstHourMinutes && !paused.Contains(m);
            decimal PerMinute(int minutes) => Math.Round(minutes * ratePerHour / 60m, 2);

            var segments = new List<FeeSegment>
            {
                new(FeeSegmentKind.FirstHour, entry, firstHourEnd, FirstHourMinutes, ratePerHour)
            };

            // Walk minutes 61.. in runs of the same kind. Past now, only a grace
            // period still running is shown (an open visit), never future charges.
            var perMinute = 0;
            FeeSegmentKind? runKind = null;
            var runStart = 0;
            var last = 0;

            void Close(int endMinute)
            {
                var minutes = endMinute - runStart + 1;
                var amount = runKind == FeeSegmentKind.PerMinute ? PerMinute(minutes) : 0m;
                segments.Add(new FeeSegment(runKind!.Value,
                    entry.AddMinutes(runStart - 1), entry.AddMinutes(endMinute), minutes, amount));
            }

            var lastMinute = Math.Max(n, pausedTo);
            for (var m = FirstHourMinutes + 1; m <= lastMinute; m++)
            {
                var kind = Chargeable(m) ? FeeSegmentKind.PerMinute : FeeSegmentKind.Grace;
                if (m > n && kind == FeeSegmentKind.PerMinute)
                    break;
                if (kind == FeeSegmentKind.PerMinute)
                    perMinute++;
                if (runKind != kind)
                {
                    if (runKind is not null)
                        Close(m - 1);
                    runKind = kind;
                    runStart = m;
                }
                last = m;
            }
            if (runKind is not null)
                Close(last);

            var total = ratePerHour + PerMinute(perMinute);

            var state = n <= FirstHourMinutes ? MeterState.FirstHour
                : holdingUntil is not null ? MeterState.Paused
                : MeterState.Running;

            DateTime? nextAt = null;
            decimal? nextTotal = null;
            if (open)
            {
                if (holdingUntil is DateTime until && ChargedMinutes(entry, until) > FirstHourMinutes)
                {
                    // The grace period ending is the next change, and a big one:
                    // every minute it paused is charged at once.
                    nextAt = until;
                    nextTotal = Breakdown(ratePerHour, entry, until.AddSeconds(1), settled, graceMinutes, open: false).Total;
                }
                else
                {
                    for (var m = n + 1; m <= n + 24 * 60; m++)
                    {
                        if (!Chargeable(m)) continue;
                        nextAt = entry.AddMinutes(m - 1);
                        nextTotal = ratePerHour + PerMinute(perMinute + 1);
                        break;
                    }
                }
            }

            return new FeeBreakdown(total, n, perMinute, segments, firstHourEnd,
                graceUntil, state, nextAt, nextTotal);
        }
    }
}
