using AimPark.API.DTOs;
using AimPark.API.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;

namespace AimPark.API.Controllers
{
    [ApiController]
    [Route("api/payments")]
    [Authorize]
    public class PaymentsController : ControllerBase
    {
        private readonly IPaymentService _paymentService;

        public PaymentsController(IPaymentService paymentService)
        {
            _paymentService = paymentService;
        }

        [HttpGet]
        public Task<ActionResult<PaymentListResponse>> List(
            [FromQuery] int page = 1,
            [FromQuery] int pageSize = 20,
            CancellationToken ct = default)
            => _paymentService.GetMyPaymentsAsync(GetUserId(), page, pageSize, ct);

        [HttpGet("{paymentId:guid}")]
        public Task<ActionResult<PaymentResponse>> GetDetail(Guid paymentId, CancellationToken ct)
            => _paymentService.GetMyPaymentDetailAsync(GetUserId(), paymentId, ct);

        [HttpPost("{paymentId:guid}/pay")]
        public Task<ActionResult<object>> Pay(Guid paymentId, CancellationToken ct)
            => _paymentService.PayAsync(GetUserId(), paymentId, ct);

        private Guid GetUserId()
            => Guid.Parse(User.FindFirst(ClaimTypes.NameIdentifier)!.Value);
    }
}
