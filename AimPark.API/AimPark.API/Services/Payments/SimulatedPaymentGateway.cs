using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using AimPark.API.Entities;
using AimPark.API.Enums;
using AimPark.API.Interfaces;

namespace AimPark.API.Services.Payments
{
    /// <summary>
    /// Stands in for a payment provider until the school has a merchant account.
    /// </summary>
    /// <remarks>
    /// A merchant account needs business registration, which a project cannot
    /// open for an institution it does not run. The choice is therefore not
    /// between a real gateway and this one; it is between this one and a Pay
    /// button that sets a column to "Paid" — which is what the app did before,
    /// and which teaches the system nothing about the states a real payment
    /// passes through.
    ///
    /// So this imitates the shape rather than skipping it. It issues a checkout
    /// the payer is sent away to, and the settlement comes back as a signed
    /// callback the same way a provider's would. Every state, every guard and
    /// every screen around it is the code that will run against real money.
    /// The one honest difference: the money is imaginary, and this class is what
    /// imagines it.
    /// </remarks>
    public class SimulatedPaymentGateway : IPaymentGateway
    {
        public const string ProviderName = "Simulated";

        private readonly IConfiguration _config;
        private readonly IHttpContextAccessor _http;

        public SimulatedPaymentGateway(IConfiguration config, IHttpContextAccessor http)
        {
            _config = config;
            _http = http;
        }

        public string Name => ProviderName;

        public Task<GatewayCheckout> CreateCheckoutAsync(
            PaymentTransaction payment,
            string description,
            CancellationToken ct = default)
        {
            // Prefixed the way providers do, so a glance at a row says which
            // world it came from long after the switch to a real account.
            var id = $"sim_{Guid.NewGuid():N}";

            var baseUrl = PublicBaseUrl().TrimEnd('/');
            var url = $"{baseUrl}/api/payments/simulated/{id}";

            return Task.FromResult(new GatewayCheckout(id, url));
        }

        public bool TryReadEvent(
            string rawBody,
            IDictionary<string, string> headers,
            out GatewayEvent gatewayEvent)
        {
            gatewayEvent = null!;

            if (!headers.TryGetValue(SignatureHeader, out var signature)) return false;
            if (!IsSignatureValid(rawBody, signature)) return false;

            using var document = JsonDocument.Parse(rawBody);
            var root = document.RootElement;

            if (!root.TryGetProperty("checkoutId", out var idElement)) return false;
            var checkoutId = idElement.GetString();
            if (string.IsNullOrWhiteSpace(checkoutId)) return false;

            var paid = root.TryGetProperty("paid", out var paidElement) && paidElement.GetBoolean();

            var method = root.TryGetProperty("method", out var methodElement)
                && Enum.TryParse<PaymentMethod>(methodElement.GetString(), true, out var parsed)
                    ? parsed
                    : PaymentMethod.GCash;

            var reference = root.TryGetProperty("reference", out var referenceElement)
                ? referenceElement.GetString()
                : null;

            gatewayEvent = new GatewayEvent(checkoutId, paid, reference, method);
            return true;
        }

        // ── Used by the stand-in checkout page ───────────────────────────────

        /// <summary>The header the callback carries its signature in.</summary>
        public const string SignatureHeader = "AimPark-Signature";

        /// <summary>
        /// Builds the callback a provider would have sent, signature and all.
        /// </summary>
        /// <remarks>
        /// Signed with a secret even though both ends are this application. The
        /// point is not to keep a secret from anyone — it is that the receiving
        /// code must never have a path that accepts an unverified message, or
        /// the day a real provider is connected the verification will be the one
        /// thing that has never run.
        /// </remarks>
        public (string Body, string Signature) BuildCallback(
            string checkoutId,
            bool paid,
            PaymentMethod method)
        {
            var body = JsonSerializer.Serialize(new
            {
                checkoutId,
                paid,
                method = method.ToString(),
                // What a payer would be able to quote back. Shaped like a GCash
                // reference: thirteen digits, no letters.
                reference = paid ? RandomNumberGenerator.GetInt32(1_000_000, 9_999_999).ToString("D7") + DateTime.UtcNow.ToString("MMddss") : null
            });

            return (body, Sign(body));
        }

        private bool IsSignatureValid(string rawBody, string provided)
        {
            var expected = Sign(rawBody);

            // Constant-time: a comparison that returns early leaks how much of a
            // guess was right, one character at a time.
            return CryptographicOperations.FixedTimeEquals(
                Encoding.UTF8.GetBytes(expected),
                Encoding.UTF8.GetBytes(provided));
        }

        private string Sign(string body)
        {
            var secret = _config["Payments:Simulated:WebhookSecret"]
                ?? _config["Jwt:Key"]
                ?? "aimpark-simulated-gateway";

            using var hmac = new HMACSHA256(Encoding.UTF8.GetBytes(secret));
            var hash = hmac.ComputeHash(Encoding.UTF8.GetBytes(body));
            return Convert.ToHexString(hash).ToLowerInvariant();
        }

        /// <summary>
        /// Where this API can be reached from a phone's browser.
        /// </summary>
        /// <remarks>
        /// Configuration first, because a deployment behind a proxy knows its
        /// own public name and the request may not. Where it is not set, the
        /// address the phone just called this API on is the right answer and
        /// the only one that needs no setting up — a laptop on the same
        /// network is reached at its LAN address, and that is exactly what the
        /// app was configured with to get here.
        /// </remarks>
        private string PublicBaseUrl()
        {
            var configured = _config["Payments:PublicBaseUrl"];
            if (!string.IsNullOrWhiteSpace(configured)) return configured;

            var request = _http.HttpContext?.Request;
            if (request is not null) return $"{request.Scheme}://{request.Host}";

            return "http://localhost:5000";
        }
    }
}
