using AimPark.API.Data;
using AimPark.API.DTOs;
using AimPark.API.Entities;
using AimPark.API.Enums;
using AimPark.API.Interfaces;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace AimPark.API.Services
{
    public class ParkingSlotService : IParkingSlotService
    {
        private readonly IRepository<ParkingSlot> _slots;
        private readonly AppDbContext _db;

        public ParkingSlotService(IRepository<ParkingSlot> slots, AppDbContext db)
        {
            _slots = slots;
            _db = db;
        }

        // GET /api/parking/slots
        public async Task<ActionResult<ParkingAvailabilityResponse>> GetAvailabilityAsync(CancellationToken ct)
            => await BuildResponseAsync(_db.Set<ParkingSlot>().AsNoTracking(), ct);

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

        private static async Task<ParkingAvailabilityResponse> BuildResponseAsync(IQueryable<ParkingSlot> query, CancellationToken ct)
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

            return new ParkingAvailabilityResponse
            {
                Slots = slots,
                TotalSlots = slots.Count,
                AvailableSlots = slots.Count(s => s.Status == ParkingSlotStatus.Available.ToString())
            };
        }
    }
}
