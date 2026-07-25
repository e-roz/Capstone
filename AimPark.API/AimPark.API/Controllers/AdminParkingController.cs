using AimPark.API.DTOs;
using AimPark.API.Interfaces;
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

        [Authorize(Roles = "Admin")]
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

        // Manual stand-in for the RFID gate hardware — Admin or Security can log a vehicle entry/exit.
        [Authorize(Roles = "Admin,Security")]
        [HttpPost("log-entry")]
        public Task<ActionResult<object>> LogEntry([FromBody] LogParkingEntryDto dto, CancellationToken ct)
            => _parkingHistoryService.LogEntryAsync(dto, GetUserId(), ct);

        [Authorize(Roles = "Admin,Security")]
        [HttpPost("log-exit")]
        public Task<ActionResult<object>> LogExit([FromBody] LogParkingExitDto dto, CancellationToken ct)
            => _parkingHistoryService.LogExitAsync(dto, GetUserId(), ct);

        private Guid GetUserId()
            => Guid.Parse(User.FindFirst(ClaimTypes.NameIdentifier)!.Value);
    }
}
