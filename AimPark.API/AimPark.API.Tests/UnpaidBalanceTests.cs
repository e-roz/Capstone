using AimPark.API.Data;
using AimPark.API.DTOs;
using AimPark.API.Entities;
using AimPark.API.Enums;
using AimPark.API.Helpers;
using AimPark.API.Interfaces;
using AimPark.API.Services;
using AimPark.API.Sync;
using AimPark.API.Sync.Site;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Infrastructure;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;

namespace AimPark.API.Tests;

/// <summary>
/// A driver who owes money is refused at the entry gate, never at the exit, and
/// the site server reaches the same answer from the cloud's snapshot.
/// </summary>
public class UnpaidBalanceTests
{
    private const string Tag = "04A2B3C4";
    private static readonly DateTime Now = new(2026, 10, 10, 12, 0, 0, DateTimeKind.Utc);

    private static PaymentTransaction Bill(
        PaymentSource source = PaymentSource.ParkingFee,
        PaymentStatus status = PaymentStatus.Pending,
        decimal amount = 50m,
        DateTime? dueAt = null) => new()
    {
        Source = source, Status = status, AmountDue = amount, DueAt = dueAt, UserId = Guid.NewGuid()
    };

    // ── The rule ───────────────────────────────────────────────────────────

    [Fact]
    public void AnUnpaidParkingFeeBlocksEntryAtOnce()
    {
        var result = UnpaidBalance.Evaluate([Bill(dueAt: Now.AddDays(7))], Now);

        Assert.True(result.Blocked);
        Assert.Equal(50m, result.Outstanding);
    }

    [Fact]
    public void AFineBlocksOnlyOncePastItsDueDate()
    {
        var before = Bill(PaymentSource.ViolationPenalty, dueAt: Now.AddDays(1));
        var after = Bill(PaymentSource.ViolationPenalty, dueAt: Now.AddMinutes(-1));

        Assert.False(UnpaidBalance.Evaluate([before], Now).Blocked);
        Assert.Equal(50m, UnpaidBalance.Evaluate([before], Now).Outstanding);
        Assert.True(UnpaidBalance.Evaluate([after], Now).Blocked);
    }

    [Theory]
    [InlineData(PaymentStatus.Processing, 50)]
    [InlineData(PaymentStatus.Paid, 50)]
    [InlineData(PaymentStatus.Waived, 50)]
    [InlineData(PaymentStatus.Pending, 0)]
    public void ProcessingPaidWaivedAndZeroBillsNeverBlock(PaymentStatus status, int amount)
    {
        var result = UnpaidBalance.Evaluate([Bill(status: status, amount: amount)], Now);

        Assert.False(result.Blocked);
        Assert.Equal(0m, result.Outstanding);
    }

    // ── The gate ───────────────────────────────────────────────────────────

    private sealed record Gate(AppDbContext Db, ParkingHistoryService Parking, User User, ParkingSlot Slot);

    private static AppDbContext NewDb() => new(new DbContextOptionsBuilder<AppDbContext>()
        .UseInMemoryDatabase(Guid.NewGuid().ToString())
        .Options);

    private static async Task<Gate> GateAsync()
    {
        var db = NewDb();
        var user = new User
        {
            Id = Guid.NewGuid(), FullName = "Juan", Email = "j@x.test", RfidTagId = Tag,
            RfidStatus = RfidStatus.Active, Role = UserRole.User
        };
        var slot = new ParkingSlot { SlotCode = "A1", Status = ParkingSlotStatus.Available };
        db.AddRange(user, slot, new ParkingRate { VehicleType = null, RatePerHour = 30m });
        await db.SaveChangesAsync();

        var notifications = new QuietNotifications();
        var payments = new PaymentService(
            new Repository<PaymentTransaction>(db), new Repository<ParkingRate>(db),
            notifications, db, new NoGateway(), NullLogger<PaymentService>.Instance);

        var parking = new ParkingHistoryService(
            new Repository<ParkingLog>(db), new Repository<ParkingSlot>(db),
            payments, allocationService: null!, notifications, db, new NoSlotSensors());

        return new Gate(db, parking, user, slot);
    }

    private static Task<ActionResult<object>> EnterAsync(Gate g) =>
        g.Parking.LogEntryAsync(new LogParkingEntryDto { RfidTagId = Tag, SlotId = g.Slot.Id }, null, null, default);

    private static string Result(ActionResult<object> r)
    {
        var value = ((ObjectResult)r.Result!).Value!;
        return value.GetType().GetProperty("result")!.GetValue(value)!.ToString()!;
    }

    private static int Status(IConvertToActionResult r) =>
        r.Convert() is ObjectResult o ? o.StatusCode ?? 200 : 200;

    private static void Owe(Gate g, PaymentStatus status = PaymentStatus.Pending)
    {
        var bill = Bill(status: status);
        bill.UserId = g.User.Id;
        g.Db.Add(bill);
        g.Db.SaveChanges();
    }

    [Fact]
    public async Task OwingMoneyDeniesEntryWithAClearReason()
    {
        var g = await GateAsync();
        Owe(g);

        var result = await EnterAsync(g);

        Assert.Equal(400, Status(result));
        Assert.Equal("UNPAID_BALANCE", Result(result));
        Assert.Empty(g.Db.ParkingLogs);
    }

    [Fact]
    public async Task OwingMoneyDoesNotStopYouLeaving()
    {
        var g = await GateAsync();
        g.Slot.Status = ParkingSlotStatus.Occupied;
        g.Db.Add(new ParkingLog
        {
            UserId = g.User.Id, SlotId = g.Slot.Id, EntryTime = DateTime.UtcNow.AddMinutes(-90)
        });
        Owe(g);

        var result = await g.Parking.LogExitAsync(new LogParkingExitDto { RfidTagId = Tag }, null, null, default);

        Assert.Equal(200, Status(result));
        Assert.Equal("EXIT_LOGGED", Result(result));
        Assert.NotNull((await g.Db.ParkingLogs.SingleAsync()).ExitTime);
    }

    [Fact]
    public async Task PayingLetsYouInAgain()
    {
        var g = await GateAsync();
        Owe(g);
        Assert.Equal("UNPAID_BALANCE", Result(await EnterAsync(g)));

        g.Db.PaymentTransactions.Single().Status = PaymentStatus.Paid;
        await g.Db.SaveChangesAsync();

        var result = await EnterAsync(g);
        Assert.Equal(200, Status(result));
        Assert.Single(g.Db.ParkingLogs);
    }

    [Fact]
    public async Task AProcessingPaymentDoesNotBlockEntry()
    {
        var g = await GateAsync();
        Owe(g, PaymentStatus.Processing);

        Assert.Equal(200, Status(await EnterAsync(g)));
    }

    // ── The site server ────────────────────────────────────────────────────

    private static SiteEntryDues SiteDues(AppDbContext db, SiteSnapshot? snapshot)
    {
        var cache = new SiteDues();
        if (snapshot is not null) cache.Set(snapshot);
        return new SiteEntryDues(db, cache);
    }

    private static SyncDue Due(Guid userId, PaymentStatus status = PaymentStatus.Pending) => new()
    {
        Id = Guid.NewGuid(), UserId = userId, Source = PaymentSource.ParkingFee, Status = status,
        AmountDue = 40m, CreatedAt = Now
    };

    [Fact]
    public async Task TheSiteBlocksFromTheCloudsBillList()
    {
        var db = NewDb();
        var user = Guid.NewGuid();
        var site = SiteDues(db, new SiteSnapshot { GeneratedAt = Now, Dues = [Due(user)] });

        Assert.True(UnpaidBalance.Evaluate(await site.GetOwedAsync(user, default), Now).Blocked);
        Assert.False(UnpaidBalance.Evaluate(await site.GetOwedAsync(Guid.NewGuid(), default), Now).Blocked);
    }

    [Fact]
    public async Task AnOlderCloudWithNoBillListBlocksNobody()
    {
        var db = NewDb();
        var user = Guid.NewGuid();
        db.Add(new PaymentTransaction { UserId = user, AmountDue = 40m, CreatedAt = Now });
        await db.SaveChangesAsync();

        Assert.Empty(await SiteDues(db, new SiteSnapshot { GeneratedAt = Now, Dues = null }).GetOwedAsync(user, default));
        Assert.Empty(await SiteDues(db, null).GetOwedAsync(user, default));
    }

    [Fact]
    public async Task ABillTheSiteJustMadeCountsUntilTheCloudHasSeenIt()
    {
        var db = NewDb();
        var user = Guid.NewGuid();
        db.Add(new PaymentTransaction { UserId = user, AmountDue = 40m, CreatedAt = Now.AddMinutes(-1) });
        await db.SaveChangesAsync();

        var site = SiteDues(db, new SiteSnapshot { GeneratedAt = Now, Dues = [], SettledPaymentIds = [] });

        Assert.True(UnpaidBalance.Evaluate(await site.GetOwedAsync(user, default), Now).Blocked);
    }

    [Fact]
    public async Task ABillTheCloudSettledNoLongerBlocksAtTheSite()
    {
        var db = NewDb();
        var user = Guid.NewGuid();
        var justPaid = new PaymentTransaction { UserId = user, AmountDue = 40m, CreatedAt = Now.AddMinutes(-1) };
        var older = new PaymentTransaction { UserId = user, AmountDue = 40m, CreatedAt = Now.AddDays(-2) };
        db.AddRange(justPaid, older);
        await db.SaveChangesAsync();

        // One was paid moments ago; the other is old and absent from the unpaid list.
        var site = SiteDues(db, new SiteSnapshot { GeneratedAt = Now, Dues = [], SettledPaymentIds = [justPaid.Id] });

        Assert.Empty(await site.GetOwedAsync(user, default));
    }

    [Fact]
    public async Task AProcessingBillAtTheCloudDoesNotBlockAtTheSite()
    {
        var db = NewDb();
        var user = Guid.NewGuid();
        var due = Due(user, PaymentStatus.Processing);
        db.Add(new PaymentTransaction { Id = due.Id, UserId = user, AmountDue = 40m, CreatedAt = Now.AddMinutes(-1) });
        await db.SaveChangesAsync();

        var site = SiteDues(db, new SiteSnapshot { GeneratedAt = Now, Dues = [due] });

        Assert.False(UnpaidBalance.Evaluate(await site.GetOwedAsync(user, default), Now).Blocked);
    }

    // ── Access status ──────────────────────────────────────────────────────

    private static AccessStatusResponse Access(ActionResult<AccessStatusResponse> r) =>
        (AccessStatusResponse)((ObjectResult)r.Result!).Value!;

    [Fact]
    public async Task AccessStatusReportsTheBalanceOnlyWhenThereIsOne()
    {
        var db = NewDb();
        var user = new User { Id = Guid.NewGuid(), RfidStatus = RfidStatus.Active };
        db.Add(user);
        await db.SaveChangesAsync();
        var service = new UserProfileService(new Repository<User>(db), db);

        var clean = Access(await service.GetAccessStatusAsync(user.Id, default));
        Assert.Null(clean.EntryBlockedReason);
        Assert.Null(clean.OutstandingBalance);

        db.Add(new PaymentTransaction { UserId = user.Id, AmountDue = 75m });
        await db.SaveChangesAsync();

        var owing = Access(await service.GetAccessStatusAsync(user.Id, default));
        Assert.Equal("UNPAID_BALANCE", owing.EntryBlockedReason);
        Assert.Equal(75m, owing.OutstandingBalance);
    }

    // ── Slot watch is gone ─────────────────────────────────────────────────

    [Fact]
    public void TheRetiredSlotWatchEndpointsAreHarmlessNoOps()
    {
        var controller = new AimPark.API.Controllers.NotificationsController(null!, null!);

        var get = (OkObjectResult)controller.GetSlotWatch().Result!;
        Assert.Equal(false, get.Value!.GetType().GetProperty("watching")!.GetValue(get.Value));
        Assert.IsType<NoContentResult>(controller.WatchSlots());
        Assert.IsType<NoContentResult>(controller.UnwatchSlots());
    }

    // ── Stubs ──────────────────────────────────────────────────────────────

    private sealed class NoGateway : IPaymentGateway
    {
        public string Name => "None";

        public Task<GatewayCheckout> CreateCheckoutAsync(
            PaymentTransaction payment, string description, CancellationToken ct = default) =>
            throw new NotImplementedException();

        public bool TryReadEvent(string rawBody, IDictionary<string, string> headers, out GatewayEvent gatewayEvent)
        {
            gatewayEvent = null!;
            return false;
        }
    }

    private sealed class QuietNotifications : INotificationService
    {
        public Task NotifyUserAsync(Guid userId, NotificationType type, string title, string message,
            IDictionary<string, string>? data, CancellationToken ct) => Task.CompletedTask;

        public Task<ActionResult<object>> BroadcastAsync(BroadcastNotificationDto dto, Guid adminUserId, CancellationToken ct) => throw new NotImplementedException();
        public Task NotifyRoleAsync(UserRole role, NotificationType type, string title, string message, CancellationToken ct) => throw new NotImplementedException();
        public Task<ActionResult<NotificationListResponse>> ListAllAsync(int page, int pageSize, CancellationToken ct) => throw new NotImplementedException();
        public Task<ActionResult<NotificationListResponse>> ListForUserAsync(Guid userId, UserRole role, int page, int pageSize, CancellationToken ct) => throw new NotImplementedException();
        public Task<ActionResult<object>> MarkReadAsync(Guid userId, Guid notificationId, CancellationToken ct) => throw new NotImplementedException();
    }
}
