using AimPark.API.DTOs;
using AimPark.API.Entities;
using AimPark.API.Enums;
using Microsoft.AspNetCore.Mvc;

namespace AimPark.API.Interfaces
{
    public interface IAdminUserService
    {
        Task<ActionResult<UserListResponse>> ListAsync(int page, int pageSize, string? status, string? search, string? role, string? card, string? expiry, CancellationToken ct);
        Task<ActionResult<object>> ArchiveAsync(Guid userId, Guid adminUserId, ArchiveUserDto dto, CancellationToken ct);
        Task<ActionResult<object>> SendPasswordResetAsync(Guid userId, Guid adminUserId, ArchiveUserDto dto, CancellationToken ct);
        Task<ActionResult<object>> RestoreAsync(Guid userId, Guid adminUserId, CancellationToken ct);
        Task<ActionResult<object>> DeleteDocumentsAsync(Guid userId, Guid adminUserId, DeleteDocumentsDto dto, CancellationToken ct);
        Task<ActionResult<object>> AssignRfidAsync(Guid userId, Guid adminUserId, AssignRfidDto dto, CancellationToken ct);
        Task<ActionResult<object>> RevokeRfidAsync(Guid userId, Guid adminUserId, RevokeRfidDto dto, CancellationToken ct);
        /// <summary>
        /// Takes the card off a user who reached three Accountable violations.
        /// Same card filing and audit trail as a manual revoke. Stages changes
        /// only — the caller saves. False when the user has no card to take.
        /// </summary>
        /// <param name="actorUserId">The admin whose action caused it, or Guid.Empty for the deadline job.</param>
        Task<bool> RevokeForViolationLimitAsync(User user, Guid actorUserId, CancellationToken ct);
        Task<ActionResult<BulkRevokeRfidResponse>> BulkRevokeRfidAsync(Guid adminUserId, BulkRevokeRfidDto dto, CancellationToken ct);
        Task<ActionResult<BulkArchiveResponse>> BulkArchiveAsync(Guid adminUserId, BulkArchiveDto dto, CancellationToken ct);
        Task<ActionResult<BulkArchiveLastRunResponse?>> GetLastBulkArchiveRunAsync(Guid adminUserId, CancellationToken ct);
        Task<ActionResult<BulkArchiveLastRunResponse?>> UpdateAutoArchiveAsync(Guid adminUserId, Guid runId, BulkArchiveAutoSettingsDto dto, CancellationToken ct);
        Task<ActionResult<BulkArchiveLastRunResponse?>> CancelPendingArchiveAsync(Guid adminUserId, Guid pendingId, CancellationToken ct);

        Task<ActionResult<BulkRestoreResponse>> BulkRestoreAsync(Guid adminUserId, BulkRestoreDto dto, CancellationToken ct);
        Task<ActionResult<BulkRestoreResponse>> UndoBulkArchiveAsync(Guid adminUserId, Guid runId, UndoBulkArchiveDto dto, CancellationToken ct);

        /// <summary>One pass of "archive when clear" over every run that has it on.</summary>
        /// <returns>How many accounts were archived.</returns>
        Task<int> RunAutoArchivePassAsync(DateTime now, CancellationToken ct);
        Task<ActionResult<List<RfidCardResponse>>> ListRfidCardsAsync(string? state, bool includeAssigned, CancellationToken ct);
        Task<ActionResult<List<RfidCardHistoryEntry>>> GetRfidCardHistoryAsync(string tagId, CancellationToken ct);
    }
}
