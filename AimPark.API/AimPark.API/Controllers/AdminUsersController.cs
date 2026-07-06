using AimPark.API.DTOs;
using AimPark.API.Enums;
using AimPark.API.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;

namespace AimPark.API.Controllers
{
    [ApiController]
    [Route("api/admin/users")]
    [Authorize(Roles = "Admin")]
    public class AdminUsersController : ControllerBase
    {
        private readonly IAdminUserService _adminUserService;

        public AdminUsersController(IAdminUserService adminUserService)
        {
            _adminUserService = adminUserService;
        }

        /// <summary>
        /// Returns a paginated list of all users (including soft-deleted ones).
        /// Query params: page (default 1), pageSize (default 20), status (optional AccountStatus filter).
        /// </summary>
        [HttpGet]
        public Task<ActionResult<UserListResponse>> List(
            [FromQuery] int page = 1,
            [FromQuery] int pageSize = 20,
            [FromQuery] AccountStatus? status = null,
            CancellationToken ct = default)
            => _adminUserService.ListAsync(page, pageSize, status, ct);

        /// <summary>
        /// Suspends an active user account.
        /// The optional reason is recorded in the audit log.
        /// </summary>
        [HttpPost("{userId:guid}/suspend")]
        public Task<ActionResult<object>> Suspend(
            Guid userId,
            [FromBody] SuspendUserDto dto,
            CancellationToken ct)
            => _adminUserService.SuspendAsync(userId, GetAdminUserId(), dto, ct);

        /// <summary>
        /// Reverts a suspended user back to Active status.
        /// </summary>
        [HttpPost("{userId:guid}/unsuspend")]
        public Task<ActionResult<object>> Unsuspend(Guid userId, CancellationToken ct)
            => _adminUserService.UnsuspendAsync(userId, GetAdminUserId(), ct);

        /// <summary>
        /// Soft-deletes a user account. Sets IsDeleted=true and DeletedAt=now.
        /// The user's data is retained for audit purposes; they cannot log in.
        /// </summary>
        [HttpDelete("{userId:guid}")]
        public Task<ActionResult<object>> Delete(Guid userId, CancellationToken ct)
            => _adminUserService.DeleteAsync(userId, GetAdminUserId(), ct);

        /// <summary>
        /// Restores a soft-deleted user account, clearing IsDeleted and DeletedAt.
        /// </summary>
        [HttpPost("{userId:guid}/restore")]
        public Task<ActionResult<object>> Restore(Guid userId, CancellationToken ct)
            => _adminUserService.RestoreAsync(userId, GetAdminUserId(), ct);

        private Guid GetAdminUserId()
            => Guid.Parse(User.FindFirst(ClaimTypes.NameIdentifier)!.Value);
    }
}
