using AimPark.API.Auth;
using AimPark.API.DTOs;
using AimPark.API.Interfaces;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;

namespace AimPark.API.Controllers
{
    [ApiController]
    [Route("api/admin/parking")]
    public class AdminParkingController : ControllerBase
    {
        private readonly IParkingSlotService _parkingSlotService;
        private readonly IParkingHistoryService _parkingHistoryService;

        public AdminParkingController(IParkingSlotService parkingSlotService, IParkingHistoryService parkingHistoryService)
        {
            _parkingSlotService = parkingSlotService;
            _parkingHistoryService = parkingHistoryService;
        }

        // "Current Occupancy" is a Security module. Reading the bays is what
        // the gate screen and the guard's overview are built on; creating and
        // editing them below stays Admin.
        [Authorize(Roles = "Admin,Security")]
        [HttpGet("slots")]
        public Task<ActionResult<ParkingAvailabilityResponse>> ListSlots(CancellationToken ct)
            => _parkingSlotService.ListAllAsync(ct);

        [Authorize(Roles = "Admin")]
        [HttpPost("slots")]
        public Task<ActionResult<object>> CreateSlot([FromBody] UpsertParkingSlotDto dto, CancellationToken ct)
            => _parkingSlotService.CreateAsync(dto, ct);

        [Authorize(Roles = "Admin")]
        [HttpPut("slots/{slotId:guid}/status")]
        public Task<ActionResult<object>> UpdateSlotStatus(Guid slotId, [FromBody] UpdateSlotStatusDto dto, CancellationToken ct)
            => _parkingSlotService.UpdateStatusAsync(slotId, dto, ct);

        /// <summary>
        /// Vehicles currently inside (entry logged, no exit yet). Backs the "Log Exit"
        /// picker so an operator never has to look up a raw log ID.
        /// </summary>
        [Authorize(Roles = "Admin,Security")]
        [HttpGet("active-sessions")]
        public Task<ActionResult<List<ActiveParkingSessionResponse>>> ListActiveSessions(CancellationToken ct)
            => _parkingHistoryService.ListActiveSessionsAsync(ct);

        // The RFID gate posts here with a device key; Admin and Security can do
        // the same by hand from the panel, which is how it is driven until the
        // hardware exists.
        [Authorize(
            AuthenticationSchemes = $"{JwtBearerDefaults.AuthenticationScheme},{ApiKeyDefaults.AuthenticationScheme}",
            Roles = "Admin,Security," + ApiKeyDefaults.DeviceRole)]
        [HttpPost("log-entry")]
        public Task<ActionResult<object>> LogEntry([FromBody] LogParkingEntryDto dto, CancellationToken ct)
        {
            if (RejectIfEnrollmentDevice() is { } refusal)
                return Task.FromResult<ActionResult<object>>(refusal);

            // A reader is bolted to one barrier, so its own identity decides the
            // gate. Anything the request body claims is ignored — otherwise a
            // leaked key could log entries against the wrong gate.
            if (GetDeviceGate() is int deviceGate)
                dto.Gate = deviceGate;

            return _parkingHistoryService.LogEntryAsync(dto, GetUserId(), GetDeviceId(), ct);
        }

        [Authorize(
            AuthenticationSchemes = $"{JwtBearerDefaults.AuthenticationScheme},{ApiKeyDefaults.AuthenticationScheme}",
            Roles = "Admin,Security," + ApiKeyDefaults.DeviceRole)]
        [HttpPost("log-exit")]
        public Task<ActionResult<object>> LogExit([FromBody] LogParkingExitDto dto, CancellationToken ct)
        {
            if (RejectIfEnrollmentDevice() is { } refusal)
                return Task.FromResult<ActionResult<object>>(refusal);

            return _parkingHistoryService.LogExitAsync(dto, GetUserId(), GetDeviceId(), ct);
        }

        /// <summary>
        /// The reader on the admin's desk has a device key like any other, but
        /// it is not on a barrier and must not be able to move a vehicle
        /// through one. Returns null when the caller is allowed through.
        /// </summary>
        private ObjectResult? RejectIfEnrollmentDevice()
            => IsDevice && GetDeviceGate() == ApiKeyDefaults.EnrollmentGate
                ? new ObjectResult(new
                {
                    result = "DEVICE_NOT_AT_GATE",
                    message = "This reader is registered to the enrollment desk, not a gate."
                })
                { StatusCode = StatusCodes.Status403Forbidden }
                : null;

        private bool IsDevice => User.IsInRole(ApiKeyDefaults.DeviceRole);

        private Guid? GetUserId()
            => IsDevice ? null : Guid.Parse(User.FindFirst(ClaimTypes.NameIdentifier)!.Value);

        private Guid? GetDeviceId()
            => IsDevice ? Guid.Parse(User.FindFirst(ClaimTypes.NameIdentifier)!.Value) : null;

        private int? GetDeviceGate()
            => int.TryParse(User.FindFirst(ApiKeyDefaults.GateClaim)?.Value, out var gate) ? gate : null;
    }
}
