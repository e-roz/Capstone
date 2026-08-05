using AimPark.API.DTOs;
using AimPark.API.Interfaces;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AimPark.API.Controllers
{
    /// <summary>
    /// Issues and revokes the keys gate hardware uses to talk to the API.
    /// Admin-only, and deliberately not reachable with a device key — a reader
    /// must never be able to mint more readers.
    /// </summary>
    [ApiController]
    [Route("api/admin/gate-devices")]
    [Authorize(AuthenticationSchemes = JwtBearerDefaults.AuthenticationScheme, Roles = "Admin")]
    public class AdminGateDevicesController : ControllerBase
    {
        private readonly IGateDeviceService _gateDevices;

        public AdminGateDevicesController(IGateDeviceService gateDevices)
        {
            _gateDevices = gateDevices;
        }

        /// <summary>
        /// Registers a device and returns its key. The key is shown once and
        /// never stored in clear — copy it straight into the firmware.
        /// </summary>
        [HttpPost]
        public Task<ActionResult<CreatedGateDeviceResponse>> Create(
            [FromBody] CreateGateDeviceDto dto, CancellationToken ct)
            => _gateDevices.CreateAsync(dto, ct);

        [HttpGet]
        public Task<ActionResult<List<GateDeviceResponse>>> List(CancellationToken ct)
            => _gateDevices.ListAsync(ct);

        /// <summary>
        /// Permanently disables a device's key. Use when hardware is lost,
        /// replaced, or a key has been exposed.
        /// </summary>
        [HttpPost("{deviceId:guid}/revoke")]
        public Task<ActionResult<object>> Revoke(Guid deviceId, CancellationToken ct)
            => _gateDevices.RevokeAsync(deviceId, ct);
    }
}
