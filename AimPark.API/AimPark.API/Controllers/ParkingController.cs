using AimPark.API.DTOs;
using AimPark.API.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;

namespace AimPark.API.Controllers
{
    [ApiController]
    [Route("api/parking")]
    [Authorize]
    public class ParkingController : ControllerBase
    {
        private readonly IParkingSlotService _parkingSlotService;
        private readonly IParkingHistoryService _parkingHistoryService;

        public ParkingController(IParkingSlotService parkingSlotService, IParkingHistoryService parkingHistoryService)
        {
            _parkingSlotService = parkingSlotService;
            _parkingHistoryService = parkingHistoryService;
        }

        [HttpGet("slots")]
        public Task<ActionResult<ParkingAvailabilityResponse>> GetSlots(CancellationToken ct)
            => _parkingSlotService.GetAvailabilityAsync(ct);

        [HttpGet("history")]
        public Task<ActionResult<ParkingHistoryResponse>> GetHistory(
            [FromQuery] int page = 1,
            [FromQuery] int pageSize = 20,
            CancellationToken ct = default)
            => _parkingHistoryService.GetMyHistoryAsync(GetUserId(), page, pageSize, ct);

        private Guid GetUserId()
            => Guid.Parse(User.FindFirst(ClaimTypes.NameIdentifier)!.Value);
    }
}
