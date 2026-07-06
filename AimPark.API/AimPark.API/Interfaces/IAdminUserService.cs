using AimPark.API.DTOs;
using AimPark.API.Enums;
using Microsoft.AspNetCore.Mvc;

namespace AimPark.API.Interfaces
{
    public interface IAdminUserService
    {
        Task<ActionResult<UserListResponse>> ListAsync(int page, int pageSize, AccountStatus? status, CancellationToken ct);
        Task<ActionResult<object>> SuspendAsync(Guid userId, Guid adminUserId, SuspendUserDto dto, CancellationToken ct);
        Task<ActionResult<object>> UnsuspendAsync(Guid userId, Guid adminUserId, CancellationToken ct);
        Task<ActionResult<object>> DeleteAsync(Guid userId, Guid adminUserId, CancellationToken ct);
        Task<ActionResult<object>> RestoreAsync(Guid userId, Guid adminUserId, CancellationToken ct);
    }
}
