using AimPark.API.Data;
using AimPark.API.DTOs;
using AimPark.API.Entities;
using AimPark.API.Enums;
using AimPark.API.Interfaces;
using AimPark.API.Sync;
using AimPark.API.Sync.Cloud;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace AimPark.API.Services
{
    public class ParkingSlotService : IParkingSlotService
    {
        private readonly IRepository<ParkingSlot> _slots;
        private readonly AppDbContext _db;
        private readonly SiteLinkState _link;
        private readonly SiteOptions _site;

        /// <summary>
        /// Without a word from the guard post for this long, the bays are not
        /// trusted. The guard post reports every 15 s; the admin map uses the
        /// same 60 s.
        /// </summary>
        private static readonly TimeSpan GuardPostSilentAfter = TimeSpan.FromSeconds(60);
        private static readonly DateTime ProcessStartedAt = DateTime.UtcNow;

        public ParkingSlotService(
            IRepository<ParkingSlot> slots,
            AppDbContext db,
            SiteLinkState link,
            IOptions<SiteOptions> site)
        {
            _slots = slots;
            _db = db;
            _link = link;
            _site = site.Value;
        }

        // GET /api/parking/slots — what the mobile app reads.
        //
        // The bays are only as good as the guard post that feeds them. If it dies
        // the cloud keeps the last state it was sent, so a lot with the power off
        // still read "9 free" and the app said "Updated just now". Once the guard
        // post has gone quiet every bay is reported as No signal instead. The admin
        // list (ListAllAsync) is left alone: it shows the last known state and says
        // so, which is what an admin needs.
        public async Task<ActionResult<ParkingAvailabilityResponse>> GetAvailabilityAsync(CancellationToken ct)
        {
            var response = await BuildResponseAsync(_db.Set<ParkingSlot>().AsNoTracking(), ct);

            // At the guard post the sensors are read directly; there is no link
            // to be silent.
            if (!_site.IsCloud) return response;

            var link = _link.Snapshot();
            var heardAt = new[] { link.LastPushAt, link.HealthAt }.Max();
            response.LastHeardAt = heardAt;

            // The sensors are read by the guard post, so no guard post means no
            // sensor feed and the stored bays are only a memory. What the cloud
            // has heard is held in memory, and a restart forgets it — which used
            // to read as "never heard, so maybe there is no guard post" and put
            // the last known "9 free" back on screen with the hardware dead. The
            // guard post reports at least every 15 seconds, so if the cloud has
            // been up longer than the silence window and heard nothing, it is off.
            var silent = heardAt is null
                ? _site.TreatUnheardGuardPostAsSilent
                  || DateTime.UtcNow - ProcessStartedAt > GuardPostSilentAfter
                : DateTime.UtcNow - heardAt.Value > GuardPostSilentAfter;

            if (!silent) return response;

            foreach (var slot in response.Slots)
                slot.Status = ParkingSlotStatus.NoSignal.ToString();

            response.AvailableSlots = 0;
            response.AvailableCars = 0;
            response.AvailableMotorcycles = 0;
            response.SensorsDetected = 0;
            response.LiveBays = 0;
            response.NoSignalBays = response.Slots.Count;
            response.FeedPaused = true;
            return response;
        }

        // GET /api/admin/parking/slots
        public async Task<ActionResult<ParkingAvailabilityResponse>> ListAllAsync(CancellationToken ct)
            => await BuildResponseAsync(_db.Set<ParkingSlot>().AsNoTracking(), ct);

        // POST /api/admin/parking/slots
        public async Task<ActionResult<object>> CreateAsync(UpsertParkingSlotDto dto, CancellationToken ct)
        {
            if (string.IsNullOrWhiteSpace(dto.SlotCode))
                return new BadRequestObjectResult(new { message = "Slot code is required." });

            var exists = await _slots.ExistsAsync(s => s.SlotCode == dto.SlotCode, ct);
            if (exists)
                return new BadRequestObjectResult(new { message = "A slot with this code already exists." });

            VehicleType? vehicleType = null;
            if (!string.IsNullOrWhiteSpace(dto.VehicleType))
            {
                if (!Enum.TryParse<VehicleType>(dto.VehicleType, true, out var parsed))
                    return new BadRequestObjectResult(new { message = "Invalid vehicle type." });
                vehicleType = parsed;
            }

            var gate = dto.Gate ?? 1;
            if (gate < 1)
                return new BadRequestObjectResult(new { message = "Gate must be 1 or greater." });

            var slot = new ParkingSlot
            {
                Id = Guid.NewGuid(),
                SlotCode = dto.SlotCode.Trim(),
                Gate = gate,
                VehicleType = vehicleType,
                Status = ParkingSlotStatus.Available,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            };

            await _slots.AddAsync(slot, ct);
            await _slots.SaveAsync(ct);

            return new OkObjectResult(new { message = "Slot created." });
        }

        // PUT /api/admin/parking/slots/{slotId}/status
        public async Task<ActionResult<object>> UpdateStatusAsync(Guid slotId, UpdateSlotStatusDto dto, CancellationToken ct)
        {
            if (!Enum.TryParse<ParkingSlotStatus>(dto.Status, true, out var newStatus))
                return new BadRequestObjectResult(new { message = "Invalid status value." });

            // Only a bay's sensor can say it has lost its signal.
            if (newStatus == ParkingSlotStatus.NoSignal)
                return new BadRequestObjectResult(new { message = "No signal is set by the slot's sensor, not by hand." });

            var slot = await _slots.FindAsync(s => s.Id == slotId, ct);
            if (slot is null)
                return new NotFoundObjectResult(new { message = "Slot not found." });

            // A vehicle is inside until somebody logs its exit, and the exit is
            // what closes the session, works out the duration and raises the
            // bill. Flipping the slot to Available around it freed the bay on
            // screen while the session stayed open forever: the plate went on
            // showing in active sessions, and nobody was ever charged.
            //
            // Out of service is no different — the car is still parked in it.
            if (newStatus != slot.Status)
            {
                var occupant = await _db.Set<ParkingLog>().AsNoTracking()
                    .Where(l => l.SlotId == slotId && l.ExitTime == null)
                    .Select(l => l.User != null ? l.User.Email : l.VisitorPass!.PlateNumber)
                    .FirstOrDefaultAsync(ct);

                if (occupant is not null)
                {
                    return new BadRequestObjectResult(new
                    {
                        message = $"{slot.SlotCode} still has a vehicle in it ({occupant}). "
                                + "Log the exit first — that is what ends the session and bills it."
                    });
                }
            }

            slot.Status = newStatus;
            slot.UpdatedAt = DateTime.UtcNow;

            _slots.Update(slot);
            await _slots.SaveAsync(ct);

            return new OkObjectResult(new { message = "Slot status updated." });
        }

        /// <summary>Most sessions one history call returns. The window narrows it; this bounds it.</summary>
        private const int HistoryLimit = 200;

        // GET /api/admin/parking/slots/{id}/history — who used one bay.
        //
        // A session counts when it overlapped [from, to]: it began before the
        // window ended and had not ended before it began. Either end may be left
        // open. Whose session it is comes from the log's SlotId, which is the bay
        // the driver confirmed when ConfirmedAt is set and only the gate's
        // suggestion when it is not; the response carries that so the panel can
        // say which.
        public async Task<ActionResult<SlotHistoryResponse>> GetHistoryAsync(
            Guid slotId, DateTime? from, DateTime? to, CancellationToken ct)
        {
            var slot = await _db.Set<ParkingSlot>().AsNoTracking()
                .FirstOrDefaultAsync(s => s.Id == slotId, ct);
            if (slot is null)
                return new NotFoundObjectResult(new { message = "Slot not found." });

            if (from is not null && to is not null && from > to)
                return new BadRequestObjectResult(new { message = "'from' must be before 'to'." });

            var logs = _db.Set<ParkingLog>().AsNoTracking().Where(l => l.SlotId == slotId);

            if (to is DateTime end) logs = logs.Where(l => l.EntryTime <= end);
            if (from is DateTime start) logs = logs.Where(l => l.ExitTime == null || l.ExitTime >= start);

            var rows = await logs
                .OrderByDescending(l => l.EntryTime)
                .Take(HistoryLimit + 1)
                .Select(l => new SlotSessionItem
                {
                    LogId = l.Id,
                    UserId = l.UserId,
                    UserName = l.User != null
                        ? l.User.FullName
                        : l.VisitorPass != null
                            ? l.VisitorPass.VisitorName
                            : "Unknown",
                    // What the camera read is what actually came in; a registered
                    // plate is only a guess for a holder with several vehicles.
                    PlateNumber = l.AlprPlateNumber
                        ?? (l.VisitorPass != null
                            ? l.VisitorPass.PlateNumber
                            : _db.Set<Vehicle>()
                                .Where(v => v.UserId == l.UserId)
                                .Select(v => v.PlateNumber)
                                .FirstOrDefault()),
                    IsVisitor = l.VisitorPassId != null,
                    EntryTime = l.EntryTime,
                    ExitTime = l.ExitTime,
                    ConfirmedAt = l.SlotConfirmedAt
                })
                .ToListAsync(ct);

            var truncated = rows.Count > HistoryLimit;
            if (truncated) rows.RemoveAt(rows.Count - 1);

            // The current occupant is whoever has an open session on the bay,
            // whatever the window asked for.
            var current = await _db.Set<ParkingLog>().AsNoTracking()
                .Where(l => l.SlotId == slotId && l.ExitTime == null)
                .OrderByDescending(l => l.EntryTime)
                .Select(l => new SlotSessionItem
                {
                    LogId = l.Id,
                    UserId = l.UserId,
                    UserName = l.User != null
                        ? l.User.FullName
                        : l.VisitorPass != null
                            ? l.VisitorPass.VisitorName
                            : "Unknown",
                    PlateNumber = l.AlprPlateNumber
                        ?? (l.VisitorPass != null
                            ? l.VisitorPass.PlateNumber
                            : _db.Set<Vehicle>()
                                .Where(v => v.UserId == l.UserId)
                                .Select(v => v.PlateNumber)
                                .FirstOrDefault()),
                    IsVisitor = l.VisitorPassId != null,
                    EntryTime = l.EntryTime,
                    ExitTime = l.ExitTime,
                    ConfirmedAt = l.SlotConfirmedAt
                })
                .FirstOrDefaultAsync(ct);

            var logIds = rows.Select(r => r.LogId).ToList();
            var violations = await _db.Set<Violation>().AsNoTracking()
                .Where(v => v.ParkingLogId != null && logIds.Contains(v.ParkingLogId.Value))
                .OrderByDescending(v => v.CreatedAt)
                .Select(v => new SlotViolationItem
                {
                    ViolationId = v.Id,
                    UserId = v.UserId,
                    UserName = v.User.FullName,
                    RuleTitle = v.PolicyRule.Title,
                    Status = v.Status.ToString(),
                    PenaltyAmount = v.PenaltyAmount,
                    CreatedAt = v.CreatedAt
                })
                .ToListAsync(ct);

            var flags = _db.Set<WrongBayFlag>().AsNoTracking().Where(f => f.SlotId == slotId);
            if (to is DateTime flagEnd) flags = flags.Where(f => f.DetectedAt <= flagEnd);
            if (from is DateTime flagStart) flags = flags.Where(f => f.BayClearedAt == null || f.BayClearedAt >= flagStart);

            var wrongBay = await flags
                .OrderByDescending(f => f.DetectedAt)
                .Take(50)
                .Select(f => new SlotWrongBayItem
                {
                    FlagId = f.Id,
                    Status = f.Status.ToString(),
                    DetectedAt = f.DetectedAt,
                    BayClearedAt = f.BayClearedAt
                })
                .ToListAsync(ct);

            return new OkObjectResult(new SlotHistoryResponse
            {
                SlotId = slot.Id,
                SlotCode = slot.SlotCode,
                Gate = slot.Gate,
                BayType = slot.VehicleType?.ToString(),
                Current = current,
                Sessions = rows,
                Violations = violations,
                WrongBayFlags = wrongBay,
                Truncated = truncated
            });
        }

        private async Task<ParkingAvailabilityResponse> BuildResponseAsync(IQueryable<ParkingSlot> query, CancellationToken ct)
        {
            var slots = await query
                .OrderBy(s => s.Gate)
                .ThenBy(s => s.SlotCode)
                .Select(s => new ParkingSlotResponse
                {
                    SlotId = s.Id,
                    SlotCode = s.SlotCode,
                    Gate = s.Gate,
                    VehicleType = s.VehicleType == null ? null : s.VehicleType.ToString(),
                    Status = s.Status.ToString()
                })
                .ToListAsync(ct);

            var room = await ParkingCapacity.LoadAsync(_db, ct);
            var count = await ParkingCapacity.LoadCountAsync(_db, ct);

            return new ParkingAvailabilityResponse
            {
                Slots = slots,
                TotalSlots = slots.Count,
                AvailableSlots = room.Free,
                AvailableCars = room.FreeCars,
                AvailableMotorcycles = room.FreeMotorcycles,
                UsersInside = count.UsersInside,
                SensorsDetected = count.SensorsDetected,
                LiveBays = count.TotalBays,
                NoSignalBays = count.NoSignalBays
            };
        }
    }
}
