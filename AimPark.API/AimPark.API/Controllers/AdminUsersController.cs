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
        /// Query params: page (default 1), pageSize (default 20),
        /// status (optional — either an AccountStatus value, or "Archived" to filter to archived accounts),
        /// search (optional, matches full name, email, or plate number).
        /// </summary>
        [HttpGet]
        public Task<ActionResult<UserListResponse>> List(
            [FromQuery] int page = 1,
            [FromQuery] int pageSize = 20,
            [FromQuery] string? status = null,
            [FromQuery] string? search = null,
            [FromQuery] string? role = null,
            CancellationToken ct = default)
            => _adminUserService.ListAsync(page, pageSize, status, search, role, ct);

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
        /// Archives a user account (soft delete). Sets IsDeleted=true and DeletedAt=now.
        /// The user's data is retained and can be restored later; they cannot log in while archived.
        /// Requires the acting admin's password to confirm, since this is a destructive action.
        /// </summary>
        [HttpDelete("{userId:guid}")]
        public Task<ActionResult<object>> Archive(Guid userId, [FromBody] ArchiveUserDto dto, CancellationToken ct)
            => _adminUserService.ArchiveAsync(userId, GetAdminUserId(), dto, ct);

        /// <summary>
        /// Permanently deletes a user's uploaded identity documents — the image
        /// files and the raw OCR readings taken from them. The account, and every
        /// violation, payment and parking record on it, is left alone.
        /// Requires the acting admin's password, and cannot be undone.
        /// </summary>
        [HttpDelete("{userId:guid}/documents")]
        public Task<ActionResult<object>> DeleteDocuments(
            Guid userId,
            [FromBody] DeleteDocumentsDto dto,
            CancellationToken ct)
            => _adminUserService.DeleteDocumentsAsync(userId, GetAdminUserId(), dto, ct);

        /// <summary>
        /// Restores a soft-deleted user account, clearing IsDeleted and DeletedAt.
        /// </summary>
        [HttpPost("{userId:guid}/restore")]
        public Task<ActionResult<object>> Restore(Guid userId, CancellationToken ct)
            => _adminUserService.RestoreAsync(userId, GetAdminUserId(), ct);

        /// <summary>
        /// Assigns an RFID tag to a user and sets their RfidStatus to Active.
        /// Stands in for physical tag provisioning until hardware is integrated.
        /// </summary>
        [HttpPost("{userId:guid}/assign-rfid")]
        public Task<ActionResult<object>> AssignRfid(Guid userId, [FromBody] AssignRfidDto dto, CancellationToken ct)
            => _adminUserService.AssignRfidAsync(userId, GetAdminUserId(), dto, ct);

        /// <summary>
        /// Revokes a user's RFID tag, clearing it and setting RfidStatus back to Unassigned.
        /// </summary>
        [HttpPost("{userId:guid}/revoke-rfid")]
        public Task<ActionResult<object>> RevokeRfid(Guid userId, CancellationToken ct)
            => _adminUserService.RevokeRfidAsync(userId, GetAdminUserId(), ct);

        private Guid GetAdminUserId()
            => Guid.Parse(User.FindFirst(ClaimTypes.NameIdentifier)!.Value);
    }
}
