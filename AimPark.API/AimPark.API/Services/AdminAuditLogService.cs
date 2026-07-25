using AimPark.API.Data;
using AimPark.API.DTOs;
using AimPark.API.Entities;
using AimPark.API.Interfaces;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace AimPark.API.Services
{
    public class AdminAuditLogService : IAdminAuditLogService
    {
        private readonly AppDbContext _db;

        public AdminAuditLogService(AppDbContext db)
        {
            _db = db;
        }

        // GET /api/admin/audit-logs?page=1&pageSize=20&action=Suspend
        public async Task<ActionResult<AuditLogListResponse>> ListAsync(int page, int pageSize, string? action, CancellationToken ct)
        {
            page = Math.Max(1, page);
            pageSize = Math.Clamp(pageSize, 1, 100);

            var query = _db.Set<AdminAuditLog>().AsNoTracking();

            if (!string.IsNullOrWhiteSpace(action))
                query = query.Where(l => l.Action == action);

            var totalCount = await query.CountAsync(ct);

            var logs = await query
                .OrderByDescending(l => l.CreatedAt)
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .ToListAsync(ct);

            // AdminAuditLog only stores raw user IDs (no FK/navigation), so names are
            // resolved here in a single batched lookup rather than per-row.
            var userIds = logs.SelectMany(l => new[] { l.AdminUserId, l.TargetUserId }).Distinct().ToList();
            var names = await _db.Set<User>().AsNoTracking()
                .Where(u => userIds.Contains(u.Id))
                .Select(u => new { u.Id, Display = u.FullName + " (" + u.Email + ")" })
                .ToDictionaryAsync(u => u.Id, u => u.Display, ct);

            var response = logs.Select(l => new AuditLogEntryResponse
            {
                Id = l.Id,
                AdminUserId = l.AdminUserId,
                AdminName = names.GetValueOrDefault(l.AdminUserId, "Unknown user"),
                TargetUserId = l.TargetUserId,
                TargetName = names.GetValueOrDefault(l.TargetUserId, "Unknown user"),
                Action = l.Action,
                OldValue = l.OldValue,
                NewValue = l.NewValue,
                Reason = l.Reason,
                CreatedAt = l.CreatedAt
            }).ToList();

            return new OkObjectResult(new AuditLogListResponse
            {
                Logs = response,
                TotalCount = totalCount,
                Page = page,
                PageSize = pageSize
            });
        }
    }
}
