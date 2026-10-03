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

namespace AimPark.API.Tests;

/// <summary>
/// Visitor cards are registered ahead of time, lent at the gate, released by
/// the exit tap, and shared by many visitors without mixing up their logs.
/// </summary>
public class VisitorCardTests
{
    private const string Card = "04A2B3C4";
    private static readonly Guid Guard = Guid.NewGuid();

    private static AppDbContext NewDb() => new(new DbContextOptionsBuilder<AppDbContext>()
        .UseInMemoryDatabase(Guid.NewGuid().ToString())
        .Options);

    private static async Task<AppDbContext> DbWithCardAsync(VisitorCardState state = VisitorCardState.Active)
    {
        var db = NewDb();
        db.VisitorCards.Add(new VisitorCard { RfidTagId = Card, Label = "V1", State = state });
        await db.SaveChangesAsync();
        return db;
    }

    private static VisitorPassService Passes(AppDbContext db) => new(new Repository<VisitorPass>(db), db);

    private static ParkingHistoryService Parking(AppDbContext db) => new(
        new Repository<ParkingLog>(db), new Repository<ParkingSlot>(db),
        paymentService: null!, allocationService: null!, notificationService: null!,
        db, new NoSlotSensors());

    private static IssueVisitorPassDto Visitor(string name, string tag = Card) => new()
    {
        RfidTagId = tag, VisitorName = name, PlateNumber = "abc 123", VehicleType = "Car"
    };

    private static int Status(IConvertToActionResult result) =>
        result.Convert() is ObjectResult o ? o.StatusCode ?? 200 : 200;

    private static T Body<T>(ActionResult<T> result) => (T)((ObjectResult)result.Result!).Value!;

    /// <summary>Stands in for the entry the guard's save logs after issuing.</summary>
    private static async Task<ParkingLog> ParkAsync(AppDbContext db, string name)
    {
        await Passes(db).IssueAsync(Visitor(name), Guard, default);
        var pass = await db.VisitorPasses.OrderByDescending(p => p.IssuedAt).FirstAsync();
        var log = new ParkingLog
        {
            VisitorPassId = pass.Id, EntryTime = DateTime.UtcNow.AddMinutes(-30), LoggedByUserId = Guard
        };
        db.ParkingLogs.Add(log);
        await db.SaveChangesAsync();
        return log;
    }

    // ── Issuing ────────────────────────────────────────────────────────────

    [Fact]
    public async Task OnlyARegisteredVisitorCardCanBeLent()
    {
        var db = NewDb();
        var result = await Passes(db).IssueAsync(Visitor("Ana"), Guard, default);

        Assert.Equal(409, Status(result));
        Assert.Empty(db.VisitorPasses);
    }

    [Fact]
    public async Task ABlockedVisitorCardCannotBeLent()
    {
        var db = await DbWithCardAsync(VisitorCardState.Blocked);
        var result = await Passes(db).IssueAsync(Visitor("Ana"), Guard, default);

        Assert.Equal(409, Status(result));
    }

    [Fact]
    public async Task AHandTypedUidMatchesTheCard()
    {
        var db = await DbWithCardAsync();
        var result = await Passes(db).IssueAsync(Visitor("Ana", tag: "04:a2:b3:c4"), Guard, default);

        Assert.Equal(200, Status(result));
        Assert.Equal(Card, db.VisitorPasses.Single().RfidTagId);
    }

    [Fact]
    public async Task ACardCannotBeLentWhileItsLastVisitorIsParked()
    {
        var db = await DbWithCardAsync();
        await ParkAsync(db, "Ana");

        // Her pass ran out while she was inside; it is no longer Active.
        var pass = db.VisitorPasses.Single();
        pass.Status = VisitorPassStatus.Expired;
        await db.SaveChangesAsync();

        var result = await Passes(db).IssueAsync(Visitor("Ben"), Guard, default);
        Assert.Equal(409, Status(result));
    }

    // ── Exit and return ────────────────────────────────────────────────────

    [Fact]
    public async Task TheExitTapReleasesTheCardButItIsNotYetReturned()
    {
        var db = await DbWithCardAsync();
        var log = await ParkAsync(db, "Ana");

        await Parking(db).LogExitAsync(new LogParkingExitDto { LogId = log.Id }, null, Guid.NewGuid(), default);

        var pass = db.VisitorPasses.Single();
        Assert.Equal(VisitorPassStatus.Returned, pass.Status);
        Assert.NotNull(pass.ReturnedAt);
        Assert.Null(pass.CardCollectedAt);

        var cards = Body(await new VisitorCardService(db).ListAsync(default));
        Assert.Equal("NotYetReturned", cards.Single().Whereabouts);
    }

    [Fact]
    public async Task TheGuardConfirmsTheCardIsBack()
    {
        var db = await DbWithCardAsync();
        var log = await ParkAsync(db, "Ana");
        await Parking(db).LogExitAsync(new LogParkingExitDto { LogId = log.Id }, null, Guid.NewGuid(), default);

        var pass = db.VisitorPasses.Single();
        Assert.Equal(200, Status(await Passes(db).ConfirmCardReturnedAsync(pass.Id, Guard, default)));
        Assert.NotNull(pass.CardCollectedAt);
    }

    [Fact]
    public async Task LendingTheCardAgainMeansItCameBack()
    {
        var db = await DbWithCardAsync();
        var log = await ParkAsync(db, "Ana");
        await Parking(db).LogExitAsync(new LogParkingExitDto { LogId = log.Id }, null, Guid.NewGuid(), default);

        var result = await Passes(db).IssueAsync(Visitor("Ben"), Guard, default);

        Assert.Equal(200, Status(result));
        var ana = db.VisitorPasses.Single(p => p.VisitorName == "Ana");
        Assert.NotNull(ana.CardCollectedAt);
    }

    [Fact]
    public async Task TwoVisitorsOnOneCardKeepTheirOwnNamesInTheLog()
    {
        var db = await DbWithCardAsync();

        var ana = await ParkAsync(db, "Ana");
        await Parking(db).LogExitAsync(new LogParkingExitDto { LogId = ana.Id }, null, Guid.NewGuid(), default);

        var ben = await ParkAsync(db, "Ben");
        ben.EntryTime = DateTime.UtcNow;
        await db.SaveChangesAsync();

        var result = await new AdminLogService(db).ListRfidAccessAsync(1, 20, null, default);
        var logs = Body(result).Logs;

        Assert.Equal(["Ben", "Ana"], logs.Select(l => l.UserName));
        Assert.All(logs, l => Assert.Equal(Card, l.RfidTagId));
    }

    // ── The drawer ─────────────────────────────────────────────────────────

    [Fact]
    public async Task AUsersCardCannotBecomeAVisitorCard()
    {
        var db = NewDb();
        db.Users.Add(new User { FullName = "Carla Cruz", Email = "c@x.edu", RfidTagId = Card });
        await db.SaveChangesAsync();

        var result = await new VisitorCardService(db).AddAsync(new AddVisitorCardDto { RfidTagId = Card, Label = "v1" }, default);

        Assert.Equal(409, Status(result));
        Assert.Empty(db.VisitorCards);
    }

    [Fact]
    public async Task ALentCardIsBlockedRatherThanRemoved()
    {
        var db = await DbWithCardAsync();
        await ParkAsync(db, "Ana");

        Assert.Equal(400, Status(await new VisitorCardService(db).RemoveAsync(Card, default)));
        Assert.Single(db.VisitorCards);
    }

    // ── The gate ───────────────────────────────────────────────────────────

    [Fact]
    public async Task AnIdleVisitorCardWaitsForTheGuard()
    {
        var db = await DbWithCardAsync();
        var outcome = await new GateTapHandler(db, parking: null!).HandleAsync(1, Guid.NewGuid(), "04 a2 b3 c4", default);

        Assert.False(outcome.Opened);
        Assert.Equal("V1", outcome.AwaitingVisitorCard);
    }

    [Fact]
    public async Task ABlockedVisitorCardIsRefusedAtTheGate()
    {
        var db = await DbWithCardAsync(VisitorCardState.Blocked);
        var outcome = await new GateTapHandler(db, parking: null!).HandleAsync(1, Guid.NewGuid(), Card, default);

        Assert.False(outcome.Opened);
        Assert.Null(outcome.AwaitingVisitorCard);
    }

    [Fact]
    public void TappingTheSameCardAgainKeepsOneForm()
    {
        var pending = new PendingVisitorRegistrations();
        var first = pending.Add(Card, "V1", 1, "COM4", "G1", Guid.NewGuid(), null);
        var second = pending.Add(Card, "V1", 1, "COM4", "G1", Guid.NewGuid(), null);

        Assert.Equal(first.Id, second.Id);
        Assert.Single(pending.List());
    }

    [Fact]
    public void OnlyOneGuardGetsToSaveATap()
    {
        var pending = new PendingVisitorRegistrations();
        var tap = pending.Add(Card, "V1", 1, "COM4", "G1", Guid.NewGuid(), null);

        Assert.NotNull(pending.Take(tap.Id));
        Assert.Null(pending.Take(tap.Id));

        pending.Restore(tap);
        Assert.Single(pending.List());
    }
}
