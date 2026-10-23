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
    /// <summary>
    /// Everything one account has done, for the tabs on the user's detail page.
    /// </summary>
    public class UserHistoryService : IUserHistoryService
    {
        private const int MaxPageSize = 100;

        /// <summary>How far back "possibly involved" looks for the person's sessions.</summary>
        private static readonly TimeSpan InvolvementHorizon = TimeSpan.FromDays(180);

        private readonly AppDbContext _db;

        public UserHistoryService(AppDbContext db)
        {
            _db = db;
        }

        private Task<bool> ExistsAsync(Guid userId, CancellationToken ct) =>
            _db.Set<User>().AsNoTracking().AnyAsync(u => u.Id == userId, ct);

        private static (int page, int size) Clamp(int page, int pageSize) =>
            (Math.Max(1, page), Math.Clamp(pageSize, 1, MaxPageSize));

        // GET /api/admin/users/{id}/history/summary
        public async Task<ActionResult<UserHistorySummary>> GetSummaryAsync(Guid userId, CancellationToken ct)
        {
            var user = await _db.Set<User>().AsNoTracking()
                .Where(u => u.Id == userId)
                .Select(u => new { u.Id, u.RfidTagId })
                .FirstOrDefaultAsync(ct);
            if (user is null)
                return new NotFoundObjectResult(new { message = "User not found." });

            var summary = new UserHistorySummary
            {
                Sessions = await _db.Set<ParkingLog>().CountAsync(l => l.UserId == userId, ct),
                Violations = await _db.Set<Violation>().CountAsync(v => v.UserId == userId, ct),
                IncidentsFiled = await _db.Set<Incident>().CountAsync(i => i.ReportedByUserId == userId, ct),
                IncidentsPossible = (await LoadPossiblyInvolvedAsync(userId, ct)).Count,
                Taps = string.IsNullOrWhiteSpace(user.RfidTagId)
                    ? 0
                    : await _db.Set<GateTapEvent>().CountAsync(t => t.RfidTagId == user.RfidTagId, ct)
            };

            var bills = await _db.Set<PaymentTransaction>().AsNoTracking()
                .Where(p => p.UserId == userId)
                .Select(p => new { p.Status, p.AmountDue, p.PaidAt })
                .ToListAsync(ct);

            summary.Owed = bills
                .Where(b => b.Status == PaymentStatus.Pending && b.AmountDue > 0m)
                .Sum(b => b.AmountDue);

            var yearStart = new DateTime(DateTime.UtcNow.Year, 1, 1, 0, 0, 0, DateTimeKind.Utc);
            summary.PaidThisYear = bills
                .Where(b => b.Status == PaymentStatus.Paid && b.PaidAt >= yearStart)
                .Sum(b => b.AmountDue);

            var inside = await _db.Set<ParkingLog>().AsNoTracking()
                .Where(l => l.UserId == userId && l.ExitTime == null)
                .OrderByDescending(l => l.EntryTime)
                .Select(l => new { l.EntryTime, SlotCode = l.Slot != null ? l.Slot.SlotCode : null })
                .FirstOrDefaultAsync(ct);
            if (inside is not null)
            {
                summary.IsInside = true;
                summary.InsideSince = inside.EntryTime;
                summary.InsideSlotCode = inside.SlotCode;
            }

            return new OkObjectResult(summary);
        }

        // GET /api/admin/users/{id}/history/sessions
        public async Task<ActionResult<UserHistoryPage<UserSessionItem>>> GetSessionsAsync(
            Guid userId, int page, int pageSize, DateTime? from, DateTime? to, int? gate, CancellationToken ct)
        {
            if (!await ExistsAsync(userId, ct))
                return new NotFoundObjectResult(new { message = "User not found." });

            var (p, size) = Clamp(page, pageSize);
            var logs = _db.Set<ParkingLog>().AsNoTracking().Where(l => l.UserId == userId);

            // A session counts when it overlapped the window, as on a bay's history.
            if (to is DateTime end) logs = logs.Where(l => l.EntryTime <= end);
            if (from is DateTime start) logs = logs.Where(l => l.ExitTime == null || l.ExitTime >= start);
            if (gate is int g) logs = logs.Where(l => l.Gate == g);

            var total = await logs.CountAsync(ct);
            var items = await logs
                .OrderByDescending(l => l.EntryTime)
                .Skip((p - 1) * size)
                .Take(size)
                .Select(l => new UserSessionItem
                {
                    Id = l.Id,
                    EntryTime = l.EntryTime,
                    ExitTime = l.ExitTime,
                    Gate = l.Gate,
                    SlotCode = l.Slot != null ? l.Slot.SlotCode : null,
                    SlotConfirmed = l.SlotConfirmedAt != null,
                    Plate = l.AlprPlateNumber,
                    PlateMatched = l.AlprMatched
                })
                .ToListAsync(ct);

            return new OkObjectResult(new UserHistoryPage<UserSessionItem> { Items = items, Total = total, Page = p, PageSize = size });
        }

        // GET /api/admin/users/{id}/history/violations
        public async Task<ActionResult<UserHistoryPage<UserViolationItem>>> GetViolationsAsync(
            Guid userId, int page, int pageSize, CancellationToken ct)
        {
            if (!await ExistsAsync(userId, ct))
                return new NotFoundObjectResult(new { message = "User not found." });

            var (p, size) = Clamp(page, pageSize);
            var query = _db.Set<Violation>().AsNoTracking().Where(v => v.UserId == userId);

            var total = await query.CountAsync(ct);
            var items = await query
                .OrderByDescending(v => v.CreatedAt)
                .Skip((p - 1) * size)
                .Take(size)
                .Select(v => new UserViolationItem
                {
                    Id = v.Id,
                    RuleTitle = v.PolicyRule.Title,
                    Status = v.Status.ToString(),
                    PenaltyAmount = v.PenaltyAmount,
                    CreatedAt = v.CreatedAt,
                    SlotCode = v.ParkingLog != null && v.ParkingLog.Slot != null ? v.ParkingLog.Slot.SlotCode : null,
                    SessionEntry = v.ParkingLog != null ? v.ParkingLog.EntryTime : null
                })
                .ToListAsync(ct);

            return new OkObjectResult(new UserHistoryPage<UserViolationItem> { Items = items, Total = total, Page = p, PageSize = size });
        }

        // GET /api/admin/users/{id}/history/incidents
        public async Task<ActionResult<UserIncidents>> GetIncidentsAsync(Guid userId, CancellationToken ct)
        {
            if (!await ExistsAsync(userId, ct))
                return new NotFoundObjectResult(new { message = "User not found." });

            var filed = await _db.Set<Incident>().AsNoTracking()
                .Where(i => i.ReportedByUserId == userId)
                .OrderByDescending(i => i.CreatedAt)
                .Take(100)
                .Select(i => new UserIncidentItem
                {
                    Id = i.Id,
                    Category = i.Category.ToString(),
                    Status = i.Status.ToString(),
                    CreatedAt = i.CreatedAt,
                    Location = i.Location
                })
                .ToListAsync(ct);

            await FillSlotCodesAsync(filed, ct);

            return new OkObjectResult(new UserIncidents
            {
                Filed = filed,
                PossiblyInvolved = await LoadPossiblyInvolvedAsync(userId, ct)
            });
        }

        // GET /api/admin/users/{id}/history/payments
        public async Task<ActionResult<UserHistoryPage<UserPaymentItem>>> GetPaymentsAsync(
            Guid userId, int page, int pageSize, CancellationToken ct)
        {
            if (!await ExistsAsync(userId, ct))
                return new NotFoundObjectResult(new { message = "User not found." });

            var (p, size) = Clamp(page, pageSize);
            var query = _db.Set<PaymentTransaction>().AsNoTracking().Where(x => x.UserId == userId);

            var total = await query.CountAsync(ct);
            var rows = await query
                .OrderByDescending(x => x.CreatedAt)
                .Skip((p - 1) * size)
                .Take(size)
                .Select(x => new
                {
                    x.Id, x.CreatedAt, x.PaidAt, x.AmountDue, x.Status, x.DurationMinutes,
                    IsFine = x.ViolationId != null
                })
                .ToListAsync(ct);

            var items = rows.Select(x => new UserPaymentItem
            {
                Id = x.Id,
                CreatedAt = x.CreatedAt,
                PaidAt = x.PaidAt,
                For = x.IsFine ? "Violation fine" : $"Parking · {x.DurationMinutes} min",
                Amount = x.AmountDue,
                Status = x.Status.ToString()
            }).ToList();

            return new OkObjectResult(new UserHistoryPage<UserPaymentItem> { Items = items, Total = total, Page = p, PageSize = size });
        }

        // Reports about a bay this person had a session in around the time it was
        // reported. Whoever filed the report is left out of their own list.
        private async Task<List<UserIncidentItem>> LoadPossiblyInvolvedAsync(Guid userId, CancellationToken ct)
        {
            var since = DateTime.UtcNow - InvolvementHorizon;

            var sessions = await _db.Set<ParkingLog>().AsNoTracking()
                .Where(l => l.UserId == userId && l.SlotId != null && (l.ExitTime == null || l.ExitTime >= since))
                .Select(l => new { SlotId = l.SlotId!.Value, l.EntryTime, l.ExitTime, Confirmed = l.SlotConfirmedAt != null })
                .ToListAsync(ct);
            if (sessions.Count == 0) return [];

            var slotIds = sessions.Select(s => s.SlotId).Distinct().ToList();
            var incidents = await _db.Set<Incident>().AsNoTracking()
                .Where(i => i.SlotId != null && slotIds.Contains(i.SlotId.Value) && i.ReportedByUserId != userId)
                .OrderByDescending(i => i.CreatedAt)
                .Select(i => new { i.Id, i.Category, i.Status, i.CreatedAt, i.Location, SlotId = i.SlotId!.Value })
                .ToListAsync(ct);

            var codes = await _db.Set<ParkingSlot>().AsNoTracking()
                .Where(s => slotIds.Contains(s.Id))
                .ToDictionaryAsync(s => s.Id, s => s.SlotCode, ct);

            var result = new List<UserIncidentItem>();
            foreach (var i in incidents)
            {
                var hit = sessions
                    .Where(s => s.SlotId == i.SlotId && IncidentInvolvement.Overlaps(s.EntryTime, s.ExitTime, i.CreatedAt))
                    .OrderByDescending(s => s.EntryTime)
                    .FirstOrDefault();
                if (hit is null) continue;

                result.Add(new UserIncidentItem
                {
                    Id = i.Id,
                    Category = i.Category.ToString(),
                    Status = i.Status.ToString(),
                    CreatedAt = i.CreatedAt,
                    Location = i.Location,
                    SlotCode = codes.GetValueOrDefault(i.SlotId),
                    InvolvedEntry = hit.EntryTime,
                    InvolvedExit = hit.ExitTime,
                    InvolvedConfirmed = hit.Confirmed
                });
            }

            return result;
        }

        private async Task FillSlotCodesAsync(List<UserIncidentItem> items, CancellationToken ct)
        {
            if (items.Count == 0) return;
            var ids = items.Select(i => i.Id).ToList();
            var slots = await _db.Set<Incident>().AsNoTracking()
                .Where(i => ids.Contains(i.Id) && i.SlotId != null)
                .Select(i => new { i.Id, SlotCode = _db.Set<ParkingSlot>().Where(s => s.Id == i.SlotId).Select(s => s.SlotCode).FirstOrDefault() })
                .ToDictionaryAsync(x => x.Id, x => x.SlotCode, ct);
            foreach (var item in items)
                item.SlotCode = slots.GetValueOrDefault(item.Id);
        }
    }
}
