using AimPark.API.Data;
using AimPark.API.Entities;
using AimPark.API.Enums;
using AimPark.API.Interfaces;
using AimPark.API.Services.Payments;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace AimPark.API.Controllers
{
    /// <summary>
    /// The checkout page a provider would host, while there is no provider.
    /// </summary>
    /// <remarks>
    /// Deliberately a web page rather than a screen inside the app. The part of
    /// paying that is easy to get wrong is not the button — it is everything
    /// around leaving the app and coming back: the bill sitting in Processing
    /// while nobody is looking at it, the settlement arriving from somewhere
    /// other than the payer's phone, the app having to ask again what happened.
    /// A screen inside Flutter would skip all of that and prove nothing.
    ///
    /// Switched off entirely when a real provider is configured, so a deployment
    /// with live keys cannot serve a page that settles bills for free.
    /// </remarks>
    [ApiController]
    [Route("api/payments/simulated")]
    [AllowAnonymous]
    public class SimulatedCheckoutController : ControllerBase
    {
        private readonly AppDbContext _db;
        private readonly IPaymentService _payments;
        private readonly SimulatedPaymentGateway _gateway;
        private readonly IConfiguration _config;

        public SimulatedCheckoutController(
            AppDbContext db,
            IPaymentService payments,
            SimulatedPaymentGateway gateway,
            IConfiguration config)
        {
            _db = db;
            _payments = payments;
            _gateway = gateway;
            _config = config;
        }

        private bool IsEnabled =>
            string.Equals(
                _config["Payments:Provider"] ?? SimulatedPaymentGateway.ProviderName,
                SimulatedPaymentGateway.ProviderName,
                StringComparison.OrdinalIgnoreCase);

        [HttpGet("{checkoutId}")]
        public async Task<IActionResult> Page(string checkoutId, CancellationToken ct)
        {
            if (!IsEnabled) return NotFound();

            var payment = await _db.Set<PaymentTransaction>()
                .AsNoTracking()
                .FirstOrDefaultAsync(p => p.ProviderPaymentId == checkoutId, ct);

            if (payment is null) return NotFound();

            if (payment.Status == PaymentStatus.Paid)
            {
                return Redirect("/api/payments/return?status=paid");
            }

            var what = payment.Source == PaymentSource.ParkingFee
                ? "AimPark parking fee"
                : "AimPark violation penalty";

            return Content(CheckoutPage(checkoutId, what, payment.AmountDue), "text/html");
        }

        /// <summary>
        /// What a payer tapping "Pay" at the provider would cause: a signed
        /// settlement sent back to this application.
        /// </summary>
        [HttpPost("{checkoutId}/confirm")]
        public async Task<IActionResult> Confirm(
            string checkoutId,
            [FromForm] string? method,
            CancellationToken ct)
        {
            if (!IsEnabled) return NotFound();

            var chosen = Enum.TryParse<PaymentMethod>(method, true, out var parsed)
                ? parsed
                : PaymentMethod.GCash;

            var (body, signature) = _gateway.BuildCallback(checkoutId, paid: true, method: chosen);

            // Straight into the same method the real callback endpoint calls,
            // with the same signed body it would receive. Not over HTTP: a
            // request to itself would need this deployment to know its own
            // reachable address, and would buy nothing — the code being
            // exercised is identical either way.
            var headers = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
            {
                [SimulatedPaymentGateway.SignatureHeader] = signature
            };

            await _payments.HandleGatewayCallbackAsync(body, headers, ct);

            return Redirect("/api/payments/return?status=paid");
        }

        [HttpPost("{checkoutId}/cancel")]
        public IActionResult Cancel(string checkoutId)
        {
            if (!IsEnabled) return NotFound();

            // The bill stays as it is. Nothing was charged, and the app is free
            // to open a fresh checkout on it whenever the payer tries again.
            return Redirect("/api/payments/return?status=cancelled");
        }

        private static string CheckoutPage(string checkoutId, string what, decimal amount) =>
            "<!doctype html><html><head><meta charset=\"utf-8\">"
            + "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">"
            + "<title>AimPark payment</title><style>"
            + "body{font-family:system-ui,sans-serif;margin:0;display:grid;place-items:center;"
            + "min-height:100vh;background:#f6f7f9;color:#1a1c1e}"
            + ".card{background:#fff;padding:24px;border-radius:16px;width:320px;"
            + "box-shadow:0 1px 3px rgba(0,0,0,.08)}"
            + ".tag{font-size:12px;letter-spacing:.08em;text-transform:uppercase;color:#8a9199}"
            + "h1{font-size:32px;margin:4px 0 2px}.what{color:#5b6169;font-size:14px;margin:0 0 20px}"
            + "button{width:100%;padding:14px;border-radius:10px;border:0;font-size:15px;"
            + "font-weight:600;cursor:pointer;margin-bottom:10px}"
            + ".gcash{background:#0057ff;color:#fff}.maya{background:#0f8f4d;color:#fff}"
            + ".cancel{background:transparent;color:#5b6169;border:1px solid #dfe3e8}"
            + ".note{font-size:12px;color:#8a9199;text-align:center;margin:14px 0 0;line-height:1.5}"
            + "form{margin:0}</style></head><body><div class=\"card\">"
            + "<p class=\"tag\">Amount due</p>"
            + $"<h1>₱{amount:0.00}</h1><p class=\"what\">{what}</p>"
            + $"<form method=\"post\" action=\"/api/payments/simulated/{checkoutId}/confirm\">"
            + "<button class=\"gcash\" name=\"method\" value=\"GCash\">Pay with GCash</button>"
            + "<button class=\"maya\" name=\"method\" value=\"Maya\">Pay with Maya</button></form>"
            + $"<form method=\"post\" action=\"/api/payments/simulated/{checkoutId}/cancel\">"
            + "<button class=\"cancel\">Cancel</button></form>"
            + "<p class=\"note\">Test payment. No money moves. This page stands in for the "
            + "payment provider until AimPark has a merchant account.</p>"
            + "</div></body></html>";
    }
}
