using AimPark.API.Data;
using AimPark.API.DTOs;
using AimPark.API.Entities;
using AimPark.API.Enums;
using AimPark.API.Interfaces;
using AimPark.API.Services;
using AimPark.API.Sync;
using AimPark.API.Sync.Cloud;
using AimPark.API.Sync.Site;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Infrastructure;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;

namespace AimPark.API.Tests;

/// <summary>
/// A driver still parked pays from the app, then drives to the gate. The fee
/// covers the stay up to the payment, the barrier opens on a tap for a short
/// while after it, and a driver who stays longer pays for the rest at the gate.
/// </summary>
public class PayAheadTests
{
    private const string Tag = "04A2B3C4";
    private static readonly Guid Device = Guid.NewGuid();

    private sealed record Lot(AppDbContext Db, ParkingHistoryService Parking, User User, ParkingLog Log, SiteDues Dues, Notices Notices);

    private static AppDbContext NewDb() => new(new DbContextOptionsBuilder<AppDbContext>()
        .UseInMemoryDatabase(Guid.NewGuid().ToString())
        .Options);

    /// <summary>Parked just under two hours at ₱30 an hour: ₱60 now.</summary>
    private static async Task<Lot> LotAsync(bool site = false)
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
        db.AddRange(user, slot, log, new ParkingRate { VehicleType = null, RatePerHour = 30m, MinimumFee = 0m });
        await db.SaveChangesAsync();

        var notices = new Notices();
        var payments = new PaymentService(
            new Repository<PaymentTransaction>(db), new Repository<ParkingRate>(db),
            notices, db, new NoGateway(), NullLogger<PaymentService>.Instance);

        var dues = new SiteDues();
        IEntryDues entryDues = site ? new SiteEntryDues(db, dues) : new DbEntryDues(db);

        var parking = new ParkingHistoryService(
            new Repository<ParkingLog>(db), new Repository<ParkingSlot>(db),
            payments, allocationService: null!, notices, db, new NoSlotSensors(), entryDues,
            Options.Create(new GateOptions { PaidExitGraceMinutes = 15 }));

        return new Lot(db, parking, user, log, dues, notices);
    }

    private static async Task<PayAheadResponse> PayAhead(Lot l)
        => (PayAheadResponse)((OkObjectResult)(await l.Parking.PayAheadAsync(l.User.Id, l.Log.Id, default)).Result!).Value!;

    private static Task<ActionResult<object>> Tap(Lot l) =>
        l.Parking.LogExitAsync(new LogParkingExitDto { RfidTagId = Tag }, null, Device, default);

    private static int Status(IConvertToActionResult r) =>
        r.Convert() is ObjectResult o ? o.StatusCode ?? 200 : 200;

    private static List<PaymentTransaction> Bills(Lot l) =>
        l.Db.Set<PaymentTransaction>().AsNoTracking().OrderBy(p => p.CreatedAt).ToList();

    private static ParkingLog Session(Lot l) => l.Db.Set<ParkingLog>().AsNoTracking().Single();

    private static async Task PaidAt(Lot l, DateTime when)
    {
        foreach (var bill in l.Db.Set<PaymentTransaction>().Where(p => p.Status != PaymentStatus.Paid))
        {
            bill.Status = PaymentStatus.Paid;
            bill.PaidAt = when;
        }
        await l.Db.SaveChangesAsync();
    }

    private static async Task<ParkingHistoryEntryResponse> History(Lot l)
        => ((ParkingHistoryResponse)((OkObjectResult)(await l.Parking.GetMyHistoryAsync(l.User.Id, null, 1, 20, default)).Result!).Value!).Logs.Single();

    private static async Task<ActiveParkingSessionResponse> Active(Lot l)
        => ((List<ActiveParkingSessionResponse>)((OkObjectResult)(await l.Parking.ListActiveSessionsAsync(default)).Result!).Value!).Single();

    // ── Asking to pay while parked ─────────────────────────────────────────

    [Fact]
    public async Task Paying_ahead_raises_one_bill_priced_up_to_now_without_a_notice()
    {
        var l = await LotAsync();

        var ahead = await PayAhead(l);

        var bill = Assert.Single(Bills(l));
        Assert.Equal(bill.Id, ahead.PaymentId);
        Assert.Equal(60m, ahead.AmountDue);
        Assert.True(bill.PaidAhead);
        Assert.Equal(PaymentStatus.Pending, bill.Status);
        Assert.Null(Session(l).ExitTime);
        Assert.Empty(l.Notices.Sent);
    }

    [Fact]
    public async Task A_bill_opened_ahead_is_not_a_driver_waiting_at_the_exit()
    {
        var l = await LotAsync();
        await PayAhead(l);

        Assert.False((await History(l)).WaitingToLeave);
        Assert.False((await Active(l)).WaitingToLeave);
    }

    [Fact]
    public async Task Asking_again_before_paying_reprices_the_same_bill()
    {
        var l = await LotAsync();
        await PayAhead(l);
        l.Db.Set<ParkingLog>().Single().EntryTime = DateTime.UtcNow.AddMinutes(-179).AddSeconds(-30);
        await l.Db.SaveChangesAsync();

        var again = await PayAhead(l);

        var bill = Assert.Single(Bills(l));
        Assert.Equal(90m, bill.AmountDue);
        Assert.Equal(90m, again.AmountDue);
    }

    [Fact]
    public async Task Once_paid_the_app_is_told_when_to_leave_by()
    {
        var l = await LotAsync();
        await PayAhead(l);
        var paidAt = DateTime.UtcNow;
        await PaidAt(l, paidAt);

        var entry = await History(l);
        var again = await PayAhead(l);

        Assert.Equal(paidAt.AddMinutes(15), entry.LeaveBy);
        Assert.True(again.Paid);
        Assert.Null(again.PaymentId);
        Assert.Single(Bills(l));
    }

    [Fact]
    public async Task A_session_already_closed_cannot_be_paid_ahead()
    {
        var l = await LotAsync();
        l.Db.Set<ParkingLog>().Single().ExitTime = DateTime.UtcNow;
        await l.Db.SaveChangesAsync();

        var result = await l.Parking.PayAheadAsync(l.User.Id, l.Log.Id, default);

        Assert.IsType<BadRequestObjectResult>(result.Result);
    }

    [Fact]
    public async Task Someone_elses_session_is_not_found()
    {
        var l = await LotAsync();

        var result = await l.Parking.PayAheadAsync(Guid.NewGuid(), l.Log.Id, default);

        Assert.IsType<NotFoundObjectResult>(result.Result);
    }

    // ── At the gate ────────────────────────────────────────────────────────

    [Fact]
    public async Task Paid_ahead_and_tapping_in_time_opens_the_barrier_at_once()
    {
        var l = await LotAsync();
        await PayAhead(l);
        await PaidAt(l, DateTime.UtcNow.AddMinutes(-10));

        var result = await Tap(l);

        Assert.Equal(200, Status(result));
        Assert.NotNull(Session(l).ExitTime);
        Assert.Single(Bills(l));
    }

    [Fact]
    public async Task Tapping_after_the_window_bills_the_rest_and_holds_the_barrier()
    {
        var l = await LotAsync();
        await PayAhead(l);
        // Paid ₱60 for two hours, then stayed another hour.
        await PaidAt(l, DateTime.UtcNow.AddMinutes(-60));
        l.Db.Set<ParkingLog>().Single().EntryTime = DateTime.UtcNow.AddMinutes(-179).AddSeconds(-30);
        await l.Db.SaveChangesAsync();

        var result = await Tap(l);

        Assert.Equal(402, Status(result));
        Assert.Null(Session(l).ExitTime);
        var bills = Bills(l);
        Assert.Equal(2, bills.Count);
        var extra = bills[1];
        Assert.Equal(30m, extra.AmountDue);
        Assert.False(extra.PaidAhead);
        Assert.Equal(PaymentStatus.Pending, extra.Status);
        Assert.Contains(l.Notices.Sent, n => n.Title == "Pay to leave");

        // The guard post sees the extra as the bill they are waiting on.
        var waiting = await Active(l);
        Assert.True(waiting.WaitingToLeave);
        Assert.Equal(extra.Id, waiting.PaymentId);

        await PaidAt(l, DateTime.UtcNow);
        var after = await Tap(l);

        Assert.Equal(200, Status(after));
        Assert.NotNull(Session(l).ExitTime);
        Assert.Equal(2, Bills(l).Count);
    }

    [Fact]
    public async Task Reaching_the_gate_before_paying_becomes_an_ordinary_hold_priced_to_the_tap()
    {
        var l = await LotAsync();
        await PayAhead(l);
        l.Db.Set<ParkingLog>().Single().EntryTime = DateTime.UtcNow.AddMinutes(-179).AddSeconds(-30);
        await l.Db.SaveChangesAsync();

        var result = await Tap(l);

        Assert.Equal(402, Status(result));
        var bill = Assert.Single(Bills(l));
        Assert.False(bill.PaidAhead);
        Assert.Equal(90m, bill.AmountDue);
        Assert.True((await History(l)).WaitingToLeave);
    }

    [Fact]
    public async Task Staying_past_the_window_while_still_parked_raises_the_rest_from_the_app()
    {
        var l = await LotAsync();
        await PayAhead(l);
        await PaidAt(l, DateTime.UtcNow.AddMinutes(-60));
        l.Db.Set<ParkingLog>().Single().EntryTime = DateTime.UtcNow.AddMinutes(-179).AddSeconds(-30);
        await l.Db.SaveChangesAsync();

        var again = await PayAhead(l);

        Assert.Equal(30m, again.AmountDue);
        var extra = Bills(l)[1];
        Assert.Equal(again.PaymentId, extra.Id);
        Assert.True(extra.PaidAhead);
    }

    // ── Keeping the site and the cloud in step ─────────────────────────────

    [Fact]
    public async Task At_the_site_a_bill_paid_ahead_in_the_app_reaches_the_gate_through_the_snapshot()
    {
        var l = await LotAsync(site: true);
        var paidAt = DateTime.UtcNow.AddMinutes(-2);
        var cloudBill = new PaymentTransaction
        {
            Id = Guid.NewGuid(), Source = PaymentSource.ParkingFee, ParkingLogId = l.Log.Id, UserId = l.User.Id,
            DurationMinutes = 118, RatePerHourApplied = 30m, AmountDue = 59m, Status = PaymentStatus.Paid,
            PaidAhead = true, PaidAt = paidAt, Method = PaymentMethod.GCash, Provider = "Simulated",
            CreatedAt = paidAt.AddMinutes(-1)
        };

        await new SnapshotApplier(l.Db, new SyncSuppression(), l.Dues).ApplyAsync(Snapshot(l, cloudBill), default);
        var result = await Tap(l);

        Assert.Equal(200, Status(result));
        var bill = Assert.Single(Bills(l));
        Assert.Equal(cloudBill.Id, bill.Id);
        Assert.Equal(PaymentStatus.Paid, bill.Status);
    }

    [Fact]
    public async Task At_the_site_a_later_snapshot_settles_the_copy_it_made_earlier()
    {
        var l = await LotAsync(site: true);
        var cloudBill = new PaymentTransaction
        {
            Id = Guid.NewGuid(), Source = PaymentSource.ParkingFee, ParkingLogId = l.Log.Id, UserId = l.User.Id,
            AmountDue = 60m, Status = PaymentStatus.Pending, PaidAhead = true, CreatedAt = DateTime.UtcNow
        };
        var applier = new SnapshotApplier(l.Db, new SyncSuppression(), l.Dues);
        await applier.ApplyAsync(Snapshot(l, cloudBill), default);

        cloudBill.Status = PaymentStatus.Paid;
        cloudBill.PaidAt = DateTime.UtcNow;
        await applier.ApplyAsync(Snapshot(l, cloudBill), default);

        var bill = Assert.Single(Bills(l));
        Assert.Equal(PaymentStatus.Paid, bill.Status);
        Assert.NotNull(bill.PaidAt);
    }

    [Fact]
    public void A_hold_at_the_site_reprices_the_clouds_unpaid_copy()
    {
        var cloud = new PaymentTransaction { Status = PaymentStatus.Pending, AmountDue = 60m, DurationMinutes = 120, PaidAhead = true };
        var site = new PaymentTransaction { Status = PaymentStatus.Pending, AmountDue = 90m, DurationMinutes = 180, PaidAhead = false };

        var settled = EventIngestor.MergePayment(cloud, site);

        Assert.False(settled);
        Assert.False(cloud.PaidAhead);
        Assert.Equal(90m, cloud.AmountDue);
        Assert.Equal(180, cloud.DurationMinutes);
    }

    [Fact]
    public void A_hold_at_the_site_never_reprices_a_bill_already_paid_in_the_app()
    {
        var cloud = new PaymentTransaction { Status = PaymentStatus.Paid, AmountDue = 60m, PaidAhead = true };
        var site = new PaymentTransaction { Status = PaymentStatus.Pending, AmountDue = 90m, PaidAhead = false };

        Assert.False(EventIngestor.MergePayment(cloud, site));
        Assert.Equal(60m, cloud.AmountDue);
        Assert.Equal(PaymentStatus.Paid, cloud.Status);
    }

    private static SiteSnapshot Snapshot(Lot l, PaymentTransaction bill) => new()
    {
        GeneratedAt = DateTime.UtcNow,
        Users =
        [
            new SyncUser
            {
                Id = l.User.Id, FullName = l.User.FullName, Email = l.User.Email, RfidTagId = Tag,
                RfidStatus = RfidStatus.Active, Role = UserRole.User, AccountStatus = AccountStatus.Active
            }
        ],
        Dues = [],
        SettledPaymentIds = bill.Status == PaymentStatus.Paid ? [bill.Id] : [],
        PaidAheadBills =
        [
            new PaymentTransaction
            {
                Id = bill.Id, Source = bill.Source, ParkingLogId = bill.ParkingLogId, UserId = bill.UserId,
                DurationMinutes = bill.DurationMinutes, RatePerHourApplied = bill.RatePerHourApplied,
                AmountDue = bill.AmountDue, Status = bill.Status, PaidAhead = bill.PaidAhead, PaidAt = bill.PaidAt,
                Method = bill.Method, Provider = bill.Provider, CreatedAt = bill.CreatedAt
            }
        ]
    };

    private sealed class Notices : INotificationService
    {
        public List<(string Title, string Message)> Sent { get; } = [];

        public Task NotifyUserAsync(Guid userId, NotificationType type, string title, string message,
            IDictionary<string, string>? data, CancellationToken ct)
        {
            Sent.Add((title, message));
            return Task.CompletedTask;
        }

        public Task<ActionResult<object>> BroadcastAsync(BroadcastNotificationDto dto, Guid adminUserId, CancellationToken ct) => throw new NotImplementedException();
        public Task NotifyRoleAsync(UserRole role, NotificationType type, string title, string message, CancellationToken ct) => throw new NotImplementedException();
        public Task<ActionResult<NotificationListResponse>> ListAllAsync(int page, int pageSize, CancellationToken ct) => throw new NotImplementedException();
        public Task<ActionResult<NotificationListResponse>> ListSystemAsync(DateTime? from, DateTime? to, int take, CancellationToken ct) => throw new NotImplementedException();
        public Task<ActionResult<NotificationListResponse>> ListForUserAsync(Guid userId, UserRole role, int page, int pageSize, CancellationToken ct) => throw new NotImplementedException();
        public Task<ActionResult<object>> MarkReadAsync(Guid userId, Guid notificationId, CancellationToken ct) => throw new NotImplementedException();
        public Task<ActionResult<object>> MarkAllReadAsync(Guid userId, UserRole role, CancellationToken ct) => throw new NotImplementedException();
    }

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
}
