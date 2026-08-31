using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using AimPark.API.Entities;
using AimPark.API.Enums;
using AimPark.API.Interfaces;

namespace AimPark.API.Services.Payments
{
    /// <summary>
    /// PayMongo, through its Checkout Sessions API.
    /// </summary>
    /// <remarks>
    /// Written against the API but not yet run against a real account: live keys
    /// need a verified merchant, which needs the school's business registration.
    /// It is here rather than waiting because "ready for a real provider" is
    /// only a claim until the implementation exists — with this file present,
    /// switching over is a key and a configuration value, and the rest of the
    /// system cannot tell the difference.
    ///
    /// Checkout Sessions rather than Payment Intents: the session hands back a
    /// hosted page that already handles GCash, Maya and cards, which is the
    /// whole of what this application needs. Intents would mean building that
    /// page, and building a payment form is how a project ends up handling card
    /// numbers it has no business touching.
    ///
    /// Amounts go in centavos. PayMongo will refuse anything under ₱20, which is
    /// why <see cref="ParkingRate.MinimumFee"/> exists.
    /// </remarks>
    public class PayMongoPaymentGateway : IPaymentGateway
    {
        public const string ProviderName = "PayMongo";

        private const string CheckoutSessionsUrl = "https://api.paymongo.com/v1/checkout_sessions";

        private readonly HttpClient _httpClient;
        private readonly IConfiguration _config;
        private readonly IHttpContextAccessor _http;
        private readonly ILogger<PayMongoPaymentGateway> _logger;

        public PayMongoPaymentGateway(
            HttpClient httpClient,
            IConfiguration config,
            IHttpContextAccessor http,
            ILogger<PayMongoPaymentGateway> logger)
        {
            _httpClient = httpClient;
            _config = config;
            _http = http;
            _logger = logger;
        }

        public string Name => ProviderName;

        public async Task<GatewayCheckout> CreateCheckoutAsync(
            PaymentTransaction payment,
            string description,
            CancellationToken ct = default)
        {
            var secretKey = _config["Payments:PayMongo:SecretKey"]
                ?? throw new InvalidOperationException(
                    "Payments:PayMongo:SecretKey is not configured.");

            var baseUrl = PublicBaseUrl().TrimEnd('/');

            var body = new
            {
                data = new
                {
                    attributes = new
                    {
                        line_items = new[]
                        {
                            new
                            {
                                currency = "PHP",
                                amount = ToCentavos(payment.AmountDue),
                                name = description,
                                quantity = 1
                            }
                        },
                        payment_method_types = new[] { "gcash", "paymaya", "card" },
                        description,
                        // Ours, not theirs: it comes back on the callback and is
                        // the second way to find the row if an id ever gets lost.
                        reference_number = payment.Id.ToString(),
                        success_url = $"{baseUrl}/api/payments/return?status=paid",
                        cancel_url = $"{baseUrl}/api/payments/return?status=cancelled"
                    }
                }
            };

            using var request = new HttpRequestMessage(HttpMethod.Post, CheckoutSessionsUrl)
            {
                Content = JsonContent.Create(body)
            };

            // Basic auth with the secret key as the username and no password.
            request.Headers.Authorization = new AuthenticationHeaderValue(
                "Basic",
                Convert.ToBase64String(Encoding.UTF8.GetBytes($"{secretKey}:")));

            var response = await _httpClient.SendAsync(request, ct);
            var payload = await response.Content.ReadAsStringAsync(ct);

            if (!response.IsSuccessStatusCode)
            {
                throw new InvalidOperationException(
                    $"PayMongo refused the checkout: {response.StatusCode} {payload}");
            }

            using var document = JsonDocument.Parse(payload);
            var data = document.RootElement.GetProperty("data");
            var id = data.GetProperty("id").GetString()!;
            var url = data.GetProperty("attributes").GetProperty("checkout_url").GetString()!;

            return new GatewayCheckout(id, url);
        }

        public bool TryReadEvent(
            string rawBody,
            IDictionary<string, string> headers,
            out GatewayEvent gatewayEvent)
        {
            gatewayEvent = null!;

            if (!headers.TryGetValue("Paymongo-Signature", out var signature))
            {
                return false;
            }

            if (!IsSignatureValid(rawBody, signature))
            {
                // Worth a line in the log: a wrong signature is either a
                // misconfigured secret or somebody trying to settle a bill they
                // did not pay, and the two look identical from here.
                _logger.LogWarning("Rejected a PayMongo callback with an invalid signature.");
                return false;
            }

            using var document = JsonDocument.Parse(rawBody);
            var attributes = document.RootElement.GetProperty("data").GetProperty("attributes");

            var type = attributes.GetProperty("type").GetString();

            // The only event that means money arrived. The rest — sessions
            // opened, payments failed, refunds — are not what this settles on.
            if (type != "checkout_session.payment.paid") return false;

            var session = attributes.GetProperty("data");
            var checkoutId = session.GetProperty("id").GetString();
            if (string.IsNullOrWhiteSpace(checkoutId)) return false;

            string? reference = null;
            PaymentMethod? method = null;

            if (session.TryGetProperty("attributes", out var sessionAttributes)
                && sessionAttributes.TryGetProperty("payments", out var payments)
                && payments.ValueKind == JsonValueKind.Array
                && payments.GetArrayLength() > 0)
            {
                var first = payments[0];
                reference = first.TryGetProperty("id", out var paymentId) ? paymentId.GetString() : null;

                if (first.TryGetProperty("attributes", out var paymentAttributes)
                    && paymentAttributes.TryGetProperty("source", out var source)
                    && source.TryGetProperty("type", out var sourceType))
                {
                    method = MapMethod(sourceType.GetString());
                }
            }

            gatewayEvent = new GatewayEvent(checkoutId, true, reference, method);
            return true;
        }

        /// <summary>
        /// PayMongo signs <c>{timestamp}.{body}</c> and sends the result as
        /// <c>t=…,te=…,li=…</c> — <c>te</c> in test mode, <c>li</c> in live.
        /// </summary>
        private bool IsSignatureValid(string rawBody, string header)
        {
            var secret = _config["Payments:PayMongo:WebhookSecret"];
            if (string.IsNullOrWhiteSpace(secret)) return false;

            string? timestamp = null;
            string? test = null;
            string? live = null;

            foreach (var part in header.Split(',', StringSplitOptions.RemoveEmptyEntries))
            {
                var pieces = part.Split('=', 2);
                if (pieces.Length != 2) continue;

                switch (pieces[0].Trim())
                {
                    case "t": timestamp = pieces[1].Trim(); break;
                    case "te": test = pieces[1].Trim(); break;
                    case "li": live = pieces[1].Trim(); break;
                }
            }

            if (timestamp is null) return false;

            var provided = live ?? test;
            if (string.IsNullOrWhiteSpace(provided)) return false;

            using var hmac = new HMACSHA256(Encoding.UTF8.GetBytes(secret));
            var hash = hmac.ComputeHash(Encoding.UTF8.GetBytes($"{timestamp}.{rawBody}"));
            var expected = Convert.ToHexString(hash).ToLowerInvariant();

            return CryptographicOperations.FixedTimeEquals(
                Encoding.UTF8.GetBytes(expected),
                Encoding.UTF8.GetBytes(provided));
        }

        /// <summary>Where the payer's browser is sent back to afterwards.</summary>
        private string PublicBaseUrl()
        {
            var configured = _config["Payments:PublicBaseUrl"];
            if (!string.IsNullOrWhiteSpace(configured)) return configured;

            var request = _http.HttpContext?.Request;
            return request is null ? string.Empty : $"{request.Scheme}://{request.Host}";
        }

        private static PaymentMethod? MapMethod(string? source) => source?.ToLowerInvariant() switch
        {
            "gcash" => PaymentMethod.GCash,
            "paymaya" or "maya" => PaymentMethod.Maya,
            "card" => PaymentMethod.Card,
            _ => null
        };

        private static int ToCentavos(decimal amount) =>
            (int)Math.Round(amount * 100m, MidpointRounding.AwayFromZero);
    }
}
