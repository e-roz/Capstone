using AimPark.API.Data;
using AimPark.API.DTOs;
using AimPark.API.Entities;
using AimPark.API.Enums;
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

        // GET /api/admin/logs/parking?page=1&pageSize=20&search=ABC&gate=1&vehicleType=Car&visitor=true&from=...&to=...
        public async Task<ActionResult<RfidAccessLogListResponse>> ListRfidAccessAsync(
            int page,
            int pageSize,
            string? search,
            int? gate,
            VehicleType? vehicleType,
            bool? visitor,
            DateTime? from,
            DateTime? to,
            CancellationToken ct)
        {
            page = Math.Max(1, page);
            pageSize = Math.Clamp(pageSize, 1, 100);

            var query = _db.Set<ParkingLog>().AsNoTracking();

            if (gate is int g)
                query = query.Where(l => l.Gate == g);

            if (vehicleType is VehicleType vt)
                query = query.Where(l => l.VehicleType == vt);

            if (visitor is bool isVisitor)
                query = isVisitor
                    ? query.Where(l => l.VisitorPassId != null)
                    : query.Where(l => l.VisitorPassId == null);

            // Entry time is what the table sorts and shows, so the range is on it.
            if (from is DateTime f)
                query = query.Where(l => l.EntryTime >= f.ToUniversalTime());
            if (to is DateTime t)
                query = query.Where(l => l.EntryTime <= t.ToUniversalTime());

            if (!string.IsNullOrWhiteSpace(search))
            {
                // Plates are held uppercase and unspaced, so a typed "abc 123"
                // has to be squashed the same way before it can match.
                var term = search.Trim();
                var plate = term.Replace(" ", "").Replace("-", "").ToUpperInvariant();
                var like = $"%{term}%";
                var plateLike = $"%{plate}%";

                query = query.Where(l =>
                    (l.User != null && EF.Functions.ILike(l.User.FullName, like)) ||
                    (l.VisitorPass != null && EF.Functions.ILike(l.VisitorPass.VisitorName, like)) ||
                    (l.AlprPlateNumber != null && EF.Functions.ILike(l.AlprPlateNumber, plateLike)) ||
                    (l.VisitorPass != null && EF.Functions.ILike(l.VisitorPass.PlateNumber, plateLike)) ||
                    (l.UserId != null && _db.Set<Vehicle>().Any(v =>
                        v.UserId == l.UserId && EF.Functions.ILike(v.PlateNumber, plateLike))));
            }

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
                    l.VisitorPassId,
                    l.Gate,
                    l.VehicleType,
                    l.AlprPlateNumber,
                    UserName = l.User != null
                        ? l.User.FullName
                        : l.VisitorPass != null
                            ? l.VisitorPass.VisitorName
                            : "Unknown",
                    RfidTagId = l.User != null
                        ? l.User.RfidTagId
                        : l.VisitorPass != null
                            ? l.VisitorPass.RfidTagId
                            : null,
                    VisitorPlate = l.VisitorPass != null ? l.VisitorPass.PlateNumber : null,
                    VisitorType = l.VisitorPass != null ? (VehicleType?)l.VisitorPass.VehicleType : null,
                    Purpose = l.VisitorPass != null ? l.VisitorPass.Purpose : null
                })
                .ToListAsync(ct);

            // One batched lookup for the account holders on this page, to fill in
            // a plate and a type when the camera read none.
            var userIds = logs.Where(l => l.UserId != null)
                              .Select(l => l.UserId!.Value)
                              .Distinct()
                              .ToList();
            var vehiclesByUser = (await _db.Set<Vehicle>().AsNoTracking()
                    .Where(v => userIds.Contains(v.UserId))
                    .Select(v => new { v.UserId, v.PlateNumber, v.VehicleType })
                    .ToListAsync(ct))
                .GroupBy(v => v.UserId)
                .ToDictionary(grp => grp.Key, grp => grp.ToList());

            var response = logs.Select(l =>
            {
                var registered = l.UserId is Guid uid && vehiclesByUser.TryGetValue(uid, out var vs)
                    ? vs
                    : null;

                // Type recorded at entry, else the only type the holder has.
                var type = l.VehicleType ?? l.VisitorType;
                if (type is null && registered is not null)
                {
                    var types = registered.Select(v => v.VehicleType).Distinct().ToList();
                    if (types.Count == 1) type = types[0];
                }

                // What the camera read, else the registered plate of that type
                // when there is exactly one, else nothing: guessing between a
                // holder's two cars would put the wrong plate in the record.
                var plate = l.AlprPlateNumber ?? l.VisitorPlate;
                if (plate is null && registered is not null && type is not null)
                {
                    var ofType = registered.Where(v => v.VehicleType == type).ToList();
                    if (ofType.Count == 1) plate = ofType[0].PlateNumber;
                }

                return new RfidAccessLogEntryResponse
                {
                    Id = l.Id,
                    UserId = l.UserId,
                    UserName = l.UserName,
                    IsVisitor = l.VisitorPassId != null,
                    VisitorPurpose = l.Purpose,
                    RfidTagId = l.RfidTagId,
                    VehicleType = type?.ToString(),
                    PlateNumber = plate,
                    Gate = l.Gate,
                    EntryTime = l.EntryTime,
                    ExitTime = l.ExitTime,
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
