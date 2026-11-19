using AimPark.API.Data;
using AimPark.API.DTOs;
using AimPark.API.Entities;
using AimPark.API.Enums;
using AimPark.API.Interfaces;
using AimPark.API.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace AimPark.API.Tests;

/// <summary>
/// Bulk archive's "archive when clear": the people a run left alone are
/// warned once they are clear and away from the lot, archived after the
/// notice, and never archived if they park again.
/// </summary>
public class AutoArchiveTests
{
    private const string AdminPassword = "correct horse";
    private static readonly DateTime LongAgo = DateTime.UtcNow.AddDays(-200);

    private sealed class Db
    {
        public AppDbContext Context { get; } = new(new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options);

        public FakeNotifications Notifications { get; } = new();

        public AdminUserService Service() => new(
            new Repository<User>(Context), new Repository<AdminAuditLog>(Context), Context,
            storage: null!, notificationService: Notifications, otpService: null!, emailService: null!);
    }

    /// <summary>Records the pushes instead of sending them.</summary>
    private sealed class FakeNotifications : INotificationService
    {
        public List<(Guid UserId, string Title)> Sent { get; } = [];

        public Task NotifyUserAsync(Guid userId, NotificationType type, string title, string message,
            IDictionary<string, string>? data, CancellationToken ct)
        {
            Sent.Add((userId, title));
            return Task.CompletedTask;
        }

        public Task<ActionResult<object>> BroadcastAsync(BroadcastNotificationDto dto, Guid adminUserId, CancellationToken ct) => throw new NotSupportedException();
        public Task<ActionResult<NotificationListResponse>> ListAllAsync(int page, int pageSize, CancellationToken ct) => throw new NotSupportedException();
        public Task<ActionResult<NotificationListResponse>> ListSystemAsync(DateTime? from, DateTime? to, int take, CancellationToken ct) => throw new NotSupportedException();
        public Task<ActionResult<NotificationListResponse>> ListForUserAsync(Guid userId, UserRole role, int page, int pageSize, CancellationToken ct) => throw new NotSupportedException();
        public Task<ActionResult<object>> MarkReadAsync(Guid userId, Guid notificationId, CancellationToken ct) => throw new NotSupportedException();
        public Task<ActionResult<object>> MarkAllReadAsync(Guid userId, UserRole role, CancellationToken ct) => throw new NotSupportedException();
    }

    private static User Admin(AppDbContext db)
    {
        var admin = new User
        {
            Id = Guid.NewGuid(), FullName = "Admin One", Email = "a@x.test", Role = UserRole.Admin,
            PasswordHash = BCrypt.Net.BCrypt.HashPassword(AdminPassword), CreatedAt = LongAgo
        };
        db.Users.Add(admin);
        return admin;
    }

    private static User Student(AppDbContext db, string name, string? tag = null)
    {
        var user = new User
        {
            Id = Guid.NewGuid(), FullName = name, Email = $"{Guid.NewGuid()}@x.test", Role = UserRole.User,
            Affiliation = Affiliation.Student, CreatedAt = LongAgo,
            RfidTagId = tag, RfidStatus = tag is null ? RfidStatus.Unassigned : RfidStatus.Active
        };
        db.Users.Add(user);
        return user;
    }

    private static PaymentTransaction Bill(AppDbContext db, User user)
    {
        var bill = new PaymentTransaction { Id = Guid.NewGuid(), UserId = user.Id, AmountDue = 30m, Status = PaymentStatus.Pending };
        db.Set<PaymentTransaction>().Add(bill);
        return bill;
    }

    private static BulkArchiveDto Real(bool auto, params Guid[] ids) => new()
    {
        UserIds = [.. ids], Reason = "End of 1st sem", Password = AdminPassword,
        AutoArchive = auto, GraceDays = 7
    };

    private static async Task<IActionResult?> RunArchive(Db db, Guid adminId, BulkArchiveDto dto) =>
        (await db.Service().BulkArchiveAsync(adminId, dto, default)).Result;

    private static BulkArchivePending PendingFor(AppDbContext db, User user) =>
        db.Set<BulkArchivePending>().Single(p => p.UserId == user.Id);

    private static Task<int> Pass(Db db, DateTime at) => db.Service().RunAutoArchivePassAsync(at, default);

    [Fact]
    public async Task Turning_it_on_lists_everyone_left_alone_as_waiting_and_tells_nobody_yet()
    {
        var db = new Db();
        var admin = Admin(db.Context);
        var kim = Student(db.Context, "Kim");
        var clear = Student(db.Context, "Clear");
        Bill(db.Context, kim);
        await db.Context.SaveChangesAsync();

        Assert.IsType<OkObjectResult>(await RunArchive(db, admin.Id, Real(true, kim.Id, clear.Id)));

        var pending = Assert.Single(db.Context.Set<BulkArchivePending>());
        Assert.Equal(kim.Id, pending.UserId);
        Assert.Equal(PendingArchiveState.Waiting, pending.State);
        Assert.Contains("unpaid", pending.Note);
        Assert.Empty(db.Notifications.Sent);

        var run = db.Context.Set<BulkArchiveRun>().Single();
        Assert.True(run.AutoArchive);
        Assert.Equal(7, run.GraceDays);
        Assert.Equal("End of 1st sem", run.Reason);
    }

    [Fact]
    public async Task Without_opting_in_nothing_is_queued()
    {
        var db = new Db();
        var admin = Admin(db.Context);
        var kim = Student(db.Context, "Kim");
        Bill(db.Context, kim);
        await db.Context.SaveChangesAsync();

        await RunArchive(db, admin.Id, Real(false, kim.Id));

        Assert.Empty(db.Context.Set<BulkArchivePending>());
        Assert.Equal(0, await Pass(db, DateTime.UtcNow.AddDays(30)));
    }

    [Fact]
    public async Task Paying_starts_the_notice_and_the_account_goes_when_it_ends()
    {
        var db = new Db();
        var admin = Admin(db.Context);
        var kim = Student(db.Context, "Kim", tag: "K1");
        var bill = Bill(db.Context, kim);
        await db.Context.SaveChangesAsync();
        await RunArchive(db, admin.Id, Real(true, kim.Id));

        // Still owing: nothing happens.
        await Pass(db, DateTime.UtcNow.AddHours(1));
        Assert.Equal(PendingArchiveState.Waiting, PendingFor(db.Context, kim).State);
        Assert.Empty(db.Notifications.Sent);

        // Paid, and stays away.
        bill.Status = PaymentStatus.Paid;
        await db.Context.SaveChangesAsync();
        var paidAt = DateTime.UtcNow.AddDays(1);
        await Pass(db, paidAt);

        var pending = PendingFor(db.Context, kim);
        Assert.Equal(PendingArchiveState.Warned, pending.State);
        Assert.Equal(paidAt.AddDays(7), pending.ArchiveAt);
        Assert.Equal(kim.Id, Assert.Single(db.Notifications.Sent).UserId);

        // A day before the date: still here.
        Assert.Equal(0, await Pass(db, paidAt.AddDays(6)));
        Assert.False((await db.Context.Users.FindAsync(kim.Id))!.IsDeleted);

        // The date comes: archived, card back, audited under the admin who ran it.
        Assert.Equal(1, await Pass(db, paidAt.AddDays(7)));
        var saved = (await db.Context.Users.FindAsync(kim.Id))!;
        Assert.True(saved.IsDeleted);
        Assert.Null(saved.RfidTagId);
        Assert.Equal(PendingArchiveState.Archived, PendingFor(db.Context, kim).State);
        Assert.Contains(db.Context.AdminAuditLogs, l =>
            l.Action == "Archive" && l.TargetUserId == kim.Id && l.AdminUserId == admin.Id
            && l.Reason!.Contains("Auto-archive") && l.Reason.Contains("End of 1st sem"));
        Assert.Single(db.Notifications.Sent);
    }

    [Fact]
    public async Task Parking_again_after_the_run_keeps_the_account_even_mid_notice()
    {
        var db = new Db();
        var admin = Admin(db.Context);
        var kim = Student(db.Context, "Kim");
        var bill = Bill(db.Context, kim);
        await db.Context.SaveChangesAsync();
        await RunArchive(db, admin.Id, Real(true, kim.Id));

        bill.Status = PaymentStatus.Paid;
        await db.Context.SaveChangesAsync();
        await Pass(db, DateTime.UtcNow.AddDays(1));
        Assert.Equal(PendingArchiveState.Warned, PendingFor(db.Context, kim).State);

        var parked = DateTime.UtcNow.AddDays(2);
        db.Context.ParkingLogs.Add(new ParkingLog { Id = Guid.NewGuid(), UserId = kim.Id, EntryTime = parked, ExitTime = parked.AddHours(2) });
        await db.Context.SaveChangesAsync();

        Assert.Equal(0, await Pass(db, DateTime.UtcNow.AddDays(30)));
        var pending = PendingFor(db.Context, kim);
        Assert.Equal(PendingArchiveState.Kept, pending.State);
        Assert.StartsWith("Parked again", pending.Note);
        Assert.False((await db.Context.Users.FindAsync(kim.Id))!.IsDeleted);
    }

    [Fact]
    public async Task A_new_bill_during_the_notice_puts_them_back_to_waiting()
    {
        var db = new Db();
        var admin = Admin(db.Context);
        var kim = Student(db.Context, "Kim");
        var bill = Bill(db.Context, kim);
        await db.Context.SaveChangesAsync();
        await RunArchive(db, admin.Id, Real(true, kim.Id));

        bill.Status = PaymentStatus.Paid;
        await db.Context.SaveChangesAsync();
        await Pass(db, DateTime.UtcNow.AddDays(1));

        Bill(db.Context, kim);
        await db.Context.SaveChangesAsync();
        await Pass(db, DateTime.UtcNow.AddDays(10));

        var pending = PendingFor(db.Context, kim);
        Assert.Equal(PendingArchiveState.Waiting, pending.State);
        Assert.Null(pending.ArchiveAt);
        Assert.False((await db.Context.Users.FindAsync(kim.Id))!.IsDeleted);
    }

    [Fact]
    public async Task After_the_end_date_waiting_people_are_dropped_but_a_running_notice_finishes()
    {
        var db = new Db();
        var admin = Admin(db.Context);
        var owes = Student(db.Context, "Owes");
        var paid = Student(db.Context, "Paid");
        Bill(db.Context, owes);
        var paidBill = Bill(db.Context, paid);
        await db.Context.SaveChangesAsync();

        var dto = Real(true, owes.Id, paid.Id);
        dto.AutoArchiveUntil = DateTime.UtcNow.AddDays(10);
        await RunArchive(db, admin.Id, dto);

        paidBill.Status = PaymentStatus.Paid;
        await db.Context.SaveChangesAsync();
        await Pass(db, DateTime.UtcNow.AddDays(8));   // warned, archive on day 15

        await Pass(db, DateTime.UtcNow.AddDays(11));  // past the end date
        Assert.Equal(PendingArchiveState.Expired, PendingFor(db.Context, owes).State);
        Assert.Equal(PendingArchiveState.Warned, PendingFor(db.Context, paid).State);

        Assert.Equal(1, await Pass(db, DateTime.UtcNow.AddDays(16)));
        Assert.True((await db.Context.Users.FindAsync(paid.Id))!.IsDeleted);
        Assert.False((await db.Context.Users.FindAsync(owes.Id))!.IsDeleted);
    }

    [Fact]
    public async Task Editing_the_notice_period_moves_the_date_for_people_already_warned()
    {
        var db = new Db();
        var admin = Admin(db.Context);
        var kim = Student(db.Context, "Kim");
        var bill = Bill(db.Context, kim);
        await db.Context.SaveChangesAsync();
        await RunArchive(db, admin.Id, Real(true, kim.Id));

        bill.Status = PaymentStatus.Paid;
        await db.Context.SaveChangesAsync();
        var warnedAt = DateTime.UtcNow.AddHours(1);
        await Pass(db, warnedAt);

        var run = db.Context.Set<BulkArchiveRun>().Single();
        var result = await db.Service().UpdateAutoArchiveAsync(admin.Id, run.Id,
            new BulkArchiveAutoSettingsDto { GraceDays = 14 }, default);
        Assert.IsType<OkObjectResult>(result.Result);

        Assert.Equal(14, run.GraceDays);
        Assert.Equal(warnedAt.AddDays(14), PendingFor(db.Context, kim).ArchiveAt);
        Assert.Equal(0, await Pass(db, warnedAt.AddDays(8)));
    }

    [Fact]
    public async Task Turning_it_off_or_cancelling_one_person_stops_their_archive()
    {
        var db = new Db();
        var admin = Admin(db.Context);
        var a = Student(db.Context, "A");
        var b = Student(db.Context, "B");
        Bill(db.Context, a);
        Bill(db.Context, b);
        await db.Context.SaveChangesAsync();
        await RunArchive(db, admin.Id, Real(true, a.Id, b.Id));

        var pendingA = PendingFor(db.Context, a);
        Assert.IsType<OkObjectResult>((await db.Service().CancelPendingArchiveAsync(admin.Id, pendingA.Id, default)).Result);
        Assert.Equal(PendingArchiveState.Cancelled, pendingA.State);

        var run = db.Context.Set<BulkArchiveRun>().Single();
        await db.Service().UpdateAutoArchiveAsync(admin.Id, run.Id, new BulkArchiveAutoSettingsDto { Enabled = false }, default);
        Assert.NotNull(run.AutoArchiveStoppedAt);
        Assert.Equal(PendingArchiveState.Cancelled, PendingFor(db.Context, b).State);

        // Paying later changes nothing.
        foreach (var bill in db.Context.Set<PaymentTransaction>()) bill.Status = PaymentStatus.Paid;
        await db.Context.SaveChangesAsync();
        Assert.Equal(0, await Pass(db, DateTime.UtcNow.AddDays(30)));
        Assert.Empty(db.Notifications.Sent);
    }

    [Fact]
    public async Task It_can_be_turned_on_after_the_run_and_a_newer_run_replaces_the_older_list()
    {
        var db = new Db();
        var admin = Admin(db.Context);
        var kim = Student(db.Context, "Kim");
        Bill(db.Context, kim);
        await db.Context.SaveChangesAsync();

        await RunArchive(db, admin.Id, Real(false, kim.Id));
        var first = db.Context.Set<BulkArchiveRun>().Single();
        await db.Service().UpdateAutoArchiveAsync(admin.Id, first.Id, new BulkArchiveAutoSettingsDto { Enabled = true }, default);
        Assert.Equal(PendingArchiveState.Waiting, PendingFor(db.Context, kim).State);

        await RunArchive(db, admin.Id, Real(true, kim.Id));

        Assert.NotNull(first.AutoArchiveStoppedAt);
        var rows = db.Context.Set<BulkArchivePending>().Where(p => p.UserId == kim.Id).ToList();
        Assert.Equal(2, rows.Count);
        Assert.Single(rows, r => r.State == PendingArchiveState.Waiting);
        Assert.Single(rows, r => r.State == PendingArchiveState.Cancelled && r.Note!.StartsWith("Replaced"));
    }

    [Theory]
    [InlineData(0)]
    [InlineData(61)]
    public async Task A_notice_period_out_of_range_refuses_the_run(int days)
    {
        var db = new Db();
        var admin = Admin(db.Context);
        var kim = Student(db.Context, "Kim");
        await db.Context.SaveChangesAsync();

        var dto = Real(true, kim.Id);
        dto.GraceDays = days;
        Assert.IsType<BadRequestObjectResult>(await RunArchive(db, admin.Id, dto));
        Assert.False((await db.Context.Users.FindAsync(kim.Id))!.IsDeleted);
    }

    [Fact]
    public async Task The_last_run_shows_the_list_and_settings()
    {
        var db = new Db();
        var admin = Admin(db.Context);
        var kim = Student(db.Context, "Kim");
        Bill(db.Context, kim);
        await db.Context.SaveChangesAsync();
        await RunArchive(db, admin.Id, Real(true, kim.Id));

        var result = await db.Service().GetLastBulkArchiveRunAsync(admin.Id, default);
        var last = Assert.IsType<BulkArchiveLastRunResponse>(Assert.IsType<OkObjectResult>(result.Result).Value);

        Assert.True(last.Auto.Enabled);
        Assert.Equal(7, last.Auto.GraceDays);
        Assert.NotNull(last.Auto.AutoArchiveUntil);
        var item = Assert.Single(last.Pending);
        Assert.Equal("Kim", item.FullName);
        Assert.Equal("Waiting", item.State);
    }
}
