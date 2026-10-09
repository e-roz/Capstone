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
    /// Raises and clears "wrong kind of vehicle in this bay" warnings as the
    /// slot sensors report, and records a guard's verdict on them.
    /// </summary>
    /// <remarks>
    /// The warning is deliberately generic: it names the bay, not a driver.
    /// The sensor cannot say who parked, so who to fine, if anyone, is for the
    /// person who goes and looks. See <see cref="WrongBayRule"/>.
    /// </remarks>
    public class WrongBayService : IWrongBayService
    {
        private readonly AppDbContext _db;
        private readonly INotificationService _notifications;
        private readonly ILogger<WrongBayService> _logger;

        public WrongBayService(AppDbContext db, INotificationService notifications, ILogger<WrongBayService> logger)
        {
            _db = db;
            _notifications = notifications;
            _logger = logger;
        }

        public async Task OnBayFilledAsync(Guid slotId, CancellationToken ct)
        {
            try
            {
                // One warning per stay in the bay, however often the sensor
                // repeats itself.
                var alreadyWarned = await _db.Set<WrongBayFlag>()
                    .AnyAsync(f => f.SlotId == slotId && f.BayClearedAt == null, ct);
                if (alreadyWarned) return;

                var bays = await _db.Set<ParkingSlot>().AsNoTracking()
                    .Select(s => new { s.Id, s.SlotCode, s.VehicleType, s.Status })
                    .ToListAsync(ct);

                var filled = bays.FirstOrDefault(b => b.Id == slotId);
                if (filled is null) return;

                var inside = await _db.Set<ParkingLog>().AsNoTracking()
                    .Where(l => l.ExitTime == null)
                    .Select(l => new WrongBayRule.Session(l.VehicleType, l.SlotId, l.EntryTime))
                    .ToListAsync(ct);

                var now = DateTime.UtcNow;
                var warn = WrongBayRule.ShouldWarn(
                    new WrongBayRule.Bay(filled.Id, filled.VehicleType, filled.Status),
                    bays.Select(b => new WrongBayRule.Bay(b.Id, b.VehicleType, b.Status)).ToList(),
                    inside,
                    now);
                if (!warn) return;

                _db.Set<WrongBayFlag>().Add(new WrongBayFlag
                {
                    SlotId = slotId,
                    DetectedAt = now,
                    UpdatedAt = now
                });
                await _db.SaveChangesAsync(ct);

                var bayKind = filled.VehicleType == VehicleType.Motorcycle ? "motorcycle" : "four-wheel";
                await _notifications.NotifyRoleAsync(
                    UserRole.Security,
                    NotificationType.System,
                    $"Check bay {filled.SlotCode}",
                    $"Bay {filled.SlotCode} is a {bayKind} bay, and the wrong kind of vehicle may be parked in it. Please go and check.",
                    ct);
            }
            catch (Exception ex) when (ex is not OperationCanceledException)
            {
                _logger.LogError(ex, "Could not check bay {SlotId} for a wrong vehicle.", slotId);
            }
        }

        public async Task OnBayEmptiedAsync(Guid slotId, CancellationToken ct)
        {
            try
            {
                var live = await _db.Set<WrongBayFlag>()
                    .Where(f => f.SlotId == slotId && f.BayClearedAt == null)
                    .ToListAsync(ct);
                if (live.Count == 0) return;

                var now = DateTime.UtcNow;
                foreach (var flag in live)
                {
                    flag.BayClearedAt = now;
                    flag.UpdatedAt = now;
                }
                await _db.SaveChangesAsync(ct);
            }
            catch (Exception ex) when (ex is not OperationCanceledException)
            {
                _logger.LogError(ex, "Could not clear the wrong-bay warning on {SlotId}.", slotId);
            }
        }

        public async Task<ActionResult<List<WrongBayFlagResponse>>> ListLiveAsync(CancellationToken ct)
        {
            var flags = await _db.Set<WrongBayFlag>().AsNoTracking()
                .Where(f => f.BayClearedAt == null && f.Status != WrongBayFlagStatus.FalseAlarm)
                .OrderBy(f => f.DetectedAt)
                .Select(f => new WrongBayFlagResponse
                {
                    FlagId = f.Id,
                    SlotId = f.SlotId,
                    SlotCode = f.Slot.SlotCode,
                    Gate = f.Slot.Gate,
                    BayType = f.Slot.VehicleType == null ? null : f.Slot.VehicleType.ToString(),
                    Status = f.Status.ToString(),
                    DetectedAt = f.DetectedAt,
                    ReviewedAt = f.ReviewedAt,
                    ReviewedByName = _db.Set<User>()
                        .Where(u => u.Id == f.ReviewedByUserId)
                        .Select(u => u.FullName)
                        .FirstOrDefault()
                })
                .ToListAsync(ct);

            return new OkObjectResult(flags);
        }

        public async Task<ActionResult<object>> ReviewAsync(
            Guid flagId, ReviewWrongBayFlagDto dto, Guid reviewerUserId, CancellationToken ct)
        {
            if (!Enum.TryParse<WrongBayFlagStatus>(dto.Outcome, ignoreCase: true, out var outcome)
                || outcome == WrongBayFlagStatus.Open)
                return new BadRequestObjectResult(new { message = "Outcome must be Confirmed or FalseAlarm." });

            var flag = await _db.Set<WrongBayFlag>().FirstOrDefaultAsync(f => f.Id == flagId, ct);
            if (flag is null)
                return new NotFoundObjectResult(new { message = "Warning not found." });

            var now = DateTime.UtcNow;
            flag.Status = outcome;
            flag.ReviewedByUserId = reviewerUserId;
            flag.ReviewedAt = now;
            flag.UpdatedAt = now;
            await _db.SaveChangesAsync(ct);

            return new OkObjectResult(new
            {
                message = outcome == WrongBayFlagStatus.Confirmed
                    ? "Marked as confirmed."
                    : "Marked as a false alarm."
            });
        }
    }
}
