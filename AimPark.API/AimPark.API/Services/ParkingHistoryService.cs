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
        private readonly ISlotSensors _sensors;

        public ParkingHistoryService(
            IRepository<ParkingLog> logs,
            IRepository<ParkingSlot> slots,
            IPaymentService paymentService,
            IParkingAllocationService allocationService,
            INotificationService notificationService,
            AppDbContext db,
            ISlotSensors sensors)
        {
            _sensors = sensors;
            _logs = logs;
            _slots = slots;
            _paymentService = paymentService;
            _allocationService = allocationService;
            _notificationService = notificationService;
            _db = db;
        }

        // GET /api/parking/history?page=1&pageSize=20[&vehicleId=...]
        public async Task<ActionResult<ParkingHistoryResponse>> GetMyHistoryAsync(Guid userId, Guid? vehicleId, int page, int pageSize, CancellationToken ct)
        {
            page = Math.Max(1, page);
            pageSize = Math.Clamp(pageSize, 1, 100);

            var vehicles = await _db.Set<Vehicle>().AsNoTracking()
                .Where(v => v.UserId == userId)
                .Select(v => new { v.Id, v.PlateNumber })
                .ToListAsync(ct);

            var query = _db.Set<ParkingLog>().AsNoTracking().Where(l => l.UserId == userId);

            if (vehicleId is Guid wantedVehicleId)
            {
                var vehicle = vehicles.FirstOrDefault(v => v.Id == wantedVehicleId);
                if (vehicle is null)
                    return new NotFoundObjectResult(new { message = "Vehicle not found." });

                // Mirrors AttributeVehicle's own rules exactly: a plate-less
                // session only attributes to this vehicle when it's the only
                // one the user has, since with two or more there's no way to
                // tell them apart without a camera read.
                query = vehicles.Count == 1
                    ? query.Where(l => l.AlprPlateNumber == null || l.AlprPlateNumber == vehicle.PlateNumber)
                    : query.Where(l => l.AlprPlateNumber == vehicle.PlateNumber);
            }

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
                        .FirstOrDefault(),
                    AlprPlateNumber = l.AlprPlateNumber
                })
                .ToListAsync(ct);

            foreach (var entry in logs)
                entry.VehicleId = AttributeVehicle(entry.AlprPlateNumber, vehicles.Select(v => (v.Id, v.PlateNumber)).ToList());

            return new OkObjectResult(new ParkingHistoryResponse
            {
                Logs = logs,
                TotalCount = totalCount,
                Page = page,
                PageSize = pageSize
            });
        }

        /// <summary>
        /// Works out which of the user's own vehicles a session belongs to.
        /// There's no VehicleId column on ParkingLog (see the type's remarks
        /// for why), so this is recomputed from the ALPR-confirmed plate every
        /// time history is read, rather than stored.
        /// </summary>
        /// <remarks>
        /// A matched plate always wins. Failing that, a plate-less (manually
        /// logged) session can only be attributed when the user has exactly
        /// one vehicle — with two or more there's no way to tell which one
        /// was actually driven in without a camera read.
        /// </remarks>
        public static Guid? AttributeVehicle(string? alprPlate, IReadOnlyList<(Guid Id, string Plate)> vehicles)
        {
            if (!string.IsNullOrWhiteSpace(alprPlate))
            {
                var normalizedPlate = IdentifierNormalizer.NormalizePlate(alprPlate);
                foreach (var vehicle in vehicles)
                {
                    if (IdentifierNormalizer.NormalizePlate(vehicle.Plate) == normalizedPlate)
                        return vehicle.Id;
                }
                return null;
            }

            return vehicles.Count == 1 ? vehicles[0].Id : null;
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
                // Only from the reader. An admin trying it by hand already knows.
                if (loggedByDeviceId is not null)
                {
                    var until = user.RfidSuspendedUntil is DateTime end
                        ? $" until {end:MMM d}"
                        : "";
                    await _notificationService.NotifyUserAsync(
                        user.Id,
                        NotificationType.Parking,
                        "Your card was refused",
                        $"{(dto.Gate is int g ? $"Gate {g}: y" : "Y")}our RFID access is suspended{until}. Open the app to see why.",
                        new Dictionary<string, string> { ["screen"] = "violations" },
                        ct);
                }

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

            var registeredPlates = await _db.Set<Vehicle>().AsNoTracking()
                .Where(v => v.UserId == user.Id)
                .Select(v => v.PlateNumber)
                .ToListAsync(ct);

            var alprCheck = await CheckAlprAsync(
                dto.Gate, registeredPlates, dto.RfidTagId ?? string.Empty,
                userId: user.Id, visitorPassId: null, loggedByDeviceId, nowUtc, ct);

            if (alprCheck.Denial is not null) return alprCheck.Denial;

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
                AlprReadingId = alprCheck.Matched?.Id,
                AlprPlateNumber = alprCheck.Matched?.PlateNumber,
                AlprMatched = alprCheck.Matched is not null ? true : null,
                CreatedAt = DateTime.UtcNow
            };

            await _logs.AddAsync(log, ct);

            // A bay with a sensor is marked by its sensor, when the car is
            // really there: the bay given here is only a recommendation.
            if (slot is not null && !_sensors.Watches(slot.Id))
            {
                // Idempotent for the automatic path, where the claim already
                // took the slot; the manual path relies on it.
                slot.Status = ParkingSlotStatus.Occupied;
                slot.UpdatedAt = DateTime.UtcNow;
                _slots.Update(slot);
            }

            if (loggedByUserId is not null)
                await ResolvePendingAttemptAsync(userId: user.Id, visitorPassId: null, log.Id, loggedByUserId.Value, nowUtc, ct);

            await _logs.SaveAsync(ct);

            // A receipt, and the only way someone learns their card was used
            // by somebody else. No clock time in the text: the server runs on
            // UTC and the phone already stamps the notification itself.
            var where = slot is not null
                ? $"Gate {slot.Gate}, slot {slot.SlotCode}"
                : dto.Gate is int entryGate ? $"Gate {entryGate}" : "Entry logged";
            await _notificationService.NotifyUserAsync(
                user.Id,
                NotificationType.Parking,
                "You're in",
                $"{where}. Not you? Report it in the app right away.",
                new Dictionary<string, string> { ["screen"] = "parking-history" },
                ct);

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

        /// <summary>
        /// How stale an ALPR reading can be and still count as "this car,
        /// right now" — wide enough that a slightly early or late camera read
        /// still matches the tap, narrow enough that it can't drift onto the
        /// next car in line.
        /// </summary>
        public static readonly TimeSpan AlprMatchWindow = TimeSpan.FromSeconds(8);

        private readonly record struct AlprCheckResult(ActionResult<object>? Denial, AlprReading? Matched);

        /// <summary>
        /// The automatic gate path's half of dual-factor verification: looks
        /// for a fresh, unconsumed ALPR reading at this gate and checks it
        /// against the plates on file for whoever the tag resolved to.
        /// </summary>
        /// <remarks>
        /// Only runs when a device reported the tap. A guard working Gate
        /// Check has already looked at the car themselves — that manual check
        /// *is* the ALPR-down fallback, so this is a deliberate pass-through
        /// for the staff-driven path, not a gap.
        ///
        /// A denial here writes a <see cref="GateAccessAttempt"/> instead of a
        /// <see cref="ParkingLog"/> — the car never got in, and ParkingLog's
        /// occupancy/session queries all lean on every row meaning it did.
        /// </remarks>
        private async Task<AlprCheckResult> CheckAlprAsync(
            int? gate,
            IReadOnlyCollection<string> registeredPlates,
            string rfidTagId,
            Guid? userId,
            Guid? visitorPassId,
            Guid? loggedByDeviceId,
            DateTime nowUtc,
            CancellationToken ct)
        {
            if (loggedByDeviceId is null)
                return new AlprCheckResult(null, null);

            // The device path always carries its own gate — the controller
            // fills this in from the reader's identity before this runs. No
            // gate means nothing to correlate a camera reading against.
            if (gate is not int gateNumber)
            {
                await RecordAttemptAsync(0, rfidTagId, userId, visitorPassId,
                    alprPlate: null, confidence: null, GateAccessOutcome.AlprUnavailable, nowUtc, ct);

                return new AlprCheckResult(new BadRequestObjectResult(new
                {
                    result = AllocationResult.AlprUnavailable,
                    message = "No gate context to verify this vehicle against. See a guard."
                }), null);
            }

            var reading = await _db.Set<AlprReading>()
                .Where(r => r.Gate == gateNumber
                         && r.ConsumedAt == null
                         && r.ReadAt >= nowUtc - AlprMatchWindow)
                .OrderByDescending(r => r.ReadAt)
                .FirstOrDefaultAsync(ct);

            if (reading is null)
            {
                await RecordAttemptAsync(gateNumber, rfidTagId, userId, visitorPassId,
                    alprPlate: null, confidence: null, GateAccessOutcome.AlprUnavailable, nowUtc, ct);

                return new AlprCheckResult(new BadRequestObjectResult(new
                {
                    result = AllocationResult.AlprUnavailable,
                    message = "No camera reading is available to verify this vehicle. See a guard."
                }), null);
            }

            // Consumed either way — a mismatched frame must not be offered to
            // the next tap either.
            reading.ConsumedAt = nowUtc;

            if (!registeredPlates.Contains(reading.PlateNumber))
            {
                await RecordAttemptAsync(gateNumber, rfidTagId, userId, visitorPassId,
                    reading.PlateNumber, reading.Confidence, GateAccessOutcome.PlateMismatch, nowUtc, ct);

                // The one refusal the card holder needs to hear about even when
                // they are not the one at the gate: their card, somebody else's
                // car. A camera being down is a guard's problem, not theirs.
                if (userId is Guid owner)
                {
                    await _notificationService.NotifyUserAsync(
                        owner,
                        NotificationType.Parking,
                        "Your card was refused",
                        $"Gate {gateNumber}: the car at the camera ({reading.PlateNumber}) is not one of your registered vehicles. If that was not you, report your card right away.",
                        new Dictionary<string, string> { ["screen"] = "parking-history" },
                        ct);
                }

                return new AlprCheckResult(new BadRequestObjectResult(new
                {
                    result = AllocationResult.PlateMismatch,
                    message = "The vehicle at the camera does not match this card. See a guard.",
                    plateRead = reading.PlateNumber
                }), null);
            }

            await _db.SaveChangesAsync(ct);
            return new AlprCheckResult(null, reading);
        }

        private async Task RecordAttemptAsync(
            int gate,
            string rfidTagId,
            Guid? userId,
            Guid? visitorPassId,
            string? alprPlate,
            double? confidence,
            GateAccessOutcome outcome,
            DateTime nowUtc,
            CancellationToken ct)
        {
            _db.Set<GateAccessAttempt>().Add(new GateAccessAttempt
            {
                Id = Guid.NewGuid(),
                Gate = gate,
                RfidTagId = rfidTagId,
                UserId = userId,
                VisitorPassId = visitorPassId,
                AlprPlateNumber = alprPlate,
                AlprConfidence = confidence,
                Outcome = outcome,
                AttemptedAt = nowUtc,
                CreatedAt = nowUtc
            });

            await _db.SaveChangesAsync(ct);
        }

        /// <summary>
        /// How long a flagged attempt stays eligible to be closed by whatever
        /// entry follows it. Long enough that a guard walking over to look at
        /// the car isn't racing a clock; short enough that a car turned away
        /// an hour ago can't get silently linked to an unrelated visit later.
        /// </summary>
        private static readonly TimeSpan AttemptReviewWindow = TimeSpan.FromMinutes(15);

        /// <summary>
        /// A staff account manually logging this card in *is* the guard's
        /// review — there is no separate "resolve" step to remember. Finds
        /// the most recent open flag for this card holder and closes it out
        /// against the entry that just happened.
        /// </summary>
        /// <remarks>
        /// Only called from the manual path (<c>loggedByUserId is not null</c>).
        /// The automatic device path never reaches ParkingLog creation with an
        /// open attempt still outstanding — CheckAlprAsync already returned a
        /// denial before getting this far.
        /// </remarks>
        private async Task ResolvePendingAttemptAsync(
            Guid? userId, Guid? visitorPassId, Guid resultingLogId, Guid reviewedByUserId,
            DateTime nowUtc, CancellationToken ct)
        {
            var attempt = await _db.Set<GateAccessAttempt>()
                .Where(a => a.ReviewedAt == null
                         && (userId != null ? a.UserId == userId : a.VisitorPassId == visitorPassId)
                         && a.AttemptedAt >= nowUtc - AttemptReviewWindow)
                .OrderByDescending(a => a.AttemptedAt)
                .FirstOrDefaultAsync(ct);

            if (attempt is null) return;

            attempt.ReviewedByUserId = reviewedByUserId;
            attempt.ReviewedAt = nowUtc;
            attempt.ResultingLogId = resultingLogId;
        }

        /// <summary>
        /// Tells whoever pressed "Notify me" that the full lot has a bay again.
        /// </summary>
        /// <remarks>
        /// Only the watchers. This used to push "The lot is full" and "A slot
        /// just opened" to every user, including everyone already parked and
        /// everyone not coming in today. The full-lot state is shown in the app
        /// where the Notify-me button lives, so it no longer needs a push.
        ///
        /// Fired on the transition only: one free bay right after an exit means
        /// *this* vehicle freed the only one. Read off the count, so there is no
        /// extra column to get out of step with the slots table.
        /// </remarks>
        private async Task AnnounceSlotOpenedAsync(CancellationToken ct)
        {
            var free = await _db.Set<ParkingSlot>().AsNoTracking()
                .CountAsync(sl => sl.Status == ParkingSlotStatus.Available, ct);

            if (free != 1) return;

            await _notificationService.NotifySlotWatchersAsync(
                "A slot just opened",
                "The lot was full and a bay has come free. Open the app to see where.",
                ct);
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

            var alprCheck = await CheckAlprAsync(
                dto.Gate, [pass.PlateNumber], dto.RfidTagId ?? string.Empty,
                userId: null, visitorPassId: pass.Id, loggedByDeviceId, nowUtc, ct);

            if (alprCheck.Denial is not null) return alprCheck.Denial;

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
                AlprReadingId = alprCheck.Matched?.Id,
                AlprPlateNumber = alprCheck.Matched?.PlateNumber,
                AlprMatched = alprCheck.Matched is not null ? true : null,
                CreatedAt = nowUtc
            };

            await _logs.AddAsync(log, ct);

            if (slot is not null && !_sensors.Watches(slot.Id))
            {
                slot.Status = ParkingSlotStatus.Occupied;
                slot.UpdatedAt = nowUtc;
                _slots.Update(slot);
            }

            if (loggedByUserId is not null)
                await ResolvePendingAttemptAsync(userId: null, visitorPassId: pass.Id, log.Id, loggedByUserId.Value, nowUtc, ct);

            await _logs.SaveAsync(ct);

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
                // A bay with a sensor goes free when the car leaves it, not at the tap.
                if (slot is not null && !_sensors.Watches(slot.Id))
                {
                    slot.Status = ParkingSlotStatus.Available;
                    slot.UpdatedAt = DateTime.UtcNow;
                    _slots.Update(slot);
                }
            }

            // A visitor's pass ends when they leave, in the same save, so the
            // card can be lent to the next visitor straight away. Whether the
            // card itself came back is tracked apart — see CardCollectedAt.
            if (log.VisitorPassId is not null)
            {
                var pass = await _db.Set<VisitorPass>()
                    .FirstOrDefaultAsync(p => p.Id == log.VisitorPassId, ct);

                if (pass is not null && pass.ReturnedAt is null)
                {
                    pass.Status = VisitorPassStatus.Returned;
                    pass.ReturnedAt = log.ExitTime;
                    pass.UpdatedAt = DateTime.UtcNow;
                }
            }

            await _logs.SaveAsync(ct);

            await AnnounceSlotOpenedAsync(ct);

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
