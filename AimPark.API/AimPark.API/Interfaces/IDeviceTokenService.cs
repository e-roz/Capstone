using AimPark.API.DTOs;
using Microsoft.AspNetCore.Mvc;

namespace AimPark.API.Interfaces
{
    public interface IDeviceTokenService
    {
        Task<ActionResult<object>> RegisterAsync(Guid userId, RegisterDeviceTokenDto dto, CancellationToken ct);
        Task<ActionResult<object>> UnregisterAsync(Guid userId, RegisterDeviceTokenDto dto, CancellationToken ct);
    }
}
