using AimPark.API.Data;
using AimPark.API.DTOs;
using AimPark.API.Entities;
using AimPark.API.Enums;
using AimPark.API.Helpers;
using AimPark.API.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace AimPark.API.Tests;

/// <summary>
/// The end-of-semester sweep must archive who it should, leave alone anyone in
/// the middle of something, and change nothing at all on a preview.
/// </summary>
public class BulkArchiveTests
{
    private const string AdminPassword = "correct horse";
    private static readonly DateTime Now = new(2026, 10, 20, 12, 0, 0, DateTimeKind.Utc);
    private static readonly DateTime LongAgo = Now.AddDays(-200);

    private static AppDbContext NewDb() => new(new DbContextOptionsBuilder<AppDbContext>()
        .UseInMemoryDatabase(Guid.NewGuid().ToString())
        .Options);

    private static AdminUserService Service(AppDbContext db) => new(
        new Repository<User>(db), new Repository<AdminAuditLog>(db), db,
        storage: null!, notificationService: null!, otpService: null!, emailService: null!);

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

    private static User Student(AppDbContext db, string name, string? tag = null, DateTime? created = null)
    {
        var user = new User
        {
            Id = Guid.NewGuid(), FullName = name, Email = $"{Guid.NewGuid()}@x.test", Role = UserRole.User,
            Affiliation = Affiliation.Student, CreatedAt = created ?? LongAgo,
            RfidTagId = tag, RfidStatus = tag is null ? RfidStatus.Unassigned : RfidStatus.Active
        };
        db.Users.Add(user);
        return user;
    }

    private static async Task<BulkArchiveResponse> Run(AppDbContext db, Guid adminId, BulkArchiveDto dto)
    {
        var result = await Service(db).BulkArchiveAsync(adminId, dto, CancellationToken.None);
        return Assert.IsType<BulkArchiveResponse>(Assert.IsType<OkObjectResult>(result.Result).Value);
    }

    private static BulkArchiveDto Real(params Guid[] ids) => new()
    {
        UserIds = [.. ids], Reason = "End of 1st sem 2026", Password = AdminPassword
    };

    [Fact]
    public async Task A_preview_lists_who_would_go_and_changes_nothing()
    {
        var db = NewDb();
        var admin = Admin(db);
        var ana = Student(db, "Ana", tag: "AB12");
        await db.SaveChangesAsync();

        var response = await Run(db, admin.Id, new BulkArchiveDto { DryRun = true, InactiveBefore = Now });

        Assert.Equal(ana.Id, Assert.Single(response.Users).UserId);
        Assert.True(response.Users[0].HasCard);
        Assert.False((await db.Users.FindAsync(ana.Id))!.IsDeleted);
        Assert.Equal("AB12", (await db.Users.FindAsync(ana.Id))!.RfidTagId);
        Assert.Empty(db.AdminAuditLogs);
    }

    [Fact]
    public async Task Archiving_marks_the_account_hands_the_card_back_and_audits_it()
    {
        var db = NewDb();
        var admin = Admin(db);
        var ana = Student(db, "Ana", tag: "AB12");
        await db.SaveChangesAsync();

        var response = await Run(db, admin.Id, Real(ana.Id));

        var saved = (await db.Users.FindAsync(ana.Id))!;
        Assert.True(saved.IsDeleted);
        Assert.NotNull(saved.DeletedAt);
        Assert.Null(saved.RfidTagId);
        Assert.Equal(1, response.CardsRevoked);
        Assert.Equal(RfidCardState.Free, (await db.Set<RfidCard>().FindAsync("AB12"))!.State);
        Assert.Contains(db.AdminAuditLogs, l =>
            l.Action == "Archive" && l.TargetUserId == ana.Id && l.Reason!.Contains("End of 1st sem 2026"));
    }

    [Fact]
    public async Task Anyone_in_the_middle_of_something_is_skipped_with_the_reason()
    {
        var db = NewDb();
        var admin = Admin(db);
        var parked = Student(db, "Parked");
        var owes = Student(db, "Owes");
        var appeal = Student(db, "Appeal");
        var done = Student(db, "Done");
        var rule = new PolicyRule { Id = Guid.NewGuid(), Title = "Rule" };
        db.Add(rule);
        db.ParkingLogs.Add(new ParkingLog { Id = Guid.NewGuid(), UserId = parked.Id, EntryTime = Now.AddHours(-1) });
        db.Set<PaymentTransaction>().Add(new PaymentTransaction
        {
            Id = Guid.NewGuid(), UserId = owes.Id, AmountDue = 40m, Status = PaymentStatus.Pending
        });
        db.Set<Violation>().Add(new Violation
        {
            Id = Guid.NewGuid(), UserId = appeal.Id, PolicyRuleId = rule.Id, Status = ViolationStatus.PendingAppeal
        });
        await db.SaveChangesAsync();

        var response = await Run(db, admin.Id, Real(parked.Id, owes.Id, appeal.Id, done.Id));

        Assert.Equal(done.Id, Assert.Single(response.Users).UserId);
        Assert.Equal(3, response.Skipped.Count);
        Assert.Contains(response.Skipped, s => s.FullName == "Parked" && s.Reason.Contains("parked"));
        Assert.Contains(response.Skipped, s => s.FullName == "Owes" && s.Reason.Contains("unpaid"));
        Assert.Contains(response.Skipped, s => s.FullName == "Appeal" && s.Reason.Contains("violation"));
        Assert.False((await db.Users.FindAsync(parked.Id))!.IsDeleted);
        Assert.True((await db.Users.FindAsync(done.Id))!.IsDeleted);
    }

    [Fact]
    public async Task The_inactive_since_date_counts_sessions_and_taps_not_just_account_age()
    {
        var db = NewDb();
        var admin = Admin(db);
        var idle = Student(db, "Idle", tag: "T1");
        var parkedLately = Student(db, "Parked lately");
        var tappedLately = Student(db, "Tapped lately", tag: "T2");
        var newAccount = Student(db, "New account", created: Now.AddDays(-2));
        db.ParkingLogs.Add(new ParkingLog
        {
            Id = Guid.NewGuid(), UserId = parkedLately.Id, EntryTime = Now.AddDays(-5), ExitTime = Now.AddDays(-5).AddHours(2)
        });
        db.Set<GateTapEvent>().Add(new GateTapEvent { Id = Guid.NewGuid(), RfidTagId = "T2", At = Now.AddDays(-3) });
        await db.SaveChangesAsync();

        var response = await Run(db, admin.Id, new BulkArchiveDto { DryRun = true, InactiveBefore = Now.AddDays(-30) });

        Assert.Equal(idle.Id, Assert.Single(response.Users).UserId);
    }

    [Fact]
    public async Task Staff_and_the_admins_own_account_are_never_archived_in_bulk()
    {
        var db = NewDb();
        var admin = Admin(db);
        var guard = new User { Id = Guid.NewGuid(), FullName = "Guard", Email = "g@x.test", Role = UserRole.Security, CreatedAt = LongAgo };
        db.Users.Add(guard);
        await db.SaveChangesAsync();

        var response = await Run(db, admin.Id, Real(guard.Id, admin.Id));

        Assert.Empty(response.Users);
        Assert.Equal(2, response.Skipped.Count);
        Assert.False((await db.Users.FindAsync(guard.Id))!.IsDeleted);
        Assert.False((await db.Users.FindAsync(admin.Id))!.IsDeleted);
    }

    [Fact]
    public async Task A_wrong_password_a_missing_reason_or_nobody_chosen_refuses_the_run()
    {
        var db = NewDb();
        var admin = Admin(db);
        var ana = Student(db, "Ana");
        await db.SaveChangesAsync();
        var service = Service(db);

        var wrong = Real(ana.Id);
        wrong.Password = "nope";
        Assert.IsType<UnauthorizedObjectResult>((await service.BulkArchiveAsync(admin.Id, wrong, default)).Result);

        var noReason = Real(ana.Id);
        noReason.Reason = "  ";
        Assert.IsType<BadRequestObjectResult>((await service.BulkArchiveAsync(admin.Id, noReason, default)).Result);

        var nobody = Real();
        Assert.IsType<BadRequestObjectResult>((await service.BulkArchiveAsync(admin.Id, nobody, default)).Result);

        Assert.False((await db.Users.FindAsync(ana.Id))!.IsDeleted);
    }

    [Fact]
    public void Skip_reasons_follow_a_fixed_order()
    {
        Assert.Null(BulkArchiveRules.SkipReason(UserRole.User, false, false, false, false, false));
        Assert.Contains("own account", BulkArchiveRules.SkipReason(UserRole.User, true, false, true, true, true));
        Assert.Contains("Staff", BulkArchiveRules.SkipReason(UserRole.Security, false, false, false, false, false));
        Assert.Contains("Already", BulkArchiveRules.SkipReason(UserRole.User, false, true, false, false, false));
        Assert.True(BulkArchiveRules.IsOpen(ViolationStatus.Issued));
        Assert.False(BulkArchiveRules.IsOpen(ViolationStatus.Dismissed));
        Assert.False(BulkArchiveRules.IsOpen(ViolationStatus.Accountable));
    }
}
