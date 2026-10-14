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
/// The Users list can be narrowed to people whose licence or registration has run
/// out, or runs out within 60 days, and each row says what is wrong. The Overview
/// counts them with the same filter and a page size of one.
/// </summary>
public class UserExpiryListTests
{
    private static readonly DateOnly Today = new(2026, 10, 15);

    private static DateTime In(int days) => Today.AddDays(days).ToDateTime(TimeOnly.MinValue);

    // ── The classification ─────────────────────────────────────────────────

    [Fact]
    public void NothingCloseMeansNothingToSay()
    {
        var worst = DocumentExpiry.Worst(In(200), [("ABC1234", In(300))], Today);

        Assert.Null(worst);
    }

    [Fact]
    public void SixtyDaysOutIsStillExpiringAndSixtyOneIsNot()
    {
        Assert.Equal("Expiring", DocumentExpiry.Worst(In(60), [], Today)!.State);
        Assert.Null(DocumentExpiry.Worst(In(61), [], Today));
    }

    [Fact]
    public void TheDayItExpiresIsStillExpiringAndTheDayAfterIsExpired()
    {
        Assert.Equal("Expiring", DocumentExpiry.Worst(In(0), [], Today)!.State);
        Assert.Equal("Expired", DocumentExpiry.Worst(In(-1), [], Today)!.State);
    }

    [Fact]
    public void ExpiredOutranksExpiringWhateverTheDates()
    {
        var worst = DocumentExpiry.Worst(In(5), [("ABC1234", In(-30))], Today)!;

        Assert.Equal("Expired", worst.State);
        Assert.Equal("Registration ABC1234", worst.What);
    }

    [Fact]
    public void AmongExpiredTheOneLateTheLongestWins()
    {
        var worst = DocumentExpiry.Worst(In(-3), [("ABC1234", In(-40))], Today)!;

        Assert.Equal("Registration ABC1234", worst.What);
    }

    // ── The list ───────────────────────────────────────────────────────────

    private static AppDbContext NewDb() => new(new DbContextOptionsBuilder<AppDbContext>()
        .UseInMemoryDatabase(Guid.NewGuid().ToString())
        .Options);

    private static AdminUserService Service(AppDbContext db) =>
        new(new Repository<User>(db), new Repository<AdminAuditLog>(db), db, storage: null!, notificationService: null!);

    private static User Person(
        AppDbContext db, string name, DateTime? licence, AccountStatus status = AccountStatus.Active,
        bool archived = false)
    {
        var user = new User
        {
            Id = Guid.NewGuid(), FullName = name, Email = $"{name}@x.test", Role = UserRole.User,
            AccountStatus = status, RegistrationStep = RegistrationStep.Completed,
            LicenseValidThrough = licence, IsDeleted = archived
        };
        db.Add(user);
        return user;
    }

    private static void Car(AppDbContext db, User owner, string plate, DateTime? registration, bool eBike = false) =>
        db.Add(new Vehicle
        {
            UserId = owner.Id, PlateNumber = plate, VehicleType = VehicleType.Car, Color = "Black",
            RegistrationValidThrough = registration, IsEBike = eBike
        });

    private static async Task<UserListResponse> ListAsync(AppDbContext db, string? expiry, int pageSize = 50)
    {
        var result = await Service(db).ListAsync(1, pageSize, null, null, null, null, expiry, default);
        return (UserListResponse)((OkObjectResult)result.Result!).Value!;
    }

    private static DateTime Real(int days) => DateTime.UtcNow.Date.AddDays(days);

    private static async Task<AppDbContext> SeedAsync()
    {
        var db = NewDb();

        Person(db, "ExpiredLicence", Real(-5));
        var lateOr = Person(db, "ExpiredOr", Real(300));
        Car(db, lateOr, "AAA111", Real(-10));
        var soon = Person(db, "SoonOr", Real(300));
        Car(db, soon, "BBB222", Real(20));
        var both = Person(db, "SoonLicenceExpiredOr", Real(15));
        Car(db, both, "CCC333", Real(-2));
        var fine = Person(db, "AllFine", Real(400));
        Car(db, fine, "DDD444", Real(400));

        // None of these should ever appear.
        var ebike = Person(db, "EBikeOnly", Real(400));
        Car(db, ebike, "EB0001", Real(-50), eBike: true);
        Person(db, "ArchivedExpired", Real(-5), archived: true);
        Person(db, "NotApprovedExpired", Real(-5), status: AccountStatus.PendingReview);

        await db.SaveChangesAsync();
        return db;
    }

    [Fact]
    public async Task TheExpiredFilterFindsAnyExpiredDocument()
    {
        var db = await SeedAsync();

        var names = (await ListAsync(db, "expired")).Users.Select(u => u.FullName).Order().ToList();

        Assert.Equal(["ExpiredLicence", "ExpiredOr", "SoonLicenceExpiredOr"], names);
    }

    [Fact]
    public async Task TheExpiringFilterLeavesOutAnyoneAlreadyExpired()
    {
        var db = await SeedAsync();

        var names = (await ListAsync(db, "expiring")).Users.Select(u => u.FullName).ToList();

        Assert.Equal(["SoonOr"], names);
    }

    [Fact]
    public async Task AnEBikeArchivedOrUnapprovedAccountNeverShowsUp()
    {
        var db = await SeedAsync();

        var everyone = (await ListAsync(db, "expired")).Users
            .Concat((await ListAsync(db, "expiring")).Users)
            .Select(u => u.FullName)
            .ToList();

        Assert.DoesNotContain("EBikeOnly", everyone);
        Assert.DoesNotContain("ArchivedExpired", everyone);
        Assert.DoesNotContain("NotApprovedExpired", everyone);
    }

    [Fact]
    public async Task ThePageSizeDoesNotChangeTheCount()
    {
        // This is how the Overview counts: one row, and the total beside it.
        var db = await SeedAsync();

        var page = await ListAsync(db, "expired", pageSize: 1);

        Assert.Single(page.Users);
        Assert.Equal(3, page.TotalCount);
    }

    [Fact]
    public async Task EachRowSaysWhatIsWrongWithIt()
    {
        var db = await SeedAsync();

        var users = (await ListAsync(db, null)).Users.ToDictionary(u => u.FullName);

        Assert.Equal("Expired", users["ExpiredLicence"].ExpiryState);
        Assert.Equal("Licence", users["ExpiredLicence"].ExpiryWhat);
        Assert.Equal("Registration AAA111", users["ExpiredOr"].ExpiryWhat);
        Assert.Equal("Expiring", users["SoonOr"].ExpiryState);
        Assert.Null(users["AllFine"].ExpiryState);
        // The expired registration outranks the licence that is merely close.
        Assert.Equal("Registration CCC333", users["SoonLicenceExpiredOr"].ExpiryWhat);
    }

    [Fact]
    public async Task NoFilterListsEveryoneAsBefore()
    {
        var db = await SeedAsync();

        var everyone = await ListAsync(db, null);

        // Applicants still wait on the Registrations page, not here.
        Assert.DoesNotContain(everyone.Users, u => u.FullName == "NotApprovedExpired");
        Assert.Contains(everyone.Users, u => u.FullName == "AllFine");
    }
}
