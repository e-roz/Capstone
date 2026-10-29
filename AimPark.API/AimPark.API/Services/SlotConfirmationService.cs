using AimPark.API.Data;
using AimPark.API.DTOs;
using AimPark.API.Entities;
using AimPark.API.Enums;
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
    /// The bay may be in either column, but must be of the kind of vehicle that
    /// came in: a motorcycle cannot be confirmed into a car bay, nor a car into
    /// a motorcycle bay. What came in is what the gate recorded on the session;
    /// when it could not tell (both kinds on the account, no plate read), the
    /// driver says which vehicle they brought.
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

            var kind = await VehicleKindAsync(userId, log, request.VehicleId, ct);
            if (kind.Refusal is not null)
                return kind.Refusal;

            // A bay with no kind set takes either.
            if (kind.Type is VehicleType type && slot.VehicleType is VehicleType bayType && bayType != type)
                return Refuse(SlotConfirmResult.WrongVehicleType,
                    $"{slot.SlotCode} is a {Describe(bayType)} bay, and you came in on a {Describe(type)}. Pick a {Describe(type)} bay.");

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
            // The driver's word, kept for when the gate could not tell.
            log.VehicleType ??= kind.Type;
            await _db.SaveChangesAsync(ct);

            return new ConfirmSlotResponse
            {
                Result = SlotConfirmResult.Confirmed,
                SlotId = slot.Id,
                SlotCode = slot.SlotCode,
                Late = log.ExitTime is not null,
            };
        }

        /// <summary>
        /// What this session came in on: the gate's record, else the vehicle the
        /// driver names, else the only kind on the account.
        /// </summary>
        private async Task<(VehicleType? Type, ConfirmSlotResponse? Refusal)> VehicleKindAsync(
            Guid userId, ParkingLog log, Guid? vehicleId, CancellationToken ct)
        {
            if (log.VehicleType is VehicleType recorded)
                return (recorded, null);

            var vehicles = await _db.Set<Vehicle>().AsNoTracking()
                .Where(v => v.UserId == userId)
                .Select(v => new { v.Id, v.VehicleType })
                .ToListAsync(ct);

            if (vehicleId is Guid id)
            {
                var named = vehicles.FirstOrDefault(v => v.Id == id);
                return named is null
                    ? (null, Refuse(SlotConfirmResult.VehicleNotFound, "That vehicle is not on your account."))
                    : (named.VehicleType, null);
            }

            var kinds = vehicles.Select(v => v.VehicleType).Distinct().ToList();
            return kinds.Count switch
            {
                // Nothing on file to go by; the bay's kind cannot be checked.
                0 => (null, null),
                1 => (kinds[0], null),
                _ => (null, Refuse(SlotConfirmResult.VehicleNeeded, "Tell us which vehicle you brought today, then confirm the bay."))
            };
        }

        private static string Describe(VehicleType type)
            => type == VehicleType.Motorcycle ? "motorcycle" : "car";

        private static DateOnly ManilaDay(DateTime utc)
            => DateOnly.FromDateTime(DateTime.SpecifyKind(utc, DateTimeKind.Utc).Add(Manila));

        private static ConfirmSlotResponse Refuse(string result, string message)
            => new() { Result = result, Message = message };
    }
}
