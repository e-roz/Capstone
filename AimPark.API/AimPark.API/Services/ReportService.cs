using AimPark.API.Data;
using AimPark.API.DTOs;
using AimPark.API.Entities;
using AimPark.API.Enums;
using AimPark.API.Helpers;
using AimPark.API.Interfaces;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace AimPark.API.Services
{
    public class ReportService : IReportService
    {
        private readonly AppDbContext _db;

        public ReportService(AppDbContext db)
        {
            _db = db;
        }

        // Resolves a request to Philippine days. "All time" starts from the
        // first thing the lot ever recorded.
        private async Task<ReportPeriod> ResolveAsync(ReportQuery query, CancellationToken ct)
        {
            DateOnly? earliest = null;
            if (query.AllTime)
            {
                var firstEntry = await _db.Set<ParkingLog>().MinAsync(l => (DateTime?)l.EntryTime, ct);
                var firstPayment = await _db.Set<PaymentTransaction>().MinAsync(p => (DateTime?)p.CreatedAt, ct);
                var first = new[] { firstEntry, firstPayment }.Where(d => d is not null).Min();
                if (first is DateTime f) earliest = PhilippineTime.LocalDate(f);
            }

            return ReportPeriod.From(query, PhilippineTime.Today(), earliest);
        }

        private static ReportPeriodInfo Info(ReportPeriod period) => new()
        {
            From = period.First,
            To = period.Last,
            Granularity = period.Granularity.ToString().ToLowerInvariant()
        };

        // GET /api/admin/reports/summary
        public async Task<ActionResult<ReportsSummaryResponse>> GetSummaryAsync(ReportQuery query, CancellationToken ct)
        {
            var period = await ResolveAsync(query, ct);
            var today = PhilippineTime.Today();
            var todayStart = PhilippineTime.StartOfDayUtc(today);
            var tomorrowStart = PhilippineTime.StartOfDayUtc(today.AddDays(1));

            var totalUsers = await _db.Set<User>().CountAsync(u => !u.IsDeleted, ct);
            var activeUsers = await _db.Set<User>()
                .CountAsync(u => !u.IsDeleted && u.AccountStatus == AccountStatus.Active, ct);

            // One definition of "free", the one the gates use to turn a car away:
            // working bays minus cars that have tapped in. The summary used to
            // count bays whose sensor said Available, which disagreed with the
            // parking map and the gate card whenever a bay had no signal or a
            // car had tapped in and not yet parked.
            var bays = await _db.Set<ParkingSlot>().AsNoTracking()
                .Select(s => new { s.VehicleType, s.Status })
                .ToListAsync(ct);
            var insideTypes = await _db.Set<ParkingLog>().AsNoTracking()
                .Where(l => l.ExitTime == null)
                .Select(l => l.VehicleType ?? (l.Slot == null ? null : l.Slot.VehicleType))
                .ToListAsync(ct);

            var room = ParkingCapacity.Of(bays.Select(b => (b.VehicleType, b.Status)), insideTypes);
            var usable = bays
                .Where(b => b.Status is not (ParkingSlotStatus.OutOfService or ParkingSlotStatus.NoSignal))
                .ToList();

            var sessionsToday = await _db.Set<ParkingLog>()
                .CountAsync(l => l.EntryTime >= todayStart && l.EntryTime < tomorrowStart, ct);
            var sessionsInPeriod = await _db.Set<ParkingLog>()
                .CountAsync(l => l.EntryTime >= period.StartUtc && l.EntryTime < period.EndUtc, ct);

            // Collected is by the day it was paid, not the day it was billed.
            // Fees and fines are kept apart: a violation penalty is money the
            // school is owed for a different reason than a parking fee.
            var paid = await _db.Set<PaymentTransaction>().AsNoTracking()
                .Where(p => p.Status == PaymentStatus.Paid && p.PaidAt != null
                         && p.PaidAt >= period.StartUtc && p.PaidAt < period.EndUtc)
                .GroupBy(p => p.Source)
                .Select(g => new { Source = g.Key, Amount = g.Sum(p => p.AmountDue) })
                .ToListAsync(ct);

            // Processing counts as outstanding. A bill someone opened a
            // checkout for and did not finish is still money the school has not
            // received, and leaving it out of this figure would quietly shrink
            // the amount owed every time a payer changed their mind.
            var owed = await _db.Set<PaymentTransaction>().AsNoTracking()
                .Where(p => p.Status == PaymentStatus.Pending || p.Status == PaymentStatus.Processing)
                .GroupBy(p => p.Source)
                .Select(g => new { Source = g.Key, Amount = g.Sum(p => p.AmountDue) })
                .ToListAsync(ct);

            var feesCollected = paid.Where(x => x.Source == PaymentSource.ParkingFee).Sum(x => x.Amount);
            var finesCollected = paid.Where(x => x.Source == PaymentSource.ViolationPenalty).Sum(x => x.Amount);
            var feesPending = owed.Where(x => x.Source == PaymentSource.ParkingFee).Sum(x => x.Amount);
            var finesPending = owed.Where(x => x.Source == PaymentSource.ViolationPenalty).Sum(x => x.Amount);

            var violationsIssued = await _db.Set<Violation>()
                .CountAsync(v => v.CreatedAt >= period.StartUtc && v.CreatedAt < period.EndUtc, ct);

            var openIncidents = await _db.Set<Incident>()
                .CountAsync(i => i.Status == IncidentStatus.Submitted || i.Status == IncidentStatus.UnderReview, ct);

            // Same rule as the Gate Taps page's "serious" refusals (LiveGateController).
            var seriousDenialsToday = await _db.Set<GateTapEvent>()
                .CountAsync(t => t.At >= todayStart && t.At < tomorrowStart
                    && !t.Opened && t.PersonKind != GateTapPersonKind.Manual
                    && (t.PersonKind == GateTapPersonKind.Unknown || t.PlateMatches == false), ct);

            // The stretch just before, of the same length, for "up 12%". Not
            // for all time: there is nothing before the first record.
            PreviousPeriodTotals? previous = null;
            if (!query.AllTime)
            {
                var before = new ReportPeriod(period.First.AddDays(-period.Days), period.First.AddDays(-1));
                var prevPaid = await _db.Set<PaymentTransaction>().AsNoTracking()
                    .Where(p => p.Status == PaymentStatus.Paid && p.PaidAt != null
                             && p.PaidAt >= before.StartUtc && p.PaidAt < before.EndUtc)
                    .SumAsync(p => (decimal?)p.AmountDue, ct) ?? 0m;
                previous = new PreviousPeriodTotals
                {
                    SessionsInPeriod = await _db.Set<ParkingLog>()
                        .CountAsync(l => l.EntryTime >= before.StartUtc && l.EntryTime < before.EndUtc, ct),
                    RevenueCollected = prevPaid,
                    ViolationsIssued = await _db.Set<Violation>()
                        .CountAsync(v => v.CreatedAt >= before.StartUtc && v.CreatedAt < before.EndUtc, ct)
                };
            }

            return new OkObjectResult(new ReportsSummaryResponse
            {
                Previous = previous,
                TotalUsers = totalUsers,
                ActiveUsers = activeUsers,
                TotalSlots = bays.Count,
                UsableSlots = usable.Count,
                AvailableSlots = room.Free,
                OccupiedSlots = Math.Max(0, usable.Count - room.Free),
                UsableFourWheel = usable.Count(b => b.VehicleType == VehicleType.Car),
                FreeFourWheel = room.FreeCars,
                UsableMotorcycle = usable.Count(b => b.VehicleType == VehicleType.Motorcycle),
                FreeMotorcycle = room.FreeMotorcycles,
                OutOfServiceSlots = bays.Count(b => b.Status == ParkingSlotStatus.OutOfService),
                NoSignalSlots = bays.Count(b => b.Status == ParkingSlotStatus.NoSignal),
                Period = Info(period),
                SessionsToday = sessionsToday,
                SessionsInPeriod = sessionsInPeriod,
                RevenueCollected = feesCollected + finesCollected,
                FeesCollected = feesCollected,
                FinesCollected = finesCollected,
                RevenuePending = feesPending + finesPending,
                FeesPending = feesPending,
                FinesPending = finesPending,
                ViolationsIssued = violationsIssued,
                OpenIncidents = openIncidents,
                SeriousDenialsToday = seriousDenialsToday
            });
        }

        // GET /api/admin/reports/occupancy-trend?days=14 | from=&to= | allTime=true
        public async Task<ActionResult<OccupancyTrendResponse>> GetOccupancyTrendAsync(
            ReportQuery query, CancellationToken ct)
        {
            var period = await ResolveAsync(query, ct);

            var entryTimes = await _db.Set<ParkingLog>().AsNoTracking()
                .Where(l => l.EntryTime >= period.StartUtc && l.EntryTime < period.EndUtc)
                .Select(l => l.EntryTime)
                .ToListAsync(ct);

            var counts = entryTimes
                .GroupBy(t => period.BucketOf(PhilippineTime.LocalDate(t)))
                .ToDictionary(g => g.Key, g => g.Count());

            var points = period.Buckets()
                .Select(b => new DailyCountPoint
                {
                    Date = b.ToDateTime(TimeOnly.MinValue),
                    Count = counts.GetValueOrDefault(b)
                })
                .ToList();

            return new OkObjectResult(new OccupancyTrendResponse { Period = Info(period), Points = points });
        }

        // GET /api/admin/reports/entry-exit?days=30 | from=&to= | allTime=true
        public async Task<ActionResult<EntryExitReportResponse>> GetEntryExitReportAsync(
            ReportQuery query, CancellationToken ct)
        {
            var period = await ResolveAsync(query, ct);

            // One pass over the window. Exits are counted by the day they
            // happened, which is not always the day of the entry - an overnight
            // session belongs to both days, once on each side.
            var sessions = await _db.Set<ParkingLog>().AsNoTracking()
                .Where(l => (l.EntryTime >= period.StartUtc && l.EntryTime < period.EndUtc)
                         || (l.ExitTime != null && l.ExitTime >= period.StartUtc && l.ExitTime < period.EndUtc))
                .Select(l => new
                {
                    l.EntryTime,
                    l.ExitTime,
                    IsVisitor = l.VisitorPassId != null
                })
                .ToListAsync(ct);

            var entries = new Dictionary<DateOnly, int>();
            var exits = new Dictionary<DateOnly, int>();
            var visitorEntries = new Dictionary<DateOnly, int>();
            var stillOpen = 0;

            foreach (var s in sessions)
            {
                if (period.Contains(s.EntryTime))
                {
                    var bucket = period.BucketOf(PhilippineTime.LocalDate(s.EntryTime));
                    entries[bucket] = entries.GetValueOrDefault(bucket) + 1;
                    if (s.IsVisitor)
                        visitorEntries[bucket] = visitorEntries.GetValueOrDefault(bucket) + 1;
                    if (s.ExitTime is null)
                        stillOpen++;
                }

                if (s.ExitTime is DateTime x && period.Contains(x))
                {
                    var bucket = period.BucketOf(PhilippineTime.LocalDate(x));
                    exits[bucket] = exits.GetValueOrDefault(bucket) + 1;
                }
            }

            var points = period.Buckets()
                .Select(b => new EntryExitPoint
                {
                    Date = b.ToDateTime(TimeOnly.MinValue),
                    Entries = entries.GetValueOrDefault(b),
                    Exits = exits.GetValueOrDefault(b),
                    VisitorEntries = visitorEntries.GetValueOrDefault(b)
                })
                .ToList();

            return new OkObjectResult(new EntryExitReportResponse
            {
                Period = Info(period),
                Points = points,
                TotalEntries = points.Sum(p => p.Entries),
                TotalExits = points.Sum(p => p.Exits),
                TotalVisitorEntries = points.Sum(p => p.VisitorEntries),
                StillOpen = stillOpen
            });
        }

        // GET /api/admin/reports/gate-outcomes?days=14 | from=&to= | allTime=true
        public async Task<ActionResult<GateOutcomesResponse>> GetGateOutcomesAsync(
            ReportQuery query, CancellationToken ct)
        {
            var period = await ResolveAsync(query, ct);

            // Same split as the Gate Taps page: a card nobody holds, or a plate
            // that is not the holder's, is serious; anything else refused is routine.
            var counts = await _db.Set<GateTapEvent>().AsNoTracking()
                .Where(t => t.At >= period.StartUtc && t.At < period.EndUtc
                         && t.PersonKind != GateTapPersonKind.Manual)
                .GroupBy(_ => 1)
                .Select(g => new
                {
                    Entered = g.Count(t => t.Opened && t.Direction == "IN"),
                    Exited = g.Count(t => t.Opened && t.Direction == "OUT"),
                    Mismatch = g.Count(t => !t.Opened && t.PersonKind != GateTapPersonKind.Unknown
                        && t.PlateMatches == false),
                    Unknown = g.Count(t => !t.Opened && t.PersonKind == GateTapPersonKind.Unknown),
                    Routine = g.Count(t => !t.Opened && t.PersonKind != GateTapPersonKind.Unknown
                        && (t.PlateMatches == null || t.PlateMatches == true))
                })
                .FirstOrDefaultAsync(ct);

            return new OkObjectResult(new GateOutcomesResponse
            {
                Period = Info(period),
                Entered = counts?.Entered ?? 0,
                Exited = counts?.Exited ?? 0,
                PlateMismatch = counts?.Mismatch ?? 0,
                UnknownCard = counts?.Unknown ?? 0,
                RoutineRefusals = counts?.Routine ?? 0
            });
        }

        // GET /api/admin/reports/peak-occupancy?days=14 | from=&to= | allTime=true
        public async Task<ActionResult<PeakOccupancyResponse>> GetPeakOccupancyAsync(
            ReportQuery query, CancellationToken ct)
        {
            var period = await ResolveAsync(query, ct);

            var sessions = await _db.Set<ParkingLog>().AsNoTracking()
                .Where(l => l.EntryTime < period.EndUtc
                         && (l.ExitTime == null || l.ExitTime >= period.StartUtc))
                .Select(l => new { l.EntryTime, l.ExitTime })
                .ToListAsync(ct);

            // Sweep the period: +1 when a car comes in (or at the start, if it
            // was already inside), -1 when it leaves. A car still inside counts
            // until the period ends. At the same moment, leaving goes first, so
            // a car leaving as another arrives is not counted twice.
            var events = new List<(DateTime At, int Delta)>(sessions.Count * 2);
            foreach (var s in sessions)
            {
                var start = s.EntryTime < period.StartUtc ? period.StartUtc : s.EntryTime;
                events.Add((start, +1));
                if (s.ExitTime is DateTime exit && exit < period.EndUtc)
                    events.Add((exit, -1));
            }

            var inside = 0;
            var peak = 0;
            DateTime? peakAt = null;
            foreach (var e in events.OrderBy(e => e.At).ThenBy(e => e.Delta))
            {
                inside += e.Delta;
                if (inside > peak)
                {
                    peak = inside;
                    peakAt = e.At;
                }
            }

            var capacity = await _db.Set<ParkingSlot>().AsNoTracking()
                .CountAsync(s => s.Status != ParkingSlotStatus.OutOfService
                              && s.Status != ParkingSlotStatus.NoSignal, ct);

            return new OkObjectResult(new PeakOccupancyResponse
            {
                Period = Info(period),
                Peak = peak,
                At = peakAt,
                Capacity = capacity
            });
        }

        // GET /api/admin/reports/peak-hours?days=30 | from=&to= | allTime=true
        public async Task<ActionResult<PeakHoursResponse>> GetPeakHoursAsync(ReportQuery query, CancellationToken ct)
        {
            var period = await ResolveAsync(query, ct);

            var entryTimes = await _db.Set<ParkingLog>().AsNoTracking()
                .Where(l => l.EntryTime >= period.StartUtc && l.EntryTime < period.EndUtc)
                .Select(l => l.EntryTime)
                .ToListAsync(ct);

            // The Philippine hour: the stored UTC hour read as if it were local
            // put the morning rush in the middle of the afternoon.
            var byHour = entryTimes
                .GroupBy(PhilippineTime.LocalHour)
                .ToDictionary(g => g.Key, g => g.Count());

            var points = Enumerable.Range(0, 24)
                .Select(hour => new PeakHourPoint { Hour = hour, Count = byHour.GetValueOrDefault(hour) })
                .ToList();

            return new OkObjectResult(new PeakHoursResponse { Period = Info(period), Points = points });
        }

        // GET /api/admin/reports/violations-breakdown[?days= | from=&to= | allTime=true]
        public async Task<ActionResult<ViolationBreakdownResponse>> GetViolationBreakdownAsync(
            ReportQuery? query, CancellationToken ct)
        {
            // With no range at all it is every violation ever, as before.
            var violations = _db.Set<Violation>().AsQueryable();
            if (query is { HasRange: true })
            {
                var period = await ResolveAsync(query, ct);
                violations = violations.Where(v => v.CreatedAt >= period.StartUtc && v.CreatedAt < period.EndUtc);
            }

            var byStatus = await violations
                .GroupBy(v => v.Status)
                .Select(g => new ViolationStatusCount { Status = g.Key.ToString(), Count = g.Count() })
                .ToListAsync(ct);

            var byRule = await violations
                .GroupBy(v => v.PolicyRule.Title)
                .Select(g => new ViolationRuleCount { RuleTitle = g.Key, Count = g.Count() })
                .OrderByDescending(r => r.Count)
                .Take(10)
                .ToListAsync(ct);

            return new OkObjectResult(new ViolationBreakdownResponse { ByStatus = byStatus, ByRule = byRule });
        }

        // GET /api/admin/reports/revenue-trend?days=14 | from=&to= | allTime=true
        public async Task<ActionResult<RevenueTrendResponse>> GetRevenueTrendAsync(
            ReportQuery query, CancellationToken ct)
        {
            var period = await ResolveAsync(query, ct);

            var paidPayments = await _db.Set<PaymentTransaction>().AsNoTracking()
                .Where(p => p.Status == PaymentStatus.Paid && p.PaidAt != null
                         && p.PaidAt >= period.StartUtc && p.PaidAt < period.EndUtc)
                .Select(p => new { p.PaidAt, p.AmountDue, p.Source })
                .ToListAsync(ct);

            var byBucket = paidPayments
                .GroupBy(p => period.BucketOf(PhilippineTime.LocalDate(p.PaidAt!.Value)))
                .ToDictionary(g => g.Key, g => g.ToList());

            var points = period.Buckets()
                .Select(b =>
                {
                    var rows = byBucket.GetValueOrDefault(b) ?? [];
                    var fees = rows.Where(r => r.Source == PaymentSource.ParkingFee).Sum(r => r.AmountDue);
                    var fines = rows.Where(r => r.Source == PaymentSource.ViolationPenalty).Sum(r => r.AmountDue);
                    return new RevenuePoint
                    {
                        Date = b.ToDateTime(TimeOnly.MinValue),
                        Amount = fees + fines,
                        Fees = fees,
                        Fines = fines
                    };
                })
                .ToList();

            return new OkObjectResult(new RevenueTrendResponse { Period = Info(period), Points = points });
        }
    }
}
