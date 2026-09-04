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
    public class ParkingHistoryService : IParkingHistoryService
    {
        private readonly IRepository<ParkingLog> _logs;
        private readonly IRepository<ParkingSlot> _slots;
        private readonly IPaymentService _paymentService;
        private readonly IParkingAllocationService _allocationService;
        private readonly INotificationService _notificationService;
        private readonly AppDbContext _db;

        public ParkingHistoryService(
            IRepository<ParkingLog> logs,
            IRepository<ParkingSlot> slots,
            IPaymentService paymentService,
            IParkingAllocationService allocationService,
            INotificationService notificationService,
            AppDbContext db)
        {
            _logs = logs;
            _slots = slots;
            _paymentService = paymentService;
            _allocationService = allocationService;
            _notificationService = notificationService;
            _db = db;
        }

        // GET /api/parking/history?page=1&pageSize=20
        public async Task<ActionResult<ParkingHistoryResponse>> GetMyHistoryAsync(Guid userId, int page, int pageSize, CancellationToken ct)
        {
            page = Math.Max(1, page);
            pageSize = Math.Clamp(pageSize, 1, 100);

            var query = _db.Set<ParkingLog>().AsNoTracking().Where(l => l.UserId == userId);

            var totalCount = await query.CountAsync(ct);

            var logs = await query
                .OrderByDescending(l => l.EntryTime)
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .Select(l => new ParkingHistoryEntryResponse
                {
                    LogId = l.Id,
                    SlotCode = l.Slot != null ? l.Slot.SlotCode : null,
                    EntryTime = l.EntryTime,
                    ExitTime = l.ExitTime,
                    PaymentId = _db.Set<PaymentTransaction>()
                        .Where(p => p.ParkingLogId == l.Id)
                        .Select(p => (Guid?)p.Id)
                        .FirstOrDefault()
                })
                .ToListAsync(ct);

            return new OkObjectResult(new ParkingHistoryResponse
            {
                Logs = logs,
                TotalCount = totalCount,
                Page = page,
                PageSize = pageSize
            });
        }

        // GET /api/admin/parking/active-sessions — vehicles currently inside
        public async Task<ActionResult<List<ActiveParkingSessionResponse>>> ListActiveSessionsAsync(CancellationToken ct)
        {
            var sessions = await _db.Set<ParkingLog>().AsNoTracking()
                .Where(l => l.ExitTime == null)
                .OrderByDescending(l => l.EntryTime)
                .Select(l => new ActiveParkingSessionResponse
                {
                    LogId = l.Id,
                    UserId = l.UserId,
                    // Whichever of the two this session belongs to. A visitor is
                    // as much "inside the lot" as a member of staff, and leaving
                    // them out would make the occupancy count disagree with the
                    // cars actually parked.
                    UserName = l.User != null
                        ? l.User.FullName
                        : l.VisitorPass != null
                            ? l.VisitorPass.VisitorName
                            : "Unknown",
                    PlateNumber = l.VisitorPass != null
                        ? l.VisitorPass.PlateNumber
                        : _db.Set<Vehicle>()
                            .Where(v => v.UserId == l.UserId)
                            .Select(v => v.PlateNumber)
                            .FirstOrDefault(),
                    SlotCode = l.Slot != null ? l.Slot.SlotCode : null,
                    EntryTime = l.EntryTime,
                    IsVisitor = l.VisitorPassId != null
                })
                .ToListAsync(ct);

            return new OkObjectResult(sessions);
        }

        // POST /api/admin/parking/log-entry — manual stand-in for the RFID gate hardware
        public async Task<ActionResult<object>> LogEntryAsync(
            LogParkingEntryDto dto, Guid? loggedByUserId, Guid? loggedByDeviceId, CancellationToken ct)
        {
            User? user = null;

            if (dto.UserId is not null)
                user = await _db.Set<User>().FirstOrDefaultAsync(u => u.Id == dto.UserId, ct);
            else if (!string.IsNullOrWhiteSpace(dto.RfidTagId))
                user = await _db.Set<User>().FirstOrDefaultAsync(u => u.RfidTagId == dto.RfidTagId, ct);

            // No account for this card — it may be one lent to a visitor. The
            // reader cannot tell the two apart and should not have to: a card is
            // a card, and the barrier opens for whoever is holding a valid one.
            if (user is null && !string.IsNullOrWhiteSpace(dto.RfidTagId))
                return await LogVisitorEntryAsync(dto, loggedByUserId, loggedByDeviceId, ct);

            if (user is null)
                return new NotFoundObjectResult(new
                {
                    result = AllocationResult.UnknownTag,
                    message = "User not found. Provide a valid userId or rfidTagId."
                });

            var nowUtc = DateTime.UtcNow;

            // Temporary suspension has expired — lazily reactivate.
            if (RfidAccess.HasExpired(user, nowUtc))
                RfidAccess.Reactivate(user, nowUtc);

            // Not `RfidStatus == Suspended`: a suspension issued with a
            // violation sits scheduled for a few days first, and during that
            // window the tag still opens the barrier. See RfidAccess.
            if (RfidAccess.IsSuspendedNow(user, nowUtc))
            {
                return new BadRequestObjectResult(new
                {
                    result = AllocationResult.RfidSuspended,
                    message = "RFID access is suspended."
                });
            }

            // A vehicle already inside must not open the barrier again — without
            // this the same tag could log repeated entries and orphan the first.
            var openSession = await _db.Set<ParkingLog>().AsNoTracking()
                .AnyAsync(l => l.UserId == user.Id && l.ExitTime == null, ct);

            if (openSession)
                return new BadRequestObjectResult(new
                {
                    result = AllocationResult.AlreadyInside,
                    message = "This vehicle is already inside the lot."
                });

            ParkingSlot? slot = null;
            if (dto.SlotId is not null)
            {
                slot = await _slots.FindAsync(s => s.Id == dto.SlotId, ct);
                if (slot is null)
                    return new NotFoundObjectResult(new
                    {
                        result = AllocationResult.SlotUnavailable,
                        message = "Slot not found."
                    });

                if (slot.Status != ParkingSlotStatus.Available)
                    return new BadRequestObjectResult(new
                    {
                        result = AllocationResult.SlotUnavailable,
                        message = "Slot is not available."
                    });

                // Naming the slot by hand used to skip every rule the allocator
                // applies, so the panel would put a car in a motorcycle bay.
                var types = await _db.Set<Vehicle>().AsNoTracking()
                    .Where(v => v.UserId == user.Id)
                    .Select(v => v.VehicleType)
                    .Distinct()
                    .ToListAsync(ct);

                var refusal = await CheckSlotFitsAsync(slot, types, ct);
                if (refusal is not null) return refusal;
            }
            else
            {
                // No slot named — this is the automatic path the gate uses.
                // ClaimForEntryAsync takes the slot as it picks it, so two
                // vehicles scanning at once cannot be sent to the same bay.
                var assignment = await _allocationService.ClaimForEntryAsync(user.Id, dto.Gate, ct);
                if (assignment.Result != AllocationResult.Assigned)
                    return new BadRequestObjectResult(new
                    {
                        result = assignment.Result,
                        message = assignment.Reason ?? "No slot could be assigned."
                    });

                slot = await _slots.FindAsync(s => s.Id == assignment.SlotId, ct);
            }

            var log = new ParkingLog
            {
                Id = Guid.NewGuid(),
                UserId = user.Id,
                SlotId = slot?.Id,
                EntryTime = DateTime.UtcNow,
                ExitTime = null,
                LoggedByUserId = loggedByUserId,
                LoggedByDeviceId = loggedByDeviceId,
                CreatedAt = DateTime.UtcNow
            };

            await _logs.AddAsync(log, ct);

            if (slot is not null)
            {
                // Idempotent for the automatic path, where the claim already
                // took the slot; the manual path relies on it.
                slot.Status = ParkingSlotStatus.Occupied;
                slot.UpdatedAt = DateTime.UtcNow;
                _slots.Update(slot);
            }

            await _logs.SaveAsync(ct);

            await AnnounceAvailabilityAsync(afterEntry: true, ct);

            return new OkObjectResult(new
            {
                result = AllocationResult.Assigned,
                message = "Entry logged.",
                logId = log.Id,
                slotId = slot?.Id,
                slotCode = slot?.SlotCode,
                gate = slot?.Gate
            });
        }

        /// <summary>
        /// Tells drivers when the lot fills up, and when it opens again.
        /// </summary>
        /// <remarks>
        /// Fired on the transition only, never on the state. Announcing "the lot
        /// is full" on every arrival while it stays full would be a notification
        /// per car, which is how people learn to swipe the app's notifications
        /// away without reading them.
        ///
        /// The transition is read off the count itself rather than from stored
        /// state: the bay was taken a moment ago, so zero free means *this*
        /// vehicle took the last one, and one free after an exit means *this*
        /// vehicle freed the only one. No extra column, and nothing to get out
        /// of step with the slots table.
        /// </remarks>
        /// <summary>
        /// Refuses a hand-picked slot the vehicle has no business in, or null
        /// when the placement is fine.
        /// </summary>
        /// <remarks>
        /// Only the manual paths need this. The allocator never offers a bay
        /// the vehicle does not fit, but an admin naming a slot themselves was
        /// not checked against anything.
        ///
        /// An empty <paramref name="types"/> means nothing is registered to
        /// check against — a user with no vehicle on file. That is the admin's
        /// judgement to make, so it passes.
        /// </remarks>
        private async Task<ActionResult<object>?> CheckSlotFitsAsync(
            ParkingSlot slot, IReadOnlyCollection<VehicleType> types, CancellationToken ct)
        {
            if (types.Count == 0) return null;

            if (!types.Any(t => SlotFit.Accepts(slot.VehicleType, t)))
            {
                return new BadRequestObjectResult(new
                {
                    result = AllocationResult.SlotUnavailable,
                    message = $"Slot {slot.SlotCode} is for {SlotFit.Describe(slot.VehicleType)}, "
                            + "which does not match this vehicle."
                });
            }

            // Fits, but only through the overflow rule. The allocator reaches
            // for a four-wheel bay just once the motorcycle bays are gone, and
            // a manual placement has to hold to the same limit or the handful
            // of car bays get spent on motorcycles while their own sit empty.
            if (types.All(t => SlotFit.IsOverflow(slot.VehicleType, t)))
            {
                var motorcycleBayFree = await _db.Set<ParkingSlot>().AsNoTracking()
                    .AnyAsync(s => s.VehicleType == VehicleType.Motorcycle
                               && s.Status == ParkingSlotStatus.Available, ct);

                if (motorcycleBayFree)
                {
                    return new BadRequestObjectResult(new
                    {
                        result = AllocationResult.SlotUnavailable,
                        message = $"Slot {slot.SlotCode} is a four-wheel bay. Motorcycle bays are "
                                + "still free, so use one of those first."
                    });
                }
            }

            return null;
        }

        private async Task AnnounceAvailabilityAsync(bool afterEntry, CancellationToken ct)
        {
            var free = await _db.Set<ParkingSlot>().AsNoTracking()
                .CountAsync(sl => sl.Status == ParkingSlotStatus.Available, ct);

            if (afterEntry && free == 0)
            {
                await _notificationService.NotifyRoleAsync(
                    UserRole.User,
                    NotificationType.ParkingAvailability,
                    "The lot is full",
                    "Every bay is taken right now. The app will let you know when one frees up.",
                    ct);
            }
            else if (!afterEntry && free == 1)
            {
                await _notificationService.NotifyRoleAsync(
                    UserRole.User,
                    NotificationType.ParkingAvailability,
                    "A slot just opened",
                    "The lot was full and a bay has come free. Open the app to see where.",
                    ct);
            }
        }

        /// <summary>
        /// Entry for a card that belongs to no account - a pass lent to a
        /// visitor.
        /// </summary>
        /// <remarks>
        /// Deliberately a separate path rather than more branches inside
        /// <c>LogEntryAsync</c>. The two share the shape but almost none of the
        /// checks: a visitor has no account status, no suspension, no registered
        /// vehicle to read a type from, and their pass can expire - which
        /// nothing about a registered user ever does.
        /// </remarks>
        private async Task<ActionResult<object>> LogVisitorEntryAsync(
            LogParkingEntryDto dto, Guid? loggedByUserId, Guid? loggedByDeviceId, CancellationToken ct)
        {
            var nowUtc = DateTime.UtcNow;

            var pass = await _db.Set<VisitorPass>()
                .Where(p => p.RfidTagId == dto.RfidTagId)
                .OrderByDescending(p => p.IssuedAt)
                .FirstOrDefaultAsync(ct);

            if (pass is null)
                return new NotFoundObjectResult(new
                {
                    result = AllocationResult.UnknownTag,
                    message = "This card is not registered to an account or a visitor."
                });

            if (pass.Status == VisitorPassStatus.Returned)
                return new BadRequestObjectResult(new
                {
                    result = AllocationResult.RfidSuspended,
                    message = "This card was handed back and is no longer in use."
                });

            if (pass.ExpiresAt <= nowUtc)
            {
                // Recorded, not just refused: the card is out past its day and
                // the guard needs to see that in the pass list.
                if (pass.Status == VisitorPassStatus.Active)
                {
                    pass.Status = VisitorPassStatus.Expired;
                    pass.UpdatedAt = nowUtc;
                    await _db.SaveChangesAsync(ct);
                }

                return new BadRequestObjectResult(new
                {
                    result = AllocationResult.RfidSuspended,
                    message = "This visitor pass has expired. Issue a new one."
                });
            }

            var openSession = await _db.Set<ParkingLog>().AsNoTracking()
                .AnyAsync(l => l.VisitorPassId == pass.Id && l.ExitTime == null, ct);

            if (openSession)
                return new BadRequestObjectResult(new
                {
                    result = AllocationResult.AlreadyInside,
                    message = "This vehicle is already inside the lot."
                });

            ParkingSlot? slot = null;
            if (dto.SlotId is not null)
            {
                slot = await _slots.FindAsync(s => s.Id == dto.SlotId, ct);
                if (slot is null)
                    return new NotFoundObjectResult(new
                    {
                        result = AllocationResult.SlotUnavailable,
                        message = "Slot not found."
                    });

                if (slot.Status != ParkingSlotStatus.Available)
                    return new BadRequestObjectResult(new
                    {
                        result = AllocationResult.SlotUnavailable,
                        message = "Slot is not available."
                    });

                // Same rule as a registered vehicle, read off the pass.
                var refusal = await CheckSlotFitsAsync(slot, [pass.VehicleType], ct);
                if (refusal is not null) return refusal;
            }
            else
            {
                // The pass carries the vehicle type, since there is no
                // registered vehicle to read it from.
                var assignment = await _allocationService.ClaimForVehicleTypeAsync(
                    pass.VehicleType, userId: null, dto.Gate, ct);

                if (assignment.Result != AllocationResult.Assigned)
                    return new BadRequestObjectResult(new
                    {
                        result = assignment.Result,
                        message = assignment.Reason ?? "No slot could be assigned."
                    });

                slot = await _slots.FindAsync(s => s.Id == assignment.SlotId, ct);
            }

            var log = new ParkingLog
            {
                Id = Guid.NewGuid(),
                UserId = null,
                VisitorPassId = pass.Id,
                SlotId = slot?.Id,
                EntryTime = nowUtc,
                ExitTime = null,
                LoggedByUserId = loggedByUserId,
                LoggedByDeviceId = loggedByDeviceId,
                CreatedAt = nowUtc
            };

            await _logs.AddAsync(log, ct);

            if (slot is not null)
            {
                slot.Status = ParkingSlotStatus.Occupied;
                slot.UpdatedAt = nowUtc;
                _slots.Update(slot);
            }

            await _logs.SaveAsync(ct);

            await AnnounceAvailabilityAsync(afterEntry: true, ct);

            return new OkObjectResult(new
            {
                result = AllocationResult.Assigned,
                message = "Entry logged for visitor " + pass.VisitorName + ".",
                logId = log.Id,
                slotId = slot?.Id,
                slotCode = slot?.SlotCode,
                gate = slot?.Gate,
                visitorName = pass.VisitorName,
                plateNumber = pass.PlateNumber
            });
        }

        // POST /api/admin/parking/log-exit
        public async Task<ActionResult<object>> LogExitAsync(
            LogParkingExitDto dto, Guid? loggedByUserId, Guid? loggedByDeviceId, CancellationToken ct)
        {
            ParkingLog? log = null;

            if (dto.LogId is not null)
            {
                log = await _logs.FindAsync(l => l.Id == dto.LogId, ct);
            }
            else if (!string.IsNullOrWhiteSpace(dto.RfidTagId))
            {
                // Gate path: resolve the card to its open session. Exiting is
                // only ever meaningful for a vehicle currently inside.
                var userId = await _db.Set<User>().AsNoTracking()
                    .Where(u => u.RfidTagId == dto.RfidTagId)
                    .Select(u => (Guid?)u.Id)
                    .FirstOrDefaultAsync(ct);

                if (userId is not null)
                {
                    log = await _logs.FindAsync(l => l.UserId == userId && l.ExitTime == null, ct);
                }
                else
                {
                    // A visitor leaving. Resolved through the pass rather than an
                    // account, and by the pass's *open session* rather than its
                    // status — a card that expired while the car was inside must
                    // still be able to get the car out.
                    var passId = await _db.Set<VisitorPass>().AsNoTracking()
                        .Where(p => p.RfidTagId == dto.RfidTagId)
                        .OrderByDescending(p => p.IssuedAt)
                        .Select(p => (Guid?)p.Id)
                        .FirstOrDefaultAsync(ct);

                    if (passId is null)
                        return new NotFoundObjectResult(new
                        {
                            result = AllocationResult.UnknownTag,
                            message = "No account or visitor pass is registered to this tag."
                        });

                    log = await _logs.FindAsync(
                        l => l.VisitorPassId == passId && l.ExitTime == null, ct);
                }
            }

            if (log is null)
                return new NotFoundObjectResult(new
                {
                    result = AllocationResult.LogNotFound,
                    message = "No open parking session found."
                });

            if (log.ExitTime is not null)
                return new BadRequestObjectResult(new
                {
                    result = AllocationResult.AlreadyExited,
                    message = "This entry already has a recorded exit."
                });

            log.ExitTime = DateTime.UtcNow;
            _logs.Update(log);

            if (log.SlotId is not null)
            {
                var slot = await _slots.FindAsync(s => s.Id == log.SlotId, ct);
                if (slot is not null)
                {
                    slot.Status = ParkingSlotStatus.Available;
                    slot.UpdatedAt = DateTime.UtcNow;
                    _slots.Update(slot);
                }
            }

            await _logs.SaveAsync(ct);

            await AnnounceAvailabilityAsync(afterEntry: false, ct);

            // Visitor parking is free by design — a guest being escorted in for
            // a specific purpose, not a campus regular. No quote, no charge.
            if (log.UserId is null)
            {
                var durationMinutes = Math.Max(0,
                    (int)Math.Ceiling((log.ExitTime!.Value - log.EntryTime).TotalMinutes));

                return new OkObjectResult(new
                {
                    result = AllocationResult.ExitLogged,
                    message = "Exit logged. No charge for visitors.",
                    paymentId = (Guid?)null,
                    amountDue = 0m,
                    durationMinutes,
                    collectInCash = false
                });
            }

            var transaction = await _paymentService.CreateForCompletedLogAsync(log, ct);

            return new OkObjectResult(new
            {
                result = AllocationResult.ExitLogged,
                message = "Exit logged.",
                paymentId = (Guid?)transaction.Id,
                amountDue = transaction.AmountDue,
                durationMinutes = transaction.DurationMinutes,
                collectInCash = false
            });
        }
    }
}
