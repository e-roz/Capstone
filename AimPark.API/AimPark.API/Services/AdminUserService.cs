using AimPark.API.Data;
using AimPark.API.DTOs;
using AimPark.API.Entities;
using AimPark.API.Enums;
using AimPark.API.Interfaces;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace AimPark.API.Services
{
    public class AdminUserService : IAdminUserService
    {
        private readonly IRepository<User> _users;
        private readonly IRepository<AdminAuditLog> _auditLogs;
        private readonly AppDbContext _db;

        public AdminUserService(IRepository<User> users, IRepository<AdminAuditLog> auditLogs, AppDbContext db)
        {
            _users = users;
            _auditLogs = auditLogs;
            _db = db;
        }

        // GET /api/admin/users?page=1&pageSize=20&status=Suspended
        public async Task<ActionResult<UserListResponse>> ListAsync(int page, int pageSize, AccountStatus? status, CancellationToken ct)
        {
            // Clamp to sane defaults
            page = Math.Max(1, page);
            pageSize = Math.Clamp(pageSize, 1, 100);

            var query = _db.Set<User>().AsNoTracking();

            if (status.HasValue)
                query = query.Where(u => u.AccountStatus == status.Value);

            var totalCount = await query.CountAsync(ct);

            var users = await query
                .OrderByDescending(u => u.CreatedAt)
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .Select(u => new UserSummaryResponse
                {
                    UserId       = u.Id,
                    FullName     = u.FullName,
                    Email        = u.Email,
                    AccountStatus = u.AccountStatus.ToString(),
                    IsDeleted    = u.IsDeleted,
                    CreatedAt    = u.CreatedAt
                })
                .ToListAsync(ct);

            return new OkObjectResult(new UserListResponse
            {
                Users      = users,
                TotalCount = totalCount,
                Page       = page,
                PageSize   = pageSize
            });
        }

        // POST /api/admin/users/{userId}/suspend
        public async Task<ActionResult<object>> SuspendAsync(Guid userId, Guid adminUserId, SuspendUserDto dto, CancellationToken ct)
        {
            var user = await _users.FindAsync(u => u.Id == userId, ct);
            if (user is null)
                return new NotFoundObjectResult(new { message = "User not found." });

            if (user.IsDeleted)
                return new BadRequestObjectResult(new { message = "Cannot suspend a deleted user." });

            if (user.AccountStatus == AccountStatus.Suspended)
                return new BadRequestObjectResult(new { message = "User is already suspended." });

            var oldStatus = user.AccountStatus.ToString();
            user.AccountStatus = AccountStatus.Suspended;
            user.UpdatedAt = DateTime.UtcNow;

            await LogActionAsync(adminUserId, userId, "Suspend", oldStatus, user.AccountStatus.ToString(), dto.Reason, ct);

            _users.Update(user);
            await _users.SaveAsync(ct);

            return new OkObjectResult(new { message = "User suspended." });
        }

        // POST /api/admin/users/{userId}/unsuspend
        public async Task<ActionResult<object>> UnsuspendAsync(Guid userId, Guid adminUserId, CancellationToken ct)
        {
            var user = await _users.FindAsync(u => u.Id == userId, ct);
            if (user is null)
                return new NotFoundObjectResult(new { message = "User not found." });

            if (user.IsDeleted)
                return new BadRequestObjectResult(new { message = "Cannot unsuspend a deleted user." });

            if (user.AccountStatus != AccountStatus.Suspended)
                return new BadRequestObjectResult(new { message = "User is not currently suspended." });

            var oldStatus = user.AccountStatus.ToString();
            // Revert to Active — suspension is always lifted back to Active,
            // since the user was Active before being suspended.
            user.AccountStatus = AccountStatus.Active;
            user.UpdatedAt = DateTime.UtcNow;

            await LogActionAsync(adminUserId, userId, "Unsuspend", oldStatus, user.AccountStatus.ToString(), null, ct);

            _users.Update(user);
            await _users.SaveAsync(ct);

            return new OkObjectResult(new { message = "User unsuspended. Account restored to Active." });
        }

        // DELETE /api/admin/users/{userId}
        public async Task<ActionResult<object>> DeleteAsync(Guid userId, Guid adminUserId, CancellationToken ct)
        {
            var user = await _users.FindAsync(u => u.Id == userId, ct);
            if (user is null)
                return new NotFoundObjectResult(new { message = "User not found." });

            if (user.IsDeleted)
                return new BadRequestObjectResult(new { message = "User is already deleted." });

            var oldValue = $"IsDeleted=false";
            user.IsDeleted = true;
            user.DeletedAt = DateTime.UtcNow;
            user.UpdatedAt = DateTime.UtcNow;

            await LogActionAsync(adminUserId, userId, "Delete", oldValue, "IsDeleted=true", null, ct);

            _users.Update(user);
            await _users.SaveAsync(ct);

            return new OkObjectResult(new { message = "User soft-deleted. Data is retained for audit purposes." });
        }

        // POST /api/admin/users/{userId}/restore
        public async Task<ActionResult<object>> RestoreAsync(Guid userId, Guid adminUserId, CancellationToken ct)
        {
            var user = await _users.FindAsync(u => u.Id == userId, ct);
            if (user is null)
                return new NotFoundObjectResult(new { message = "User not found." });

            if (!user.IsDeleted)
                return new BadRequestObjectResult(new { message = "User is not deleted." });

            var oldValue = $"IsDeleted=true, DeletedAt={user.DeletedAt:O}";
            user.IsDeleted = false;
            user.DeletedAt = null;
            user.UpdatedAt = DateTime.UtcNow;

            await LogActionAsync(adminUserId, userId, "Restore", oldValue, "IsDeleted=false", null, ct);

            _users.Update(user);
            await _users.SaveAsync(ct);

            return new OkObjectResult(new { message = "User restored successfully." });
        }

        private async Task LogActionAsync(
            Guid adminUserId,
            Guid targetUserId,
            string action,
            string? oldValue,
            string? newValue,
            string? reason,
            CancellationToken ct)
        {
            await _auditLogs.AddAsync(new AdminAuditLog
            {
                Id = Guid.NewGuid(),
                AdminUserId = adminUserId,
                TargetUserId = targetUserId,
                Action = action,
                OldValue = oldValue,
                NewValue = newValue,
                Reason = reason,
                CreatedAt = DateTime.UtcNow
            }, ct);
        }
    }
}
