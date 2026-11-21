namespace AimPark.API.Helpers
{
    public enum FeeSegmentKind { FirstHour, PerMinute, Grace }

    /// <summary>What the meter is doing right now.</summary>
    public enum MeterState { Free, FirstHour, Running, Paused }

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
    /// every started minute costs rate ÷ 60. After each settled payment the meter
    /// pauses for the grace (7 minutes), and grace minutes are never charged.
    /// </remarks>
    public static class ParkingFeeMath
    {
        public const int FirstHourMinutes = 60;

        /// <summary>
        /// The minute <paramref name="at"/> falls in, counted from entry. A started
        /// minute is a charged minute.
        /// </summary>
        public static int ChargedMinutes(DateTime entry, DateTime at)
            => Math.Max(0, (int)Math.Ceiling((at - entry).TotalMinutes));

        /// <param name="settledAt">When each settled payment was made. Each starts a grace pause.</param>
        /// <param name="open">
        /// True while the car is inside: a grace still running is shown to its end.
        /// False for a finished visit: the last grace stops at the exit.
        /// </param>
        public static FeeBreakdown Breakdown(
            decimal ratePerHour, DateTime entry, DateTime at,
            IReadOnlyList<DateTime> settledAt, int graceMinutes, bool open = true)
        {
            var firstHourEnd = entry.AddMinutes(FirstHourMinutes);
            var n = Math.Max(1, ChargedMinutes(entry, at));

            if (ratePerHour <= 0m)
                return new FeeBreakdown(0m, n, 0, [], firstHourEnd, null, MeterState.Free, null, null);

            // Minutes the meter is paused for, and the latest minute any grace reaches.
            var paused = new HashSet<int>();
            var graceEnd = 0;
            foreach (var paidAt in settledAt)
            {
                var k = ChargedMinutes(entry, paidAt);
                for (var m = k + 1; m <= k + graceMinutes; m++)
                    paused.Add(m);
                graceEnd = Math.Max(graceEnd, k + graceMinutes);
            }

            bool Chargeable(int m) => m > FirstHourMinutes && !paused.Contains(m);
            decimal PerMinute(int minutes) => Math.Round(minutes * ratePerHour / 60m, 2);

            var segments = new List<FeeSegment>
            {
                new(FeeSegmentKind.FirstHour, entry, firstHourEnd, FirstHourMinutes, ratePerHour)
            };

            // Walk minutes 61.. in runs of the same kind. Past now, only a grace
            // still running is shown (an open visit), never future charges.
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

            var lastMinute = open ? Math.Max(n, graceEnd) : n;
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
                : paused.Contains(n) || paused.Contains(n + 1) ? MeterState.Paused
                : MeterState.Running;

            DateTime? nextAt = null;
            decimal? nextTotal = null;
            if (open)
            {
                for (var m = n + 1; m <= n + 24 * 60; m++)
                {
                    if (!Chargeable(m)) continue;
                    nextAt = entry.AddMinutes(m - 1);
                    nextTotal = ratePerHour + PerMinute(perMinute + 1);
                    break;
                }
            }

            return new FeeBreakdown(total, n, perMinute, segments, firstHourEnd,
                graceEnd > 0 ? entry.AddMinutes(graceEnd) : null, state, nextAt, nextTotal);
        }

        /// <summary>
        /// Temporary, removed in Task 6: the old per-minute price with a floor,
        /// kept only so the callers still compile until they move to Breakdown.
        /// </summary>
        [Obsolete("Use Breakdown. Removed in Task 6.")]
        public static decimal Price(decimal ratePerHour, decimal minimumFee, int minutes)
        {
            var metered = Math.Round(ratePerHour / 60m * minutes, 2);
            return metered > 0m && metered < minimumFee ? minimumFee : metered;
        }

        [Obsolete("Use Breakdown. Removed in Task 6.")]
        public static decimal Metered(decimal ratePerHour, int minutes) => Math.Round(ratePerHour / 60m * minutes, 2);

        [Obsolete("Use Breakdown. Removed in Task 6.")]
        public static (DateTime At, decimal Amount)? NextChange(decimal ratePerHour, decimal minimumFee, DateTime entry, DateTime at)
        {
            if (ratePerHour <= 0m) return null;
            var now = ChargedMinutes(entry, at);
#pragma warning disable CS0618
            var current = Price(ratePerHour, minimumFee, now);
            for (var m = now + 1; m <= now + 24 * 60; m++)
            {
                var amount = Price(ratePerHour, minimumFee, m);
                if (amount > current) return (entry.AddMinutes(m - 1), amount);
            }
#pragma warning restore CS0618
            return null;
        }
    }
}
