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

        // GET /api/admin/users?page=1&pageSize=20&status=Suspended&search=cruz (includes archived users)
        public async Task<ActionResult<UserListResponse>> ListAsync(int page, int pageSize, string? status, string? search, CancellationToken ct)
        {
            // Clamp to sane defaults
            page = Math.Max(1, page);
            pageSize = Math.Clamp(pageSize, 1, 100);

            var query = _db.Set<User>().AsNoTracking();

            // "Archived" isn't a real AccountStatus — it's the separate IsDeleted flag —
            // so it's handled as a virtual filter value here rather than a real enum member.
            if (string.Equals(status, "Archived", StringComparison.OrdinalIgnoreCase))
            {
                query = query.Where(u => u.IsDeleted);
            }
            else if (!string.IsNullOrWhiteSpace(status) && Enum.TryParse<AccountStatus>(status, true, out var parsedStatus))
            {
                query = query.Where(u => u.AccountStatus == parsedStatus);
            }

            if (!string.IsNullOrWhiteSpace(search))
            {
                var term = search.Trim().ToLower();
                query = query.Where(u =>
                    u.FullName.ToLower().Contains(term) ||
                    u.Email.ToLower().Contains(term) ||
                    _db.Set<Vehicle>().Any(v => v.UserId == u.Id && v.PlateNumber.ToLower().Contains(term)));
            }

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
            if (userId == adminUserId)
                return new BadRequestObjectResult(new { message = "You cannot suspend your own account." });

            var user = await _users.FindAsync(u => u.Id == userId, ct);
            if (user is null)
                return new NotFoundObjectResult(new { message = "User not found." });

            if (user.IsDeleted)
                return new BadRequestObjectResult(new { message = "Cannot suspend an archived user." });

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
                return new BadRequestObjectResult(new { message = "Cannot unsuspend an archived user." });

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

        // DELETE /api/admin/users/{userId} (archive — soft delete)
        public async Task<ActionResult<object>> ArchiveAsync(Guid userId, Guid adminUserId, ArchiveUserDto dto, CancellationToken ct)
        {
            if (userId == adminUserId)
                return new BadRequestObjectResult(new { message = "You cannot archive your own account." });

            var admin = await _users.FindAsync(u => u.Id == adminUserId, ct);
            if (admin?.PasswordHash is null)
                return new BadRequestObjectResult(new { message = "Password confirmation is unavailable for this admin account." });

            if (string.IsNullOrEmpty(dto.Password) || !BCrypt.Net.BCrypt.Verify(dto.Password, admin.PasswordHash))
                return new UnauthorizedObjectResult(new { message = "Incorrect password." });

            var user = await _users.FindAsync(u => u.Id == userId, ct);
            if (user is null)
                return new NotFoundObjectResult(new { message = "User not found." });

            if (user.IsDeleted)
                return new BadRequestObjectResult(new { message = "User is already archived." });

            var oldValue = $"IsDeleted=false";
            user.IsDeleted = true;
            user.DeletedAt = DateTime.UtcNow;
            user.UpdatedAt = DateTime.UtcNow;

            await LogActionAsync(adminUserId, userId, "Archive", oldValue, "IsDeleted=true", null, ct);

            _users.Update(user);
            await _users.SaveAsync(ct);

            return new OkObjectResult(new { message = "User archived. Data is retained and can be restored later." });
        }

        // POST /api/admin/users/{userId}/restore
        public async Task<ActionResult<object>> RestoreAsync(Guid userId, Guid adminUserId, CancellationToken ct)
        {
            var user = await _users.FindAsync(u => u.Id == userId, ct);
            if (user is null)
                return new NotFoundObjectResult(new { message = "User not found." });

            if (!user.IsDeleted)
                return new BadRequestObjectResult(new { message = "User is not archived." });

            var wasSuspended = user.AccountStatus == AccountStatus.Suspended;
            var oldValue = $"IsDeleted=true, DeletedAt={user.DeletedAt:O}, AccountStatus={user.AccountStatus}";
            user.IsDeleted = false;
            user.DeletedAt = null;

            // Restore is meant to fully undo whatever locked the account out, so a suspension
            // picked up before/along with the deletion is lifted too — otherwise the account
            // comes back "restored" but still unable to log in, which reads as a bug to admins.
            // Registration-review statuses (Rejected/PendingReview) are left untouched since
            // restore isn't an approval action.
            if (wasSuspended)
                user.AccountStatus = AccountStatus.Active;

            user.UpdatedAt = DateTime.UtcNow;

            var newValue = $"IsDeleted=false, AccountStatus={user.AccountStatus}";
            await LogActionAsync(adminUserId, userId, "Restore", oldValue, newValue, null, ct);

            _users.Update(user);
            await _users.SaveAsync(ct);

            var message = wasSuspended
                ? "User restored successfully. Suspension was also lifted."
                : "User restored successfully.";
            return new OkObjectResult(new { message });
        }

        // POST /api/admin/users/{userId}/assign-rfid
        public async Task<ActionResult<object>> AssignRfidAsync(Guid userId, Guid adminUserId, AssignRfidDto dto, CancellationToken ct)
        {
            if (string.IsNullOrWhiteSpace(dto.RfidTagId))
                return new BadRequestObjectResult(new { message = "RFID tag ID is required." });

            var user = await _users.FindAsync(u => u.Id == userId, ct);
            if (user is null)
                return new NotFoundObjectResult(new { message = "User not found." });

            var tagId = dto.RfidTagId.Trim();
            var tagInUse = await _users.ExistsAsync(u => u.Id != userId && u.RfidTagId == tagId, ct);
            if (tagInUse)
                return new BadRequestObjectResult(new { message = "This RFID tag is already assigned to another user." });

            var oldValue = $"RfidTagId={user.RfidTagId}, RfidStatus={user.RfidStatus}";
            user.RfidTagId = tagId;
            user.RfidStatus = RfidStatus.Active;
            user.UpdatedAt = DateTime.UtcNow;

            await LogActionAsync(adminUserId, userId, "AssignRfid", oldValue, $"RfidTagId={user.RfidTagId}, RfidStatus={user.RfidStatus}", null, ct);

            _users.Update(user);
            await _users.SaveAsync(ct);

            return new OkObjectResult(new { message = "RFID tag assigned." });
        }

        // POST /api/admin/users/{userId}/revoke-rfid
        public async Task<ActionResult<object>> RevokeRfidAsync(Guid userId, Guid adminUserId, CancellationToken ct)
        {
            var user = await _users.FindAsync(u => u.Id == userId, ct);
            if (user is null)
                return new NotFoundObjectResult(new { message = "User not found." });

            if (user.RfidStatus == RfidStatus.Unassigned)
                return new BadRequestObjectResult(new { message = "User has no RFID tag assigned." });

            var oldValue = $"RfidTagId={user.RfidTagId}, RfidStatus={user.RfidStatus}";
            user.RfidTagId = null;
            user.RfidStatus = RfidStatus.Unassigned;
            user.UpdatedAt = DateTime.UtcNow;

            await LogActionAsync(adminUserId, userId, "RevokeRfid", oldValue, $"RfidTagId={user.RfidTagId}, RfidStatus={user.RfidStatus}", null, ct);

            _users.Update(user);
            await _users.SaveAsync(ct);

            return new OkObjectResult(new { message = "RFID tag revoked." });
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
