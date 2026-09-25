using AimPark.API.DTOs;
using AimPark.API.Entities;
using Microsoft.AspNetCore.Mvc;

namespace AimPark.API.Interfaces
{
    public interface IGateDeviceService
    {
        /// <summary>
        /// Registers a device. <paramref name="callerIsAdmin"/> decides which
        /// kinds the caller may register — see GateDeviceService.WhoMayRegister.
        /// </summary>
        Task<ActionResult<CreatedGateDeviceResponse>> CreateAsync(
            CreateGateDeviceDto dto, bool callerIsAdmin, CancellationToken ct);

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
