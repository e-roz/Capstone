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
    public class AlprService : IAlprService
    {
        private readonly AppDbContext _db;

        public AlprService(AppDbContext db)
        {
            _db = db;
        }

        public async Task<ActionResult<AlprReadingResponse>> SubmitReadingAsync(
            SubmitAlprReadingDto dto, Guid deviceId, CancellationToken ct)
        {
            var device = await _db.Set<GateDevice>()
                .FirstOrDefaultAsync(d => d.Id == deviceId && !d.IsRevoked, ct);

            if (device is null)
                return new UnauthorizedObjectResult(new { message = "Device not found or revoked." });

            // Belt-and-suspenders alongside the DeviceType claim check that
            // routes an RFID reader's key away from this endpoint entirely —
            // this is what stops a *revoked-then-reissued* mismatch from ever
            // reaching the readings table.
            if (device.DeviceType != GateDeviceType.AlprCamera)
                return new ObjectResult(new
                {
                    message = "This key is not registered to an ALPR camera."
                })
                { StatusCode = StatusCodes.Status403Forbidden };

            var plate = IdentifierNormalizer.NormalizePlate(dto.PlateNumber);

            // A bare heartbeat. Authenticating already refreshed
            // GateDevice.LastSeenAt, so there is nothing further to record.
            if (plate.Length == 0)
                return new OkObjectResult(new AlprReadingResponse { Recorded = false });

            var reading = new AlprReading
            {
                Id = Guid.NewGuid(),
                Gate = device.Gate,
                PlateNumber = plate,
                Confidence = dto.Confidence,
                DeviceId = device.Id,
                ReadAt = DateTime.UtcNow,
                CreatedAt = DateTime.UtcNow
            };

            _db.Set<AlprReading>().Add(reading);
            await _db.SaveChangesAsync(ct);

            return new OkObjectResult(new AlprReadingResponse
            {
                ReadingId = reading.Id,
                Recorded = true
            });
        }
    }
}
