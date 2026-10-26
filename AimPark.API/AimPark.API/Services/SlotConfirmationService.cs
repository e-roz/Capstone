using AimPark.API.Data;
using AimPark.API.DTOs;
using AimPark.API.Entities;
using AimPark.API.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace AimPark.API.Services
{
    /// <summary>
    /// Lets a driver say which bay they parked in, so an administrator looking
    /// at a bay later can see who was in it without reading every gate tap.
    ///
    /// Deliberately does not touch <see cref="ParkingSlot.Status"/>: whether a
    /// bay is occupied is the sensors' to say, and a driver's word must never
    /// hide a sensor fault or fake an occupied bay.
    ///
    /// The bay may be in either column and of either kind. The lot is one lane
    /// and a driver may park wherever they like; a bay of the wrong kind is
    /// still flagged by the sensor-driven wrong-bay check, so refusing it here
    /// would only stop the driver from telling the truth.
    /// </summary>
    public class SlotConfirmationService : ISlotConfirmationService
    {
        /// <summary>Manila has no daylight saving, so a fixed offset is exact.</summary>
        private static readonly TimeSpan Manila = TimeSpan.FromHours(8);

        private readonly AppDbContext _db;

        public SlotConfirmationService(AppDbContext db)
        {
            _db = db;
        }

        public async Task<ConfirmSlotResponse> ConfirmAsync(
            Guid userId, ConfirmSlotRequest request, CancellationToken ct)
        {
            var log = await _db.Set<ParkingLog>()
                .FirstOrDefaultAsync(l => l.Id == request.LogId && l.UserId == userId, ct);
            if (log is null)
                return Refuse(SlotConfirmResult.LogNotFound, "We could not find that parking session.");

            var slot = await _db.Set<ParkingSlot>().AsNoTracking()
                .FirstOrDefaultAsync(s => s.Id == request.SlotId, ct);
            if (slot is null)
                return Refuse(SlotConfirmResult.SlotNotFound, "That bay does not exist.");

            var now = DateTime.UtcNow;

            // An open session can always be confirmed. After leaving, the driver
            // has until the end of the day they came in: past that, nobody
            // remembers reliably and a confirm would only add noise.
            if (log.ExitTime is not null && ManilaDay(now) != ManilaDay(log.EntryTime))
                return Refuse(SlotConfirmResult.TooLate, "That session ended on an earlier day, so the bay can no longer be confirmed.");

            // Two confirmed drivers cannot be in one bay at once. The sessions
            // only clash when they overlap in time, so a bay used by someone
            // else this morning can still be confirmed this afternoon.
            var start = log.EntryTime;
            var end = log.ExitTime ?? DateTime.MaxValue;
            var clash = await _db.Set<ParkingLog>().AsNoTracking().AnyAsync(l =>
                l.Id != log.Id
                && l.SlotId == slot.Id
                && l.SlotConfirmedAt != null
                && l.EntryTime < end
                && (l.ExitTime == null || l.ExitTime > start), ct);
            if (clash)
                return Refuse(SlotConfirmResult.SlotTaken, $"{slot.SlotCode} is already confirmed by someone else. Check the bay and try again.");

            log.SlotId = slot.Id;
            log.SlotConfirmedAt = now;
            await _db.SaveChangesAsync(ct);

            return new ConfirmSlotResponse
            {
                Result = SlotConfirmResult.Confirmed,
                SlotId = slot.Id,
                SlotCode = slot.SlotCode,
                Late = log.ExitTime is not null,
            };
        }

        private static DateOnly ManilaDay(DateTime utc)
            => DateOnly.FromDateTime(DateTime.SpecifyKind(utc, DateTimeKind.Utc).Add(Manila));

        private static ConfirmSlotResponse Refuse(string result, string message)
            => new() { Result = result, Message = message };
    }
}
