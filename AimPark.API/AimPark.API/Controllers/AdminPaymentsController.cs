using AimPark.API.DTOs;
using AimPark.API.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AimPark.API.Controllers
{
    [ApiController]
    [Route("api/admin/payments")]
    [Authorize(Roles = "Admin")]
    public class AdminPaymentsController : ControllerBase
    {
        private readonly IPaymentService _paymentService;

        public AdminPaymentsController(IPaymentService paymentService)
        {
            _paymentService = paymentService;
        }

        [HttpGet]
        public Task<ActionResult<PaymentListResponse>> List(
            [FromQuery] string? status = null,
            [FromQuery] int page = 1,
            [FromQuery] int pageSize = 20,
            CancellationToken ct = default)
            => _paymentService.ListAllAsync(status, page, pageSize, ct);

        [HttpGet("rates")]
        public Task<ActionResult<List<ParkingRateResponse>>> ListRates(CancellationToken ct)
            => _paymentService.ListRatesAsync(ct);

        [HttpPut("rates")]
        public Task<ActionResult<object>> UpsertRate([FromBody] UpsertParkingRateDto dto, CancellationToken ct)
            => _paymentService.UpsertRateAsync(dto, ct);
    }
}
