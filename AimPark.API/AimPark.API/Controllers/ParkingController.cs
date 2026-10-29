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
        private readonly ISlotConfirmationService _slotConfirmation;

        public ParkingController(
            IParkingSlotService parkingSlotService,
            IParkingHistoryService parkingHistoryService,
            IParkingAllocationService allocationService,
            ISlotConfirmationService slotConfirmation)
        {
            _parkingSlotService = parkingSlotService;
            _parkingHistoryService = parkingHistoryService;
            _allocationService = allocationService;
            _slotConfirmation = slotConfirmation;
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
            [FromQuery] Guid? vehicleId = null,
            CancellationToken ct = default)
            => _parkingHistoryService.GetMyHistoryAsync(GetUserId(), vehicleId, page, pageSize, ct);

        /// <summary>
        /// The driver says which bay they parked in. A refusal is a 400 with the
        /// outcome code in <c>result</c> and a sentence in <c>message</c>.
        /// </summary>
        [HttpPost("confirm-slot")]
        public async Task<IActionResult> ConfirmSlot(
            [FromBody] ConfirmSlotRequest request, CancellationToken ct)
        {
            var outcome = await _slotConfirmation.ConfirmAsync(GetUserId(), request, ct);
            return outcome.Result == SlotConfirmResult.Confirmed
                ? Ok(outcome)
                : BadRequest(new { result = outcome.Result, message = outcome.Message });
        }

        /// <summary>
        /// The driver wants to pay while still parked. Returns the bill to pay,
        /// priced up to now; once it is paid the exit opens on a tap for a short
        /// while.
        /// </summary>
        [HttpPost("sessions/{logId:guid}/pay-ahead")]
        public Task<ActionResult<PayAheadResponse>> PayAhead(Guid logId, CancellationToken ct)
            => _parkingHistoryService.PayAheadAsync(GetUserId(), logId, ct);

        private Guid GetUserId()
            => Guid.Parse(User.FindFirst(ClaimTypes.NameIdentifier)!.Value);
    }
}
