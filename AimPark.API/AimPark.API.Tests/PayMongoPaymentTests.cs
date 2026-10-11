using System.Security.Cryptography;
using System.Text;
using AimPark.API.Data;
using AimPark.API.DTOs;
using AimPark.API.Entities;
using AimPark.API.Enums;
using AimPark.API.Interfaces;
using AimPark.API.Services;
using AimPark.API.Services.Payments;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging.Abstractions;

namespace AimPark.API.Tests;

/// <summary>
/// What PayMongo sends us is the only thing that moves a bill to Paid, so the
/// reading of it — who signed it, what it says, what happens when it arrives
/// twice — is tested without a PayMongo account existing.
/// </summary>
public class PayMongoPaymentTests
{
    private const string Secret = "whsk_test_secret";
    private const string CheckoutId = "cs_test_123";

    private static PayMongoPaymentGateway Gateway(string? webhookSecret = Secret) => new(
        new HttpClient(),
        new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["Payments:PayMongo:WebhookSecret"] = webhookSecret
            })
            .Build(),
        new HttpContextAccessor(),
        NullLogger<PayMongoPaymentGateway>.Instance);

    /// <summary>The body PayMongo sends when a checkout session is paid.</summary>
    private static string PaidBody(string source = "gcash") => """
        {"data":{"id":"evt_1","type":"event","attributes":{"type":"checkout_session.payment.paid",
        "data":{"id":"@@CHECKOUT@@","type":"checkout_session","attributes":{
        "payments":[{"id":"pay_abc","attributes":{"source":{"type":"@@SOURCE@@"}}}]}}}}}
        """.Replace("@@CHECKOUT@@", CheckoutId).Replace("@@SOURCE@@", source);

    private static string OtherBody() => """
        {"data":{"id":"evt_2","type":"event","attributes":{"type":"payment.failed",
        "data":{"id":"pay_xyz","type":"payment","attributes":{}}}}}
        """;

    /// <summary>PayMongo signs <c>{timestamp}.{body}</c>; <c>te</c> is test mode, <c>li</c> is live.</summary>
    private static Dictionary<string, string> Signed(
        string body, string secret = Secret, string field = "te")
    {
        const string timestamp = "1760000000";
        using var hmac = new HMACSHA256(Encoding.UTF8.GetBytes(secret));
        var hash = Convert.ToHexString(hmac.ComputeHash(Encoding.UTF8.GetBytes($"{timestamp}.{body}")))
            .ToLowerInvariant();

        var header = field == "te"
            ? $"t={timestamp},te={hash},li="
            : $"t={timestamp},te=,li={hash}";

        return new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
        {
            ["Paymongo-Signature"] = header
        };
    }

    // ── Reading the message ──────────────────────────────────────────────────

    [Theory]
    [InlineData("gcash", PaymentMethod.GCash)]
    [InlineData("paymaya", PaymentMethod.Maya)]
    public void A_signed_paid_event_is_read_with_its_checkout_method_and_reference(
        string source, PaymentMethod expected)
    {
        var body = PaidBody(source);

        var ok = Gateway().TryReadEvent(body, Signed(body), out var evt);

        Assert.True(ok);
        Assert.True(evt.Paid);
        Assert.Equal(CheckoutId, evt.ProviderPaymentId);
        Assert.Equal("pay_abc", evt.ReferenceNumber);
        Assert.Equal(expected, evt.Method);
    }

    [Fact]
    public void A_live_mode_signature_is_accepted()
    {
        var body = PaidBody();

        Assert.True(Gateway().TryReadEvent(body, Signed(body, field: "li"), out var evt));
        Assert.True(evt.Paid);
    }

    [Fact]
    public void A_body_changed_after_signing_is_refused()
    {
        var body = PaidBody();
        var headers = Signed(body);

        var tampered = body.Replace(CheckoutId, "cs_test_someone_elses");

        Assert.False(Gateway().TryReadEvent(tampered, headers, out _));
    }

    [Fact]
    public void A_signature_made_with_another_secret_is_refused()
    {
        var body = PaidBody();

        Assert.False(Gateway().TryReadEvent(body, Signed(body, secret: "not-ours"), out _));
    }

    [Fact]
    public void A_message_with_no_signature_is_refused()
    {
        var body = PaidBody();

        Assert.False(Gateway().TryReadEvent(
            body, new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase), out _));
    }

    [Fact]
    public void Nothing_is_accepted_while_the_webhook_secret_is_unset()
    {
        var body = PaidBody();

        Assert.False(Gateway(webhookSecret: null).TryReadEvent(body, Signed(body), out _));
    }

    [Fact]
    public void A_genuine_event_about_something_else_is_understood_but_not_a_payment()
    {
        var body = OtherBody();

        var ok = Gateway().TryReadEvent(body, Signed(body), out var evt);

        // True, not false: false means "refused", which the controller answers
        // with 400 and PayMongo then retries for hours.
        Assert.True(ok);
        Assert.False(evt.Paid);
    }

    [Fact]
    public async Task Checkout_is_offered_for_gcash_and_maya_only()
    {
        var handler = new CapturingHandler();
        var gateway = new PayMongoPaymentGateway(
            new HttpClient(handler),
            new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["Payments:PayMongo:SecretKey"] = "sk_test_x",
                ["Payments:PublicBaseUrl"] = "https://api.example"
            }).Build(),
            new HttpContextAccessor(),
            NullLogger<PayMongoPaymentGateway>.Instance);

        var checkout = await gateway.CreateCheckoutAsync(
            new PaymentTransaction { AmountDue = 25.50m }, "AimPark parking fee");

        Assert.Equal(CheckoutId, checkout.ProviderPaymentId);
        Assert.Contains("\"gcash\"", handler.Body);
        Assert.Contains("\"paymaya\"", handler.Body);
        Assert.DoesNotContain("\"card\"", handler.Body);
        Assert.Contains("\"amount\":2550", handler.Body);
        Assert.Contains("https://api.example/api/payments/return?status=paid", handler.Body);
    }

    // ── Settling the bill ────────────────────────────────────────────────────

    [Fact]
    public async Task A_paid_event_settles_the_bill_with_who_handled_it_and_the_reference()
    {
        var (service, db, payment) = await ServiceWithProcessingBillAsync();
        var body = PaidBody("paymaya");

        var handled = await service.HandleGatewayCallbackAsync(body, Signed(body), default);

        Assert.True(handled);
        var row = await db.Set<PaymentTransaction>().SingleAsync();
        Assert.Equal(PaymentStatus.Paid, row.Status);
        Assert.Equal(PaymentMethod.Maya, row.Method);
        Assert.Equal("pay_abc", row.ReferenceNumber);
        Assert.Equal("PayMongo", row.Provider);
        Assert.NotNull(row.PaidAt);
        Assert.Equal(payment.Id, row.Id);
    }

    [Fact]
    public async Task The_same_event_delivered_twice_settles_once()
    {
        var (service, db, _) = await ServiceWithProcessingBillAsync();
        var body = PaidBody();

        await service.HandleGatewayCallbackAsync(body, Signed(body), default);
        var firstPaidAt = (await db.Set<PaymentTransaction>().SingleAsync()).PaidAt;

        var second = await service.HandleGatewayCallbackAsync(body, Signed(body), default);

        Assert.True(second);
        Assert.Equal(firstPaidAt, (await db.Set<PaymentTransaction>().SingleAsync()).PaidAt);
        Assert.Equal(1, Notifications(service).Count);
    }

    [Fact]
    public async Task An_unrelated_event_is_acknowledged_and_changes_nothing()
    {
        var (service, db, _) = await ServiceWithProcessingBillAsync();
        var body = OtherBody();

        var handled = await service.HandleGatewayCallbackAsync(body, Signed(body), default);

        Assert.True(handled);
        Assert.Equal(PaymentStatus.Processing, (await db.Set<PaymentTransaction>().SingleAsync()).Status);
    }

    [Fact]
    public async Task A_forged_event_is_refused_and_the_bill_stays_unpaid()
    {
        var (service, db, _) = await ServiceWithProcessingBillAsync();
        var body = PaidBody();

        var handled = await service.HandleGatewayCallbackAsync(
            body, Signed(body, secret: "attacker"), default);

        Assert.False(handled);
        Assert.Equal(PaymentStatus.Processing, (await db.Set<PaymentTransaction>().SingleAsync()).Status);
    }

    [Fact]
    public async Task A_payment_for_a_checkout_we_have_no_record_of_is_acknowledged_not_retried()
    {
        var (service, db, _) = await ServiceWithProcessingBillAsync(providerPaymentId: "cs_other");
        var body = PaidBody();

        var handled = await service.HandleGatewayCallbackAsync(body, Signed(body), default);

        Assert.True(handled);
        Assert.Equal(PaymentStatus.Processing, (await db.Set<PaymentTransaction>().SingleAsync()).Status);
    }

    // ── Plumbing ─────────────────────────────────────────────────────────────

    private static readonly Dictionary<PaymentService, RecordingNotifications> Recorders = new();

    private static RecordingNotifications Notifications(PaymentService service) => Recorders[service];

    private static async Task<(PaymentService Service, AppDbContext Db, PaymentTransaction Payment)>
        ServiceWithProcessingBillAsync(string providerPaymentId = CheckoutId)
    {
        var db = new AppDbContext(new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options);

        var payment = new PaymentTransaction
        {
            Source = PaymentSource.ParkingFee,
            UserId = Guid.NewGuid(),
            AmountDue = 30m,
            Status = PaymentStatus.Processing,
            Provider = PayMongoPaymentGateway.ProviderName,
            ProviderPaymentId = providerPaymentId,
            CheckoutStartedAt = DateTime.UtcNow
        };
        db.Add(payment);
        await db.SaveChangesAsync();

        var notifications = new RecordingNotifications();
        var service = new PaymentService(
            new Repository<PaymentTransaction>(db),
            new Repository<ParkingRate>(db),
            notifications,
            db,
            Gateway(),
            NullLogger<PaymentService>.Instance);

        Recorders[service] = notifications;
        return (service, db, payment);
    }

    private sealed class CapturingHandler : HttpMessageHandler
    {
        public string Body { get; private set; } = string.Empty;

        protected override async Task<HttpResponseMessage> SendAsync(
            HttpRequestMessage request, CancellationToken cancellationToken)
        {
            Body = await request.Content!.ReadAsStringAsync(cancellationToken);
            return new HttpResponseMessage(System.Net.HttpStatusCode.OK)
            {
                Content = new StringContent(
                    """{"data":{"id":"@@CHECKOUT@@","attributes":{"checkout_url":"https://pm.example/pay"}}}""".Replace("@@CHECKOUT@@", CheckoutId))
            };
        }
    }

    /// <summary>Counts what a settlement tells the payer; everything else is not under test.</summary>
    private sealed class RecordingNotifications : INotificationService
    {
        public int Count { get; private set; }

        public Task NotifyUserAsync(Guid userId, NotificationType type, string title, string message,
            IDictionary<string, string>? data, CancellationToken ct)
        {
            Count++;
            return Task.CompletedTask;
        }

        public Task<ActionResult<object>> BroadcastAsync(BroadcastNotificationDto dto, Guid adminUserId, CancellationToken ct) => throw new NotImplementedException();
        public Task NotifyRoleAsync(UserRole role, NotificationType type, string title, string message, CancellationToken ct) => throw new NotImplementedException();
        public Task<ActionResult<NotificationListResponse>> ListAllAsync(int page, int pageSize, CancellationToken ct) => throw new NotImplementedException();
        public Task<ActionResult<NotificationListResponse>> ListForUserAsync(Guid userId, UserRole role, int page, int pageSize, CancellationToken ct) => throw new NotImplementedException();
        public Task<ActionResult<object>> MarkReadAsync(Guid userId, Guid notificationId, CancellationToken ct) => throw new NotImplementedException();
    }
}
