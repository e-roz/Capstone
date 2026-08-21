using AimPark.API.Data;
using AimPark.API.DTOs;
using AimPark.API.Entities;
using AimPark.API.Interfaces;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace AimPark.API.Services
{
    public class AdminLogService : IAdminLogService
    {
        private readonly AppDbContext _db;

        public AdminLogService(AppDbContext db)
        {
            _db = db;
        }

        // GET /api/admin/logs/rfid-access?page=1&pageSize=20&source=Device
        public async Task<ActionResult<RfidAccessLogListResponse>> ListRfidAccessAsync(
            int page,
            int pageSize,
            string? source,
            CancellationToken ct)
        {
            page = Math.Max(1, page);
            pageSize = Math.Clamp(pageSize, 1, 100);

            var query = _db.Set<ParkingLog>().AsNoTracking();

            // A row carries either a device or a staff account, never both, so
            // the filter is a null check rather than a stored discriminator.
            if (string.Equals(source, "Device", StringComparison.OrdinalIgnoreCase))
                query = query.Where(l => l.LoggedByDeviceId != null);
            else if (string.Equals(source, "Manual", StringComparison.OrdinalIgnoreCase))
                query = query.Where(l => l.LoggedByDeviceId == null);

            var totalCount = await query.CountAsync(ct);

            var logs = await query
                .OrderByDescending(l => l.EntryTime)
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .Select(l => new
                {
                    l.Id,
                    l.UserId,
                    l.EntryTime,
                    l.ExitTime,
                    l.CreatedAt,
                    l.LoggedByDeviceId,
                    l.LoggedByUserId,
                    UserName = l.User.FullName,
                    l.User.RfidTagId,
                    SlotCode = l.Slot != null ? l.Slot.SlotCode : null,
                    Gate = l.Slot != null ? (int?)l.Slot.Gate : null
                })
                .ToListAsync(ct);

            // Two batched lookups rather than a join per row: the recorder is a
            // device on most rows and a staff account on a few, and neither has
            // a navigation property on ParkingLog to join through.
            var deviceIds = logs.Where(l => l.LoggedByDeviceId != null)
                                .Select(l => l.LoggedByDeviceId!.Value)
                                .Distinct()
                                .ToList();
            var deviceNames = await _db.Set<GateDevice>().AsNoTracking()
                .Where(d => deviceIds.Contains(d.Id))
                .ToDictionaryAsync(d => d.Id, d => d.Name, ct);

            var staffIds = logs.Where(l => l.LoggedByUserId != null)
                               .Select(l => l.LoggedByUserId!.Value)
                               .Distinct()
                               .ToList();
            var staffNames = await _db.Set<User>().AsNoTracking()
                .Where(u => staffIds.Contains(u.Id))
                .ToDictionaryAsync(u => u.Id, u => u.FullName, ct);

            var response = logs.Select(l =>
            {
                var byDevice = l.LoggedByDeviceId != null;
                return new RfidAccessLogEntryResponse
                {
                    Id = l.Id,
                    UserId = l.UserId,
                    UserName = l.UserName,
                    RfidTagId = l.RfidTagId,
                    SlotCode = l.SlotCode,
                    Gate = l.Gate,
                    EntryTime = l.EntryTime,
                    ExitTime = l.ExitTime,
                    Source = byDevice ? "Device" : "Manual",
                    RecordedBy = byDevice
                        ? deviceNames.GetValueOrDefault(l.LoggedByDeviceId!.Value, "Unknown device")
                        : l.LoggedByUserId != null
                            ? staffNames.GetValueOrDefault(l.LoggedByUserId.Value, "Unknown user")
                            : null,
                    CreatedAt = l.CreatedAt
                };
            }).ToList();

            return new OkObjectResult(new RfidAccessLogListResponse
            {
                Logs = response,
                TotalCount = totalCount,
                Page = page,
                PageSize = pageSize
            });
        }

        // GET /api/admin/logs/user-activity?page=1&pageSize=20&activity=Login
        public async Task<ActionResult<UserActivityLogListResponse>> ListUserActivityAsync(
            int page,
            int pageSize,
            string? activity,
            CancellationToken ct)
        {
            page = Math.Max(1, page);
            pageSize = Math.Clamp(pageSize, 1, 100);

            var query = _db.Set<UserActivityLog>().AsNoTracking();

            if (!string.IsNullOrWhiteSpace(activity))
                query = query.Where(l => l.Activity == activity);

            var totalCount = await query.CountAsync(ct);

            var logs = await query
                .OrderByDescending(l => l.CreatedAt)
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .ToListAsync(ct);

            // Rows deliberately have no FK to User — a failed login against an
            // address that never existed still gets recorded — so names are
            // resolved here, with the stored email as the fallback.
            var userIds = logs.Where(l => l.UserId != null)
                              .Select(l => l.UserId!.Value)
                              .Distinct()
                              .ToList();
            var names = await _db.Set<User>().AsNoTracking()
                .Where(u => userIds.Contains(u.Id))
                .ToDictionaryAsync(u => u.Id, u => u.FullName, ct);

            var response = logs.Select(l => new UserActivityLogEntryResponse
            {
                Id = l.Id,
                UserId = l.UserId,
                EmailAtTime = l.EmailAtTime,
                UserName = l.UserId != null
                    ? names.GetValueOrDefault(l.UserId.Value, l.EmailAtTime)
                    : l.EmailAtTime,
                Activity = l.Activity,
                Detail = l.Detail,
                IpAddress = l.IpAddress,
                CreatedAt = l.CreatedAt
            }).ToList();

            return new OkObjectResult(new UserActivityLogListResponse
            {
                Logs = response,
                TotalCount = totalCount,
                Page = page,
                PageSize = pageSize
            });
        }

        // GET /api/admin/logs/errors?page=1&pageSize=20
        public async Task<ActionResult<SystemErrorLogListResponse>> ListErrorsAsync(
            int page,
            int pageSize,
            CancellationToken ct)
        {
            page = Math.Max(1, page);
            pageSize = Math.Clamp(pageSize, 1, 100);

            var query = _db.Set<SystemErrorLog>().AsNoTracking();

            var totalCount = await query.CountAsync(ct);

            var logs = await query
                .OrderByDescending(l => l.CreatedAt)
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .Select(l => new SystemErrorLogEntryResponse
                {
                    Id = l.Id,
                    ErrorType = l.ErrorType,
                    Message = l.Message,
                    StackTrace = l.StackTrace,
                    Path = l.Path,
                    StatusCode = l.StatusCode,
                    TraceId = l.TraceId,
                    CreatedAt = l.CreatedAt
                })
                .ToListAsync(ct);

            return new OkObjectResult(new SystemErrorLogListResponse
            {
                Logs = logs,
                TotalCount = totalCount,
                Page = page,
                PageSize = pageSize
            });
        }
    }
}
