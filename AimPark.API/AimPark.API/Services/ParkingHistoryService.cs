using AimPark.API.Data;
using AimPark.API.DTOs;
using AimPark.API.Entities;
using AimPark.API.Enums;
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
        private readonly AppDbContext _db;

        public ParkingHistoryService(
            IRepository<ParkingLog> logs,
            IRepository<ParkingSlot> slots,
            IPaymentService paymentService,
            IParkingAllocationService allocationService,
            AppDbContext db)
        {
            _logs = logs;
            _slots = slots;
            _paymentService = paymentService;
            _allocationService = allocationService;
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
                    UserName = l.User.FullName,
                    PlateNumber = _db.Set<Vehicle>()
                        .Where(v => v.UserId == l.UserId)
                        .Select(v => v.PlateNumber)
                        .FirstOrDefault(),
                    SlotCode = l.Slot != null ? l.Slot.SlotCode : null,
                    EntryTime = l.EntryTime
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

            if (user is null)
                return new NotFoundObjectResult(new
                {
                    result = AllocationResult.UnknownTag,
                    message = "User not found. Provide a valid userId or rfidTagId."
                });

            if (user.RfidStatus == RfidStatus.Suspended)
            {
                if (user.RfidSuspendedUntil is not null && user.RfidSuspendedUntil <= DateTime.UtcNow)
                {
                    // Temporary suspension has expired — lazily reactivate.
                    user.RfidStatus = RfidStatus.Active;
                    user.RfidSuspendedUntil = null;
                    user.UpdatedAt = DateTime.UtcNow;
                }
                else
                {
                    return new BadRequestObjectResult(new
                    {
                        result = AllocationResult.RfidSuspended,
                        message = "RFID access is suspended."
                    });
                }
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

                if (userId is null)
                    return new NotFoundObjectResult(new
                    {
                        result = AllocationResult.UnknownTag,
                        message = "No account is registered to this tag."
                    });

                log = await _logs.FindAsync(l => l.UserId == userId && l.ExitTime == null, ct);
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

            var transaction = await _paymentService.CreateForCompletedLogAsync(log, ct);

            return new OkObjectResult(new
            {
                result = AllocationResult.ExitLogged,
                message = "Exit logged.",
                paymentId = transaction.Id,
                amountDue = transaction.AmountDue
            });
        }
    }
}
