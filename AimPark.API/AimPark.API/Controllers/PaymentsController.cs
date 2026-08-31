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

        /// <summary>
        /// Opens a checkout for a bill and returns the page to send the payer to.
        /// </summary>
        /// <remarks>
        /// What used to be here was a <c>pay</c> endpoint that marked the bill
        /// settled because the payer’s own phone said so. The money now has to
        /// be confirmed by whoever received it, which arrives on
        /// <see cref="Callback"/>.
        /// </remarks>
        [HttpPost("{paymentId:guid}/checkout")]
        public Task<ActionResult<CheckoutResponse>> Checkout(Guid paymentId, CancellationToken ct)
            => _paymentService.StartCheckoutAsync(GetUserId(), paymentId, ct);

        /// <summary>
        /// Where the payment provider reports that money arrived.
        /// </summary>
        /// <remarks>
        /// Anonymous because the caller is a provider’s server, which holds no
        /// account here. What stands in for authentication is the signature on
        /// the body, checked by the gateway implementation before a single field
        /// is read.
        ///
        /// Answers 200 for anything it understands, including the messages it
        /// decides not to act on — an unknown checkout, an event about
        /// something other than a completed payment. A provider that gets
        /// anything else retries for hours, and no retry improves those. A
        /// signature that does not verify is answered 400, because it is either a
        /// misconfigured secret or somebody trying it on, and neither should look
        /// like success.
        /// </remarks>
        [AllowAnonymous]
        [HttpPost("callback")]
        public async Task<IActionResult> Callback(CancellationToken ct)
        {
            using var reader = new StreamReader(Request.Body, leaveOpen: true);
            var rawBody = await reader.ReadToEndAsync(ct);

            var headers = Request.Headers.ToDictionary(
                header => header.Key,
                header => header.Value.ToString(),
                StringComparer.OrdinalIgnoreCase);

            var handled = await _paymentService.HandleGatewayCallbackAsync(rawBody, headers, ct);

            return handled ? Ok(new { received = true }) : BadRequest(new { received = false });
        }

        /// <summary>
        /// Where the provider’s hosted page sends the payer’s browser afterwards.
        /// </summary>
        /// <remarks>
        /// A plain page and nothing more. The bill is settled by the callback
        /// above, server to server; this is only what the human sees for the
        /// second before they switch back to the app. It must never be the thing
        /// that decides a payment happened — a browser can be pointed at this
        /// URL by anyone.
        /// </remarks>
        [AllowAnonymous]
        [HttpGet("return")]
        public ContentResult Return([FromQuery] string? status)
        {
            var paid = status == "paid";
            var heading = paid ? "Payment received" : "Payment cancelled";
            var line = paid
                ? "You can close this page and go back to AimPark."
                : "Nothing was charged. You can close this page and try again.";

            return Content(
                "<!doctype html><html><head><meta charset=\"utf-8\">"
                + "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">"
                + $"<title>{heading}</title>"
                + "<style>body{font-family:system-ui,sans-serif;margin:0;display:grid;"
                + "place-items:center;min-height:100vh;background:#f6f7f9;color:#1a1c1e}"
                + ".card{background:#fff;padding:32px 24px;border-radius:16px;max-width:320px;"
                + "text-align:center;box-shadow:0 1px 3px rgba(0,0,0,.08)}"
                + "h1{font-size:20px;margin:0 0 8px}p{margin:0;color:#5b6169;font-size:15px;line-height:1.5}"
                + "</style></head><body><div class=\"card\">"
                + $"<h1>{heading}</h1><p>{line}</p>"
                + "</div></body></html>",
                "text/html");
        }

        private Guid GetUserId()
            => Guid.Parse(User.FindFirst(ClaimTypes.NameIdentifier)!.Value);
    }
}
