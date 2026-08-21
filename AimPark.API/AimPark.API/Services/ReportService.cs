using AimPark.API.Data;
using AimPark.API.DTOs;
using AimPark.API.Entities;
using AimPark.API.Enums;
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

        // GET /api/admin/reports/summary
        public async Task<ActionResult<ReportsSummaryResponse>> GetSummaryAsync(CancellationToken ct)
        {
            var today = DateTime.UtcNow.Date;
            var tomorrow = today.AddDays(1);

            var totalUsers = await _db.Set<User>().CountAsync(u => !u.IsDeleted, ct);
            var activeUsers = await _db.Set<User>()
                .CountAsync(u => !u.IsDeleted && u.AccountStatus == AccountStatus.Active, ct);

            var totalSlots = await _db.Set<ParkingSlot>().CountAsync(ct);
            var occupiedSlots = await _db.Set<ParkingSlot>()
                .CountAsync(s => s.Status == ParkingSlotStatus.Occupied, ct);

            // Counted, not derived. `total - occupied` treated an out-of-service
            // bay as free space, so a lot with 2 cars and 8 broken bays reported
            // 8 available — the dashboard's headline number was wrong whenever
            // any bay was down. Reserved bays are not free either, so counting
            // Available directly is the only definition that stays honest as
            // more statuses are added.
            var availableSlots = await _db.Set<ParkingSlot>()
                .CountAsync(s => s.Status == ParkingSlotStatus.Available, ct);

            var outOfServiceSlots = await _db.Set<ParkingSlot>()
                .CountAsync(s => s.Status == ParkingSlotStatus.OutOfService, ct);

            var sessionsToday = await _db.Set<ParkingLog>()
                .CountAsync(l => l.EntryTime >= today && l.EntryTime < tomorrow, ct);

            var revenueCollected = await _db.Set<PaymentTransaction>()
                .Where(p => p.Status == PaymentStatus.Paid)
                .SumAsync(p => (decimal?)p.AmountDue, ct) ?? 0;

            var revenuePending = await _db.Set<PaymentTransaction>()
                .Where(p => p.Status == PaymentStatus.Pending)
                .SumAsync(p => (decimal?)p.AmountDue, ct) ?? 0;

            var violationsIssued = await _db.Set<Violation>().CountAsync(ct);

            var openIncidents = await _db.Set<Incident>()
                .CountAsync(i => i.Status == IncidentStatus.Submitted || i.Status == IncidentStatus.UnderReview, ct);

            return new OkObjectResult(new ReportsSummaryResponse
            {
                TotalUsers = totalUsers,
                ActiveUsers = activeUsers,
                TotalSlots = totalSlots,
                OccupiedSlots = occupiedSlots,
                AvailableSlots = availableSlots,
                OutOfServiceSlots = outOfServiceSlots,
                SessionsToday = sessionsToday,
                RevenueCollected = revenueCollected,
                RevenuePending = revenuePending,
                ViolationsIssued = violationsIssued,
                OpenIncidents = openIncidents
            });
        }

        // GET /api/admin/reports/occupancy-trend?days=14
        public async Task<ActionResult<OccupancyTrendResponse>> GetOccupancyTrendAsync(int days, CancellationToken ct)
        {
            days = Math.Clamp(days, 1, 90);
            var since = DateTime.UtcNow.Date.AddDays(-(days - 1));

            var entryTimes = await _db.Set<ParkingLog>()
                .Where(l => l.EntryTime >= since)
                .Select(l => l.EntryTime)
                .ToListAsync(ct);

            var points = new List<DailyCountPoint>();
            for (var i = 0; i < days; i++)
            {
                var day = since.AddDays(i);
                var count = entryTimes.Count(t => t.Date == day);
                points.Add(new DailyCountPoint { Date = day, Count = count });
            }

            return new OkObjectResult(new OccupancyTrendResponse { Points = points });
        }

        // GET /api/admin/reports/peak-hours?days=30
        public async Task<ActionResult<PeakHoursResponse>> GetPeakHoursAsync(int days, CancellationToken ct)
        {
            days = Math.Clamp(days, 1, 90);
            var since = DateTime.UtcNow.Date.AddDays(-(days - 1));

            var entryTimes = await _db.Set<ParkingLog>()
                .Where(l => l.EntryTime >= since)
                .Select(l => l.EntryTime)
                .ToListAsync(ct);

            var points = Enumerable.Range(0, 24)
                .Select(hour => new PeakHourPoint
                {
                    Hour = hour,
                    Count = entryTimes.Count(t => t.Hour == hour)
                })
                .ToList();

            return new OkObjectResult(new PeakHoursResponse { Points = points });
        }

        // GET /api/admin/reports/violations-breakdown
        public async Task<ActionResult<ViolationBreakdownResponse>> GetViolationBreakdownAsync(CancellationToken ct)
        {
            var byStatus = await _db.Set<Violation>()
                .GroupBy(v => v.Status)
                .Select(g => new ViolationStatusCount { Status = g.Key.ToString(), Count = g.Count() })
                .ToListAsync(ct);

            var byRule = await _db.Set<Violation>()
                .GroupBy(v => v.PolicyRule.Title)
                .Select(g => new ViolationRuleCount { RuleTitle = g.Key, Count = g.Count() })
                .OrderByDescending(r => r.Count)
                .Take(10)
                .ToListAsync(ct);

            return new OkObjectResult(new ViolationBreakdownResponse { ByStatus = byStatus, ByRule = byRule });
        }

        // GET /api/admin/reports/revenue-trend?days=14
        public async Task<ActionResult<RevenueTrendResponse>> GetRevenueTrendAsync(int days, CancellationToken ct)
        {
            days = Math.Clamp(days, 1, 90);
            var since = DateTime.UtcNow.Date.AddDays(-(days - 1));

            var paidPayments = await _db.Set<PaymentTransaction>()
                .Where(p => p.Status == PaymentStatus.Paid && p.PaidAt != null && p.PaidAt >= since)
                .Select(p => new { p.PaidAt, p.AmountDue })
                .ToListAsync(ct);

            var points = new List<RevenuePoint>();
            for (var i = 0; i < days; i++)
            {
                var day = since.AddDays(i);
                var amount = paidPayments.Where(p => p.PaidAt!.Value.Date == day).Sum(p => p.AmountDue);
                points.Add(new RevenuePoint { Date = day, Amount = amount });
            }

            return new OkObjectResult(new RevenueTrendResponse { Points = points });
        }
    }
}
