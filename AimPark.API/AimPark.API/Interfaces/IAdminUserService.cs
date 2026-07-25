using AimPark.API.DTOs;
using AimPark.API.Enums;
using Microsoft.AspNetCore.Mvc;

namespace AimPark.API.Interfaces
{
    public interface IAdminUserService
    {
        Task<ActionResult<UserListResponse>> ListAsync(int page, int pageSize, string? status, string? search, CancellationToken ct);
        Task<ActionResult<object>> SuspendAsync(Guid userId, Guid adminUserId, SuspendUserDto dto, CancellationToken ct);
        Task<ActionResult<object>> UnsuspendAsync(Guid userId, Guid adminUserId, CancellationToken ct);
        Task<ActionResult<object>> ArchiveAsync(Guid userId, Guid adminUserId, ArchiveUserDto dto, CancellationToken ct);
        Task<ActionResult<object>> RestoreAsync(Guid userId, Guid adminUserId, CancellationToken ct);
        Task<ActionResult<object>> AssignRfidAsync(Guid userId, Guid adminUserId, AssignRfidDto dto, CancellationToken ct);
        Task<ActionResult<object>> RevokeRfidAsync(Guid userId, Guid adminUserId, CancellationToken ct);
    }
}
