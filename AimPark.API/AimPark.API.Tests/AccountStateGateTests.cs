using AimPark.API.Data;
using AimPark.API.DTOs;
using AimPark.API.Entities;
using AimPark.API.Enums;
using AimPark.API.Interfaces;
using AimPark.API.Services;
using AimPark.API.Sync.Site.GateReaders;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Infrastructure;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;

namespace AimPark.API.Tests;

/// <summary>
/// A suspended, archived or unapproved account is refused at the entry gate
/// even though its card is still Active, can always drive out, and never has
/// its violation suspension touched by the account's own status.
/// </summary>
public class AccountStateGateTests
{
    private const string Tag = "04A2B3C4";
    private const string VisitorTag = "04D5E6F7";

    private sealed record Gate(AppDbContext Db, ParkingHistoryService Parking, User User, ParkingSlot Slot, Notices Notices);

    private static async Task<Gate> GateAsync(AccountStatus status = AccountStatus.Active, bool archived = false)
    {
        var db = new AppDbContext(new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options);

        var user = new User
        {
            Id = Guid.NewGuid(), FullName = "Juan", Email = "j@x.test", RfidTagId = Tag,
            RfidStatus = RfidStatus.Active, Role = UserRole.User,
            AccountStatus = status, IsDeleted = archived
        };
        var slot = new ParkingSlot { SlotCode = "A1", Status = ParkingSlotStatus.Available };
        db.AddRange(user, slot, new ParkingRate { VehicleType = null, RatePerHour = 30m });
        await db.SaveChangesAsync();

        var notices = new Notices();
        var payments = new PaymentService(
            new Repository<PaymentTransaction>(db), new Repository<ParkingRate>(db),
            notices, db, new NoGateway(), NullLogger<PaymentService>.Instance);

        var parking = new ParkingHistoryService(
            new Repository<ParkingLog>(db), new Repository<ParkingSlot>(db),
            payments, allocationService: null!, notices, db, new NoSlotSensors());

        return new Gate(db, parking, user, slot, notices);
    }

    private static Task<ActionResult<object>> EnterAsync(Gate g, string tag = Tag) =>
        g.Parking.LogEntryAsync(new LogParkingEntryDto { RfidTagId = tag, SlotId = g.Slot.Id }, null, null, default);

    private static string Field(ActionResult<object> r, string name)
    {
        var value = ((ObjectResult)r.Result!).Value!;
        return value.GetType().GetProperty(name)!.GetValue(value)!.ToString()!;
    }

    private static int Status(IConvertToActionResult r) =>
        r.Convert() is ObjectResult o ? o.StatusCode ?? 200 : 200;

    // ── Refused at entry ───────────────────────────────────────────────────

    [Fact]
    public async Task ARevokedAccountIsRefusedAtEntry()
    {
        var g = await GateAsync(AccountStatus.Revoked);

        var result = await EnterAsync(g);

        Assert.Equal(400, Status(result));
        Assert.Equal("RFID_SUSPENDED", Field(result, "result"));
        Assert.Equal("Account revoked. See a guard.", Field(result, "message"));
        Assert.Empty(g.Db.ParkingLogs);
    }

    [Fact]
    public async Task ARevokedAccountAlreadyInsideCanStillLeave()
    {
        var g = await GateAsync(AccountStatus.Revoked);
        g.Slot.Status = ParkingSlotStatus.Occupied;
        g.Db.Add(new ParkingLog { UserId = g.User.Id, SlotId = g.Slot.Id, EntryTime = DateTime.UtcNow.AddMinutes(-90) });
        await g.Db.SaveChangesAsync();

        var result = await g.Parking.LogExitAsync(new LogParkingExitDto { RfidTagId = Tag }, null, null, default);

        Assert.Equal(200, Status(result));
        Assert.Equal("EXIT_LOGGED", Field(result, "result"));
        Assert.NotNull((await g.Db.ParkingLogs.SingleAsync()).ExitTime);
    }

    [Fact]
    public async Task AnArchivedAccountIsRefusedAtEntry()
    {
        // Archiving leaves AccountStatus at Active; only IsDeleted changes.
        var g = await GateAsync(AccountStatus.Active, archived: true);

        var result = await EnterAsync(g);

        Assert.Equal(400, Status(result));
        Assert.Equal("Account archived. See a guard.", Field(result, "message"));
        Assert.Empty(g.Db.ParkingLogs);
    }

    [Theory]
    [InlineData(AccountStatus.PendingReview)]
    [InlineData(AccountStatus.Rejected)]
    [InlineData(AccountStatus.Revoked)]
    public async Task AnAccountThatIsNotActiveIsRefusedEvenWithAnActiveCard(AccountStatus status)
    {
        var g = await GateAsync(status);

        var result = await EnterAsync(g);

        Assert.Equal(400, Status(result));
        Assert.Equal("RFID_SUSPENDED", Field(result, "result"));
        Assert.Empty(g.Db.ParkingLogs);
    }

    [Fact]
    public async Task AnActiveAccountStillGetsIn()
    {
        var g = await GateAsync();

        var result = await EnterAsync(g);

        Assert.Equal(200, Status(result));
        Assert.Single(g.Db.ParkingLogs);
    }

    // ── The driver is told, without the admin's reason ─────────────────────

    [Fact]
    public async Task AReaderTapTellsTheDriverAndAManualEntryDoesNot()
    {
        var g = await GateAsync(AccountStatus.Revoked);

        await EnterAsync(g);
        Assert.Empty(g.Notices.Sent);

        var outcome = await new GateTapHandler(g.Db, g.Parking).HandleAsync(2, Guid.NewGuid(), Tag, default);

        Assert.False(outcome.Opened);
        Assert.Equal("IN", outcome.Direction);
        var notice = Assert.Single(g.Notices.Sent);
        Assert.Equal("Your card was refused", notice.Title);
        Assert.Equal("Gate 2: your account is revoked. Contact the parking admin.", notice.Message);
    }

    // ── The violation suspension is its own thing ──────────────────────────

    [Fact]
    public async Task AViolationSuspensionStillRefusesAnActiveAccount()
    {
        var g = await GateAsync();
        g.User.RfidStatus = RfidStatus.Suspended;
        g.User.RfidSuspendedFrom = DateTime.UtcNow.AddDays(-1);
        g.User.RfidSuspendedUntil = DateTime.UtcNow.AddDays(3);
        await g.Db.SaveChangesAsync();

        var result = await EnterAsync(g);

        Assert.Equal(400, Status(result));
        Assert.Equal("RFID access is suspended.", Field(result, "message"));
    }

    // ── Visitors ───────────────────────────────────────────────────────────

    [Fact]
    public async Task AVisitorCardStillGetsIn()
    {
        var g = await GateAsync(AccountStatus.Revoked);
        g.Db.VisitorCards.Add(new VisitorCard { RfidTagId = VisitorTag, Label = "V1", State = VisitorCardState.Active });
        await g.Db.SaveChangesAsync();

        var issued = await new VisitorPassService(new Repository<VisitorPass>(g.Db), g.Db).IssueAsync(new IssueVisitorPassDto
        {
            RfidTagId = VisitorTag, VisitorName = "Ana", PlateNumber = "abc 123", VehicleType = "Car"
        }, Guid.NewGuid(), default);
        Assert.Equal(200, Status(issued));

        var result = await EnterAsync(g, VisitorTag);

        Assert.Equal(200, Status(result));
        Assert.NotNull((await g.Db.ParkingLogs.SingleAsync()).VisitorPassId);
    }

    // ── Stubs ──────────────────────────────────────────────────────────────

    private sealed class NoGateway : IPaymentGateway
    {
        public string Name => "None";

        public Task<GatewayCheckout> CreateCheckoutAsync(
            PaymentTransaction payment, string description, CancellationToken ct = default) =>
            throw new NotImplementedException();

        public Task<GatewayCheckout> CreateBundleCheckoutAsync(
            IReadOnlyList<PaymentTransaction> payments, CancellationToken ct = default) =>
            throw new NotImplementedException();

        public bool TryReadEvent(string rawBody, IDictionary<string, string> headers, out GatewayEvent gatewayEvent)
        {
            gatewayEvent = null!;
            return false;
        }
    }

    private sealed class Notices : INotificationService
    {
        public List<(string Title, string Message)> Sent { get; } = [];

        public Task NotifyUserAsync(Guid userId, NotificationType type, string title, string message,
            IDictionary<string, string>? data, CancellationToken ct)
        {
            // The exit's fee notice is not what these tests are about.
            if (title == "Your card was refused") Sent.Add((title, message));
            return Task.CompletedTask;
        }

        public Task<ActionResult<object>> BroadcastAsync(BroadcastNotificationDto dto, Guid adminUserId, CancellationToken ct) => throw new NotImplementedException();
        public Task NotifyRoleAsync(UserRole role, NotificationType type, string title, string message, CancellationToken ct) => throw new NotImplementedException();
        public Task<ActionResult<NotificationListResponse>> ListAllAsync(int page, int pageSize, CancellationToken ct) => throw new NotImplementedException();
        public Task<ActionResult<NotificationListResponse>> ListForUserAsync(Guid userId, UserRole role, int page, int pageSize, CancellationToken ct) => throw new NotImplementedException();
        public Task<ActionResult<object>> MarkReadAsync(Guid userId, Guid notificationId, CancellationToken ct) => throw new NotImplementedException();
        public Task<ActionResult<object>> MarkAllReadAsync(Guid userId, UserRole role, CancellationToken ct) => throw new NotImplementedException();
    }
}
