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
        private readonly IParkingAllocationService _allocationService;

        public ParkingController(
            IParkingSlotService parkingSlotService,
            IParkingHistoryService parkingHistoryService,
            IParkingAllocationService allocationService)
        {
            _parkingSlotService = parkingSlotService;
            _parkingHistoryService = parkingHistoryService;
            _allocationService = allocationService;
        }

        [HttpGet("slots")]
        public Task<ActionResult<ParkingAvailabilityResponse>> GetSlots(CancellationToken ct)
            => _parkingSlotService.GetAvailabilityAsync(ct);

        /// <summary>
        /// Suggests where the caller should park. Advice only — nothing is
        /// held, so the slot can be taken before they arrive. Always 200; the
        /// outcome is in the body's Result field so callers branch on a code
        /// rather than an HTTP status.
        /// </summary>
        [HttpPost("recommend")]
        public Task<SlotRecommendationResponse> Recommend(CancellationToken ct)
            => _allocationService.RecommendAsync(GetUserId(), ct);

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
