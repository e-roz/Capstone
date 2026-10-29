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

            // A confirm is the driver taking responsibility for a bay, so it is
            // final: being able to switch bays would let someone step away from
            // one that turned out to have a problem. Mistakes go to an admin,
            // who corrects them with a recorded reason.
            if (log.SlotConfirmedAt is not null)
            {
                var confirmedCode = await _db.Set<ParkingSlot>().AsNoTracking()
                    .Where(s => s.Id == log.SlotId)
                    .Select(s => s.SlotCode)
                    .FirstOrDefaultAsync(ct);
                return Refuse(SlotConfirmResult.AlreadyConfirmed,
                    $"You already confirmed {confirmedCode ?? "a bay"} for this visit, and a confirmed bay can't be changed. If it's wrong, ask the parking office to correct it.");
            }

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

            if (await HeldByAnotherAsync(log, slot.Id, ct))
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

        public async Task<CorrectBayResponse> CorrectAsync(
            Guid adminUserId, Guid logId, CorrectBayRequest request, CancellationToken ct)
        {
            var reason = request.Reason?.Trim() ?? string.Empty;
            if (reason.Length == 0)
                return RefuseCorrection(BayCorrectResult.ReasonRequired, "Write why the bay is being corrected.");
            if (reason.Length > 500)
                return RefuseCorrection(BayCorrectResult.ReasonRequired, "Keep the reason under 500 characters.");

            var log = await _db.Set<ParkingLog>().FirstOrDefaultAsync(l => l.Id == logId, ct);
            if (log is null)
                return RefuseCorrection(BayCorrectResult.LogNotFound, "We could not find that parking session.");

            // Only the driver's confirm is corrected. Giving an unconfirmed
            // session a bay here would also clear it of not confirming.
            if (log.SlotConfirmedAt is null || log.SlotId is not Guid fromSlotId)
                return RefuseCorrection(BayCorrectResult.NotConfirmed, "The driver hasn't confirmed a bay for this visit, so there is nothing to correct.");

            var slot = await _db.Set<ParkingSlot>().AsNoTracking()
                .FirstOrDefaultAsync(s => s.Id == request.SlotId, ct);
            if (slot is null)
                return RefuseCorrection(BayCorrectResult.SlotNotFound, "That bay does not exist.");

            if (slot.Id == fromSlotId)
                return RefuseCorrection(BayCorrectResult.SameBay, $"This visit is already in {slot.SlotCode}.");

            if (await HeldByAnotherAsync(log, slot.Id, ct))
                return RefuseCorrection(BayCorrectResult.SlotTaken, $"{slot.SlotCode} is confirmed by another driver at the same time. Correct that visit first.");

            _db.Set<SlotConfirmCorrection>().Add(new SlotConfirmCorrection
            {
                ParkingLogId = log.Id,
                FromSlotId = fromSlotId,
                ToSlotId = slot.Id,
                Reason = reason,
                CorrectedByUserId = adminUserId,
                CorrectedAt = DateTime.UtcNow,
            });

            if (log.UserId is Guid driverId)
            {
                var fromCode = await _db.Set<ParkingSlot>().AsNoTracking()
                    .Where(s => s.Id == fromSlotId)
                    .Select(s => s.SlotCode)
                    .FirstOrDefaultAsync(ct);
                _db.Set<AdminAuditLog>().Add(new AdminAuditLog
                {
                    Id = Guid.NewGuid(),
                    AdminUserId = adminUserId,
                    TargetUserId = driverId,
                    Action = "BayConfirmCorrected",
                    OldValue = fromCode,
                    NewValue = slot.SlotCode,
                    Reason = reason,
                    CreatedAt = DateTime.UtcNow,
                });
            }

            // The confirm time stays the driver's: the correction moves the bay,
            // it does not make the driver confirm again.
            log.SlotId = slot.Id;
            await _db.SaveChangesAsync(ct);

            return new CorrectBayResponse { Result = BayCorrectResult.Corrected, SlotCode = slot.SlotCode };
        }

        public async Task<BayConfirmHistoryResponse?> GetHistoryAsync(Guid logId, CancellationToken ct)
        {
            var log = await _db.Set<ParkingLog>().AsNoTracking()
                .Where(l => l.Id == logId)
                .Select(l => new
                {
                    l.Id,
                    l.UserId,
                    l.EntryTime,
                    l.ExitTime,
                    l.SlotConfirmedAt,
                    SlotCode = l.Slot != null ? l.Slot.SlotCode : null,
                })
                .FirstOrDefaultAsync(ct);
            if (log is null) return null;

            var corrections = await _db.Set<SlotConfirmCorrection>().AsNoTracking()
                .Where(c => c.ParkingLogId == logId)
                .OrderBy(c => c.CorrectedAt)
                .Select(c => new BayCorrectionResponse
                {
                    FromSlotCode = c.FromSlot.SlotCode,
                    ToSlotCode = c.ToSlot.SlotCode,
                    Reason = c.Reason,
                    CorrectedByName = _db.Set<User>()
                        .Where(u => u.Id == c.CorrectedByUserId)
                        .Select(u => u.FullName)
                        .FirstOrDefault() ?? "An admin",
                    CorrectedAt = c.CorrectedAt,
                })
                .ToListAsync(ct);

            var confirmed = log.SlotConfirmedAt is not null;
            return new BayConfirmHistoryResponse
            {
                LogId = log.Id,
                DriverSlotCode = !confirmed ? null
                    : corrections.Count > 0 ? corrections[0].FromSlotCode : log.SlotCode,
                DriverConfirmedAt = log.SlotConfirmedAt,
                CurrentSlotCode = confirmed ? log.SlotCode : null,
                State = SlotConfirmPolicy.StateOf(log.UserId, log.EntryTime, log.ExitTime, log.SlotConfirmedAt),
                Corrections = corrections,
            };
        }

        /// <summary>
        /// Two confirmed drivers cannot be in one bay at once. The sessions only
        /// clash when they overlap in time, so a bay used by someone else this
        /// morning can still be confirmed this afternoon.
        /// </summary>
        private Task<bool> HeldByAnotherAsync(ParkingLog log, Guid slotId, CancellationToken ct)
        {
            var start = log.EntryTime;
            var end = log.ExitTime ?? DateTime.MaxValue;
            return _db.Set<ParkingLog>().AsNoTracking().AnyAsync(l =>
                l.Id != log.Id
                && l.SlotId == slotId
                && l.SlotConfirmedAt != null
                && l.EntryTime < end
                && (l.ExitTime == null || l.ExitTime > start), ct);
        }

        private static DateOnly ManilaDay(DateTime utc)
            => DateOnly.FromDateTime(DateTime.SpecifyKind(utc, DateTimeKind.Utc).Add(Manila));

        private static ConfirmSlotResponse Refuse(string result, string message)
            => new() { Result = result, Message = message };

        private static CorrectBayResponse RefuseCorrection(string result, string message)
            => new() { Result = result, Message = message };
    }
}
