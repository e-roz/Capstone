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
        /// search (optional, matches full name, email, or plate number),
        /// card (optional — "none" or "has"; limits the list to ordinary users with or without a card),
        /// expiry (optional — "expired" or "expiring"; active users whose licence or a vehicle's
        /// registration has run out, or runs out within 60 days).
        /// </summary>
        [HttpGet]
        public Task<ActionResult<UserListResponse>> List(
            [FromQuery] int page = 1,
            [FromQuery] int pageSize = 20,
            [FromQuery] string? status = null,
            [FromQuery] string? search = null,
            [FromQuery] string? role = null,
            [FromQuery] string? card = null,
            [FromQuery] string? expiry = null,
            CancellationToken ct = default)
            => _adminUserService.ListAsync(page, pageSize, status, search, role, card, expiry, ct);

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
        /// Emails the user a password-reset code (the same one "Forgot password"
        /// sends). Works on Security and ordinary users, never Admins.
        /// Requires the acting admin's password.
        /// </summary>
        [HttpPost("{userId:guid}/reset-password")]
        public Task<ActionResult<object>> ResetPassword(Guid userId, [FromBody] ArchiveUserDto dto, CancellationToken ct)
            => _adminUserService.SendPasswordResetAsync(userId, GetAdminUserId(), dto, ct);

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
        /// Revokes a user's RFID tag, clearing it and setting RfidStatus back to
        /// Unassigned. The reason decides whether the physical card goes back
        /// into the free pool or is blocked from ever being reissued.
        /// </summary>
        [HttpPost("{userId:guid}/revoke-rfid")]
        public Task<ActionResult<object>> RevokeRfid(Guid userId, [FromBody] RevokeRfidDto dto, CancellationToken ct)
            => _adminUserService.RevokeRfidAsync(userId, GetAdminUserId(), dto, ct);

        /// <summary>
        /// Revokes the RFID tag from several users in one call, all for the same
        /// reason — built for a graduation batch rather than one card at a time.
        /// Users with no tag assigned are skipped and reported, not treated as
        /// a failure of the whole request.
        /// </summary>
        [HttpPost("bulk-revoke-rfid")]
        public Task<ActionResult<BulkRevokeRfidResponse>> BulkRevokeRfid([FromBody] BulkRevokeRfidDto dto, CancellationToken ct)
            => _adminUserService.BulkRevokeRfidAsync(GetAdminUserId(), dto, ct);

        /// <summary>
        /// Archives many accounts at once, for the end of a semester. Send
        /// <c>dryRun: true</c> first: it lists who would be archived and who is
        /// skipped (parked now, owing money, an open violation) and changes
        /// nothing. The real run needs a reason and the administrator's password,
        /// and also hands each account's RFID card back to the pool.
        /// </summary>
        [HttpPost("bulk-archive")]
        public Task<ActionResult<BulkArchiveResponse>> BulkArchive([FromBody] BulkArchiveDto dto, CancellationToken ct)
            => _adminUserService.BulkArchiveAsync(GetAdminUserId(), dto, ct);

        private Guid GetAdminUserId()
            => Guid.Parse(User.FindFirst(ClaimTypes.NameIdentifier)!.Value);
    }
}
