using AimPark.API.Data;
using AimPark.API.DTOs;
using AimPark.API.Entities;
using AimPark.API.Helpers;
using AimPark.API.Interfaces;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace AimPark.API.Services
{
    public class RfidEnrollmentService : IRfidEnrollmentService
    {
        private readonly AppDbContext _db;
        private readonly RfidScanBuffer _buffer;

        public RfidEnrollmentService(AppDbContext db, RfidScanBuffer buffer)
        {
            _db = db;
            _buffer = buffer;
        }

        // POST /api/admin/rfid/scan  (enrollment reader)
        public async Task<ActionResult<RfidScanResponse>> RecordScanAsync(
            RfidScanDto dto, Guid deviceId, string deviceName, CancellationToken ct)
        {
            var tag = RfidTag.Normalize(dto.RfidTagId);

            if (!RfidTag.LooksValid(tag))
            {
                // Not buffered: a misread must never become the value an admin
                // is one click away from saving onto an account.
                return new BadRequestObjectResult(new RfidScanResponse
                {
                    Result = "INVALID_TAG",
                    Message = "That does not look like a card UID.",
                    RfidTagId = tag
                });
            }

            _buffer.Record(tag, deviceId, deviceName);

            var holder = await _db.Set<User>().AsNoTracking()
                .Where(u => u.RfidTagId == tag && !u.IsDeleted)
                .Select(u => u.FullName)
                .FirstOrDefaultAsync(ct);

            // Both outcomes are 200: the reader did its job either way, and the
            // admin is the one who decides whether reassigning is intended.
            return new OkObjectResult(holder is null
                ? new RfidScanResponse
                {
                    Result = "FREE",
                    Message = "Card read. Not yet assigned.",
                    RfidTagId = tag
                }
                : new RfidScanResponse
                {
                    Result = "IN_USE",
                    Message = $"Card read. Already assigned to {holder}.",
                    RfidTagId = tag
                });
        }

        // GET /api/admin/rfid/last-scan  (admin panel)
        public async Task<ActionResult<RfidLastScanResponse?>> GetLastScanAsync(CancellationToken ct)
        {
            var scan = _buffer.Latest();
            if (scan is null)
                return new OkObjectResult(null);

            // Looked up per poll rather than stored with the scan, so a card
            // revoked while the dialog sits open stops reading as taken.
            var holder = await _db.Set<User>().AsNoTracking()
                .Where(u => u.RfidTagId == scan.RfidTagId && !u.IsDeleted)
                .Select(u => new { u.Id, u.FullName })
                .FirstOrDefaultAsync(ct);

            return new OkObjectResult(new RfidLastScanResponse
            {
                ScanId = scan.ScanId,
                RfidTagId = scan.RfidTagId,
                ScannedAt = scan.ScannedAt,
                DeviceName = scan.DeviceName,
                IsAssigned = holder is not null,
                AssignedToUserId = holder?.Id,
                AssignedToName = holder?.FullName
            });
        }
    }
}
