using AimPark.API.DTOs;
using AimPark.API.Entities;
using Microsoft.AspNetCore.Mvc;

namespace AimPark.API.Interfaces
{
    public interface IGateDeviceService
    {
        Task<ActionResult<CreatedGateDeviceResponse>> CreateAsync(CreateGateDeviceDto dto, CancellationToken ct);

        Task<ActionResult<List<GateDeviceResponse>>> ListAsync(CancellationToken ct);

        Task<ActionResult<object>> RevokeAsync(Guid deviceId, CancellationToken ct);

        /// <summary>
        /// Resolves a presented key to its device, or null if unknown or
        /// revoked. Also stamps LastSeenAt so an admin can tell whether a
        /// reader is still alive.
        /// </summary>
        Task<GateDevice?> AuthenticateAsync(string apiKey, CancellationToken ct);
    }
}
