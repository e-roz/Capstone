using System.Security.Claims;
using AimPark.API.Controllers;
using AimPark.API.Data;
using AimPark.API.DTOs;
using AimPark.API.Entities;
using AimPark.API.Enums;
using AimPark.API.Helpers;
using AimPark.API.Interfaces;
using AimPark.API.Services;
using AimPark.API.Sync;
using AimPark.API.Sync.Cloud;
using AimPark.API.Sync.Site;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Infrastructure;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;

namespace AimPark.API.Tests;

/// <summary>
/// A driver tapping out owes this session's fee before the barrier opens: the
/// first tap raises the bill and holds the gate, a guard can take cash or let
/// them out still owing, and the tap after the bill is settled closes the
/// session.
/// </summary>
public class PayBeforeExitTests
{
    private const string Tag = "04A2B3C4";
    private static readonly Guid Device = Guid.NewGuid();

    private sealed record Gate(
        AppDbContext Db, ParkingHistoryService Parking, User User, ParkingLog Log, SiteDues Dues, Notices Notices);

    private static AppDbContext NewDb() => new(new DbContextOptionsBuilder<AppDbContext>()
        .UseInMemoryDatabase(Guid.NewGuid().ToString())
        .Options);

    /// <summary>
    /// A driver parked for just under two hours at ₱30 an hour, which bills as 120 minutes: ₱60.
    /// Entered directly: entry is not what is under test.
    /// </summary>
    private static async Task<Gate> GateAsync(decimal ratePerHour = 30m, bool site = false)
    {
        var db = NewDb();
        var user = new User
        {
            Id = Guid.NewGuid(), FullName = "Juan", Email = "j@x.test", RfidTagId = Tag,
            RfidStatus = RfidStatus.Active, Role = UserRole.User, AccountStatus = AccountStatus.Active
        };
        var slot = new ParkingSlot { SlotCode = "A1", Status = ParkingSlotStatus.Occupied };
        var log = new ParkingLog
        {
            Id = Guid.NewGuid(), UserId = user.Id, SlotId = slot.Id, Gate = 1,
            EntryTime = DateTime.UtcNow.AddMinutes(-119).AddSeconds(-30)
        };
        db.AddRange(user, slot, log, new ParkingRate { VehicleType = null, RatePerHour = ratePerHour });
        await db.SaveChangesAsync();

        var notices = new Notices();
        var payments = new PaymentService(
            new Repository<PaymentTransaction>(db), new Repository<ParkingRate>(db),
            notices, db, new NoGateway(), NullLogger<PaymentService>.Instance);

        var dues = new SiteDues();
        IEntryDues entryDues = site ? new SiteEntryDues(db, dues) : new DbEntryDues(db);

        var parking = new ParkingHistoryService(
            new Repository<ParkingLog>(db), new Repository<ParkingSlot>(db),
            payments, allocationService: null!, notices, db, new NoSlotSensors(), entryDues);

        return new Gate(db, parking, user, log, dues, notices);
    }

    private static Task<ActionResult<object>> Tap(Gate g) =>
        g.Parking.LogExitAsync(new LogParkingExitDto { RfidTagId = Tag }, null, Device, default);

    private static int Status(IConvertToActionResult r) =>
        r.Convert() is ObjectResult o ? o.StatusCode ?? 200 : 200;

    private static string Result(ActionResult<object> r)
    {
        var value = ((ObjectResult)r.Result!).Value!;
        return value.GetType().GetProperty("result")!.GetValue(value)!.ToString()!;
    }

    private static PaymentTransaction OnlyBill(Gate g) => g.Db.Set<PaymentTransaction>().AsNoTracking().Single();

    private static ParkingLog Session(Gate g) => g.Db.Set<ParkingLog>().AsNoTracking().Single();

    // ── The first tap ──────────────────────────────────────────────────────

    [Fact]
    public async Task The_first_tap_holds_the_barrier_and_raises_one_bill()
    {
        var g = await GateAsync();

        var result = await Tap(g);

        Assert.Equal(402, Status(result));
        Assert.Equal("PAYMENT_DUE", Result(result));
        Assert.Null(Session(g).ExitTime);
        var bill = OnlyBill(g);
        Assert.Equal(60m, bill.AmountDue);
        Assert.Equal(PaymentStatus.Pending, bill.Status);
        Assert.Equal(g.Log.Id, bill.ParkingLogId);
    }

    [Fact]
    public async Task Tapping_again_before_paying_does_not_raise_a_second_bill_or_change_the_amount()
    {
        var g = await GateAsync();
        await Tap(g);

        // Time passes, and the rate would now give a bigger number.
        g.Db.Set<ParkingLog>().Single().EntryTime = DateTime.UtcNow.AddHours(-5);
        await g.Db.SaveChangesAsync();
        var second = await Tap(g);

        Assert.Equal(402, Status(second));
        Assert.Equal(60m, OnlyBill(g).AmountDue);
    }

    [Fact]
    public async Task A_fee_of_nothing_lets_the_driver_out_at_once()
    {
        var g = await GateAsync(ratePerHour: 0m);

        var result = await Tap(g);

        Assert.Equal(200, Status(result));
        Assert.Equal("EXIT_LOGGED", Result(result));
        Assert.NotNull(Session(g).ExitTime);
    }

    [Fact]
    public async Task A_guard_logging_the_exit_by_hand_is_not_held()
    {
        var g = await GateAsync();

        var result = await g.Parking.LogExitAsync(new LogParkingExitDto { LogId = g.Log.Id }, Guid.NewGuid(), null, default);

        Assert.Equal(200, Status(result));
        Assert.NotNull(Session(g).ExitTime);
    }

    // ── Settling it ────────────────────────────────────────────────────────

    [Fact]
    public async Task Once_the_bill_is_paid_the_next_tap_closes_the_session()
    {
        var g = await GateAsync();
        await Tap(g);
        var bill = g.Db.Set<PaymentTransaction>().Single();
        bill.Status = PaymentStatus.Paid;
        bill.PaidAt = DateTime.UtcNow;
        await g.Db.SaveChangesAsync();

        var result = await Tap(g);

        Assert.Equal(200, Status(result));
        Assert.Equal("EXIT_LOGGED", Result(result));
        Assert.NotNull(Session(g).ExitTime);
        Assert.Single(g.Db.Set<PaymentTransaction>());
    }

    [Fact]
    public async Task A_checkout_that_is_only_processing_does_not_open_the_barrier()
    {
        var g = await GateAsync();
        await Tap(g);
        g.Db.Set<PaymentTransaction>().Single().Status = PaymentStatus.Processing;
        await g.Db.SaveChangesAsync();

        var result = await Tap(g);

        Assert.Equal(402, Status(result));
        Assert.Null(Session(g).ExitTime);
    }

    [Fact]
    public async Task At_the_site_a_payment_made_in_the_app_opens_the_barrier_through_the_snapshot()
    {
        var g = await GateAsync(site: true);
        await Tap(g);
        var billId = OnlyBill(g).Id;

        // The site's own row is still Pending; only the cloud's settled list knows.
        g.Dues.Set(new SiteSnapshot { GeneratedAt = DateTime.UtcNow, Dues = [], SettledPaymentIds = [billId] });

        var result = await Tap(g);

        Assert.Equal(200, Status(result));
        Assert.NotNull(Session(g).ExitTime);
    }

    [Fact]
    public async Task A_driver_let_out_still_owing_leaves_but_stays_blocked_from_entering()
    {
        var g = await GateAsync();
        await Tap(g);
        var bill = g.Db.Set<PaymentTransaction>().Single();
        bill.Provider = ExitPayment.ReleasedProvider;
        await g.Db.SaveChangesAsync();

        var result = await Tap(g);

        Assert.Equal(200, Status(result));
        Assert.NotNull(Session(g).ExitTime);
        Assert.Equal(PaymentStatus.Pending, OnlyBill(g).Status);
        var owed = await new DbEntryDues(g.Db).GetOwedAsync(g.User.Id, default);
        Assert.True(UnpaidBalance.Evaluate(owed, DateTime.UtcNow).Blocked);
    }

    [Fact]
    public async Task An_older_unpaid_bill_does_not_stop_a_car_already_inside_from_leaving()
    {
        var g = await GateAsync(ratePerHour: 0m);
        g.Db.Add(new PaymentTransaction { UserId = g.User.Id, AmountDue = 80m, Status = PaymentStatus.Pending });
        await g.Db.SaveChangesAsync();

        var result = await Tap(g);

        Assert.Equal(200, Status(result));
        Assert.NotNull(Session(g).ExitTime);
    }

    // ── The guard's actions ────────────────────────────────────────────────

    private static SitePaymentsController Controller(Gate g, Guid guard)
    {
        var controller = new SitePaymentsController(g.Db, g.Notices)
        {
            ControllerContext = new ControllerContext
            {
                HttpContext = new DefaultHttpContext
                {
                    User = new ClaimsPrincipal(new ClaimsIdentity(
                        [new Claim(ClaimTypes.NameIdentifier, guard.ToString())], "test"))
                }
            }
        };
        return controller;
    }

    private static T Value<T>(ActionResult<object> r) => (T)((ObjectResult)r.Result!).Value!;

    private static object Prop(object o, string name) => o.GetType().GetProperty(name)!.GetValue(o)!;

    [Fact]
    public async Task Taking_cash_records_who_took_it_how_and_a_receipt_number()
    {
        var g = await GateAsync();
        await Tap(g);
        var guard = Guid.NewGuid();

        var result = await Controller(g, guard).ReceiveCash(OnlyBill(g).Id, default);

        Assert.IsType<OkObjectResult>(result.Result);
        var bill = OnlyBill(g);
        Assert.Equal(PaymentStatus.Paid, bill.Status);
        Assert.Equal(PaymentMethod.Cash, bill.Method);
        Assert.Equal(ExitPayment.CashProvider, bill.Provider);
        Assert.Equal(guard, bill.ConfirmedByUserId);
        Assert.NotNull(bill.PaidAt);
        Assert.Matches(@"^CASH-\d{8}-0001$", bill.ReferenceNumber);
        Assert.Equal(60m, bill.AmountDue);
    }

    [Fact]
    public async Task Taking_cash_twice_records_it_once()
    {
        var g = await GateAsync();
        await Tap(g);
        var controller = Controller(g, Guid.NewGuid());
        var id = OnlyBill(g).Id;

        await controller.ReceiveCash(id, default);
        var first = OnlyBill(g).ReferenceNumber;
        var again = await controller.ReceiveCash(id, default);

        Assert.IsType<OkObjectResult>(again.Result);
        Assert.Equal(first, OnlyBill(g).ReferenceNumber);
        Assert.Equal(1, await g.Db.Set<PaymentTransaction>().CountAsync(p => p.Method == PaymentMethod.Cash));
    }

    [Fact]
    public async Task After_cash_is_taken_the_next_tap_opens_the_barrier()
    {
        var g = await GateAsync();
        await Tap(g);
        await Controller(g, Guid.NewGuid()).ReceiveCash(OnlyBill(g).Id, default);

        var result = await Tap(g);

        Assert.Equal(200, Status(result));
        Assert.NotNull(Session(g).ExitTime);
    }

    [Fact]
    public async Task Letting_someone_out_needs_a_reason_and_leaves_the_bill_owed()
    {
        var g = await GateAsync();
        await Tap(g);
        var controller = Controller(g, Guid.NewGuid());
        var id = OnlyBill(g).Id;

        var blank = await controller.Release(id, new SitePaymentsController.ReleaseDto { Reason = "  " }, default);
        Assert.IsType<BadRequestObjectResult>(blank.Result);
        Assert.NotEqual(ExitPayment.ReleasedProvider, OnlyBill(g).Provider);

        var done = await controller.Release(id, new SitePaymentsController.ReleaseDto { Reason = "phone battery dead" }, default);
        Assert.IsType<OkObjectResult>(done.Result);
        var bill = OnlyBill(g);
        Assert.Equal(PaymentStatus.Pending, bill.Status);
        Assert.Equal(ExitPayment.ReleasedProvider, bill.Provider);
        Assert.Contains("phone battery dead", bill.ReferenceNumber);
    }

    [Fact]
    public async Task The_cash_summary_totals_what_each_guard_took_today()
    {
        var g = await GateAsync();
        await Tap(g);
        var guard = Guid.NewGuid();
        await Controller(g, guard).ReceiveCash(OnlyBill(g).Id, default);

        var summary = Value<object>(await Controller(g, guard).CashSummary(null, default));

        Assert.Equal(1, Prop(summary, "count"));
        Assert.Equal(60m, Prop(summary, "total"));
        Assert.Equal(60m, Prop(Prop(summary, "mine"), "total"));

        var someoneElse = Value<object>(await Controller(g, Guid.NewGuid()).CashSummary(null, default));
        Assert.Equal(0m, Prop(Prop(someoneElse, "mine"), "total"));
    }

    // ── Waiting to leave, as the panel and the app see it ──────────────────

    [Fact]
    public async Task The_active_list_flags_a_driver_waiting_at_the_exit_until_it_is_settled()
    {
        var g = await GateAsync();
        await Tap(g);

        var waiting = ((List<ActiveParkingSessionResponse>)((OkObjectResult)(await g.Parking.ListActiveSessionsAsync(default)).Result!).Value!).Single();
        Assert.True(waiting.WaitingToLeave);
        Assert.Equal(60m, waiting.AmountDue);
        Assert.NotNull(waiting.PaymentId);

        g.Db.Set<PaymentTransaction>().Single().Status = PaymentStatus.Paid;
        await g.Db.SaveChangesAsync();

        var paid = ((List<ActiveParkingSessionResponse>)((OkObjectResult)(await g.Parking.ListActiveSessionsAsync(default)).Result!).Value!).Single();
        Assert.False(paid.WaitingToLeave);
    }

    [Fact]
    public async Task The_drivers_history_says_they_are_waiting_to_leave_with_the_amount()
    {
        var g = await GateAsync();
        await Tap(g);

        var history = (ParkingHistoryResponse)((OkObjectResult)(await g.Parking.GetMyHistoryAsync(g.User.Id, null, 1, 20, default)).Result!).Value!;

        var entry = Assert.Single(history.Logs);
        Assert.True(entry.WaitingToLeave);
        Assert.Equal(60m, entry.ExitAmountDue);
    }

    // ── Keeping the site and the cloud in step ─────────────────────────────

    [Fact]
    public void Cash_taken_at_the_site_settles_the_clouds_copy_of_the_bill()
    {
        var cloud = new PaymentTransaction { Status = PaymentStatus.Pending, AmountDue = 60m };
        var guard = Guid.NewGuid();
        var site = new PaymentTransaction
        {
            Status = PaymentStatus.Paid, PaidAt = DateTime.UtcNow, Method = PaymentMethod.Cash,
            Provider = ExitPayment.CashProvider, ReferenceNumber = "CASH-20261026-0001", ConfirmedByUserId = guard
        };

        var settled = EventIngestor.MergePayment(cloud, site);

        Assert.True(settled);
        Assert.Equal(PaymentStatus.Paid, cloud.Status);
        Assert.Equal(PaymentMethod.Cash, cloud.Method);
        Assert.Equal(guard, cloud.ConfirmedByUserId);
        Assert.Equal("CASH-20261026-0001", cloud.ReferenceNumber);
    }

    [Fact]
    public void A_bill_the_cloud_already_settled_is_never_changed_by_the_site()
    {
        var cloud = new PaymentTransaction
        {
            Status = PaymentStatus.Paid, Method = PaymentMethod.GCash, Provider = "Simulated", ReferenceNumber = "123"
        };
        var site = new PaymentTransaction
        {
            Status = PaymentStatus.Paid, Method = PaymentMethod.Cash, Provider = ExitPayment.CashProvider, ReferenceNumber = "CASH-1"
        };

        Assert.False(EventIngestor.MergePayment(cloud, site));
        Assert.Equal(PaymentMethod.GCash, cloud.Method);
        Assert.Equal("123", cloud.ReferenceNumber);
    }

    [Fact]
    public void A_release_reaches_the_cloud_without_settling_anything()
    {
        var guard = Guid.NewGuid();
        var cloud = new PaymentTransaction { Status = PaymentStatus.Pending, AmountDue = 60m };
        var site = new PaymentTransaction
        {
            Status = PaymentStatus.Pending, Provider = ExitPayment.ReleasedProvider,
            ReferenceNumber = "RELEASED: dead phone", ConfirmedByUserId = guard
        };

        var settled = EventIngestor.MergePayment(cloud, site);

        Assert.False(settled);
        Assert.Equal(PaymentStatus.Pending, cloud.Status);
        Assert.Equal(guard, cloud.ConfirmedByUserId);
        Assert.Equal("RELEASED: dead phone", cloud.ReferenceNumber);
    }

    [Fact]
    public async Task At_the_site_a_bill_paid_in_cash_no_longer_blocks_the_next_entry_even_before_the_cloud_knows()
    {
        var db = NewDb();
        var user = Guid.NewGuid();
        var bill = new PaymentTransaction
        {
            Id = Guid.NewGuid(), UserId = user, AmountDue = 60m, Status = PaymentStatus.Paid,
            Method = PaymentMethod.Cash, CreatedAt = DateTime.UtcNow
        };
        db.Add(bill);
        await db.SaveChangesAsync();

        // The cloud's list still has it as unpaid.
        var cache = new SiteDues();
        cache.Set(new SiteSnapshot
        {
            GeneratedAt = DateTime.UtcNow,
            Dues = [new SyncDue { Id = bill.Id, UserId = user, Source = PaymentSource.ParkingFee, Status = PaymentStatus.Pending, AmountDue = 60m, CreatedAt = DateTime.UtcNow }]
        });

        Assert.Empty(await new SiteEntryDues(db, cache).GetOwedAsync(user, default));
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

    internal sealed class Notices : INotificationService
    {
        public Task NotifyUserAsync(Guid userId, NotificationType type, string title, string message,
            IDictionary<string, string>? data, CancellationToken ct) => Task.CompletedTask;

        public Task<ActionResult<object>> BroadcastAsync(BroadcastNotificationDto dto, Guid adminUserId, CancellationToken ct) => throw new NotImplementedException();
        public Task NotifyRoleAsync(UserRole role, NotificationType type, string title, string message, CancellationToken ct) => throw new NotImplementedException();
        public Task<ActionResult<NotificationListResponse>> ListAllAsync(int page, int pageSize, CancellationToken ct) => throw new NotImplementedException();
        public Task<ActionResult<NotificationListResponse>> ListSystemAsync(DateTime? from, DateTime? to, int take, CancellationToken ct) => throw new NotImplementedException();
        public Task<ActionResult<NotificationListResponse>> ListForUserAsync(Guid userId, UserRole role, int page, int pageSize, CancellationToken ct) => throw new NotImplementedException();
        public Task<ActionResult<object>> MarkReadAsync(Guid userId, Guid notificationId, CancellationToken ct) => throw new NotImplementedException();
        public Task<ActionResult<object>> MarkAllReadAsync(Guid userId, UserRole role, CancellationToken ct) => throw new NotImplementedException();
    }
}
