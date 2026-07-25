using AimPark.API.DTOs;
using Microsoft.AspNetCore.Mvc;

namespace AimPark.API.Interfaces
{
    public interface IUserProfileService
    {
        Task<ActionResult<MyProfileResponse>> GetMyProfileAsync(Guid userId, CancellationToken ct);
        Task<ActionResult<object>> UpdateProfileAsync(Guid userId, UpdateProfileDto dto, CancellationToken ct);
        Task<ActionResult<object>> ChangePasswordAsync(Guid userId, ChangePasswordDto dto, CancellationToken ct);
        Task<ActionResult<AccessStatusResponse>> GetAccessStatusAsync(Guid userId, CancellationToken ct);
    }
}
