using AimPark.API.DTOs;
using AimPark.API.Enums;
using Microsoft.AspNetCore.Mvc;

namespace AimPark.API.Interfaces
{
    public interface IAdminRegistrationService
    {
        Task<ActionResult<List<PendingRegistrationResponse>>> GetPendingAsync(CancellationToken ct);
        Task<ActionResult<RegistrationDetailResponse>> GetDetailAsync(Guid userId, CancellationToken ct);
        Task<ActionResult<object>> ApproveAsync(Guid userId, Guid adminUserId, CancellationToken ct);
        Task<ActionResult<object>> RejectAsync(Guid userId, Guid adminUserId, RejectRegistrationDto dto, CancellationToken ct);
        Task<ActionResult<object>> ResetReapplyAsync(Guid userId, Guid adminUserId, CancellationToken ct);
        Task<ActionResult<object>> ResetStepAsync(Guid userId, Guid adminUserId, ResetRegistrationStepDto dto, CancellationToken ct);
    }
}
