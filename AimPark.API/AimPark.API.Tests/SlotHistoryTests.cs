using AimPark.API.Data;
using AimPark.API.DTOs;
using AimPark.API.Entities;
using AimPark.API.Enums;
using AimPark.API.Services;
using AimPark.API.Sync;
using AimPark.API.Sync.Cloud;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace AimPark.API.Tests;

/// <summary>
/// "Who was in this bay?" is answered from parking sessions that overlapped a
/// time window, so the edges of that overlap are what is worth pinning down.
/// </summary>
public class SlotHistoryTests
{
    private static readonly DateTime Noon = new(2026, 10, 20, 12, 0, 0, DateTimeKind.Utc);

    private static AppDbContext NewDb() => new(new DbContextOptionsBuilder<AppDbContext>()
        .UseInMemoryDatabase(Guid.NewGuid().ToString())
        .Options);

    private static ParkingSlotService Service(AppDbContext db) => new(
        new Repository<ParkingSlot>(db), db, new SiteLinkState(), Options.Create(new SiteOptions()));

    private static (User user, ParkingSlot slot) Seed(AppDbContext db, string name = "Juan Cruz")
    {
        var user = new User { Id = Guid.NewGuid(), FullName = name, Email = $"{Guid.NewGuid()}@x.test" };
        var slot = new ParkingSlot { Id = Guid.NewGuid(), SlotCode = "M3", Gate = 1 };
        db.AddRange(user, slot);
        return (user, slot);
    }

    private static ParkingLog Session(User user, ParkingSlot slot, DateTime entry, DateTime? exit, DateTime? confirmed = null) => new()
    {
        Id = Guid.NewGuid(),
        UserId = user.Id,
        SlotId = slot.Id,
        EntryTime = entry,
        ExitTime = exit,
        SlotConfirmedAt = confirmed
    };

    private static async Task<SlotHistoryResponse> History(
        AppDbContext db, Guid slotId, DateTime? from = null, DateTime? to = null)
    {
        var result = await Service(db).GetHistoryAsync(slotId, from, to, CancellationToken.None);
        return Assert.IsType<SlotHistoryResponse>(Assert.IsType<OkObjectResult>(result.Result).Value);
    }

    [Fact]
    public async Task Window_keeps_only_the_sessions_that_overlap_it()
    {
        var db = NewDb();
        var (user, slot) = Seed(db);
        var before = Session(user, slot, Noon.AddHours(-5), Noon.AddHours(-4));
        var crossesStart = Session(user, slot, Noon.AddHours(-1), Noon.AddHours(1));
        var inside = Session(user, slot, Noon.AddHours(2), Noon.AddHours(3));
        var stillIn = Session(user, slot, Noon.AddHours(3), null);
        var after = Session(user, slot, Noon.AddHours(10), Noon.AddHours(11));
        db.ParkingLogs.AddRange(before, crossesStart, inside, stillIn, after);
        await db.SaveChangesAsync();

        var history = await History(db, slot.Id, Noon, Noon.AddHours(4));

        Assert.Equal(
            new[] { stillIn.Id, inside.Id, crossesStart.Id },
            history.Sessions.Select(s => s.LogId).ToArray());
    }

    [Fact]
    public async Task A_session_that_ended_exactly_when_the_window_opened_still_counts()
    {
        var db = NewDb();
        var (user, slot) = Seed(db);
        var edge = Session(user, slot, Noon.AddHours(-2), Noon);
        db.ParkingLogs.Add(edge);
        await db.SaveChangesAsync();

        var history = await History(db, slot.Id, Noon, Noon.AddHours(1));

        Assert.Single(history.Sessions);
    }

    [Fact]
    public async Task Without_a_window_every_session_is_listed_newest_first()
    {
        var db = NewDb();
        var (user, slot) = Seed(db);
        var older = Session(user, slot, Noon.AddDays(-2), Noon.AddDays(-2).AddHours(1));
        var newer = Session(user, slot, Noon, null);
        db.ParkingLogs.AddRange(older, newer);
        await db.SaveChangesAsync();

        var history = await History(db, slot.Id);

        Assert.Equal(new[] { newer.Id, older.Id }, history.Sessions.Select(s => s.LogId).ToArray());
    }

    [Fact]
    public async Task Current_is_the_open_session_and_is_not_cut_by_the_window()
    {
        var db = NewDb();
        var (user, slot) = Seed(db);
        var open = Session(user, slot, Noon.AddDays(-1), null);
        db.ParkingLogs.Add(open);
        await db.SaveChangesAsync();

        var history = await History(db, slot.Id, Noon.AddDays(5), Noon.AddDays(6));

        Assert.Equal(open.Id, history.Current!.LogId);
    }

    [Fact]
    public async Task An_unconfirmed_session_says_so()
    {
        var db = NewDb();
        var (user, slot) = Seed(db);
        var suggested = Session(user, slot, Noon, null);
        var confirmed = Session(user, slot, Noon.AddDays(-1), Noon.AddDays(-1).AddHours(2), confirmed: Noon.AddDays(-1));
        db.ParkingLogs.AddRange(suggested, confirmed);
        await db.SaveChangesAsync();

        var history = await History(db, slot.Id);

        Assert.Null(history.Sessions.Single(s => s.LogId == suggested.Id).ConfirmedAt);
        Assert.NotNull(history.Sessions.Single(s => s.LogId == confirmed.Id).ConfirmedAt);
    }

    [Fact]
    public async Task Other_bays_sessions_are_left_out()
    {
        var db = NewDb();
        var (user, slot) = Seed(db);
        var other = new ParkingSlot { Id = Guid.NewGuid(), SlotCode = "M4", Gate = 1 };
        db.Add(other);
        db.ParkingLogs.AddRange(Session(user, slot, Noon, null), Session(user, other, Noon, null));
        await db.SaveChangesAsync();

        var history = await History(db, slot.Id);

        Assert.Single(history.Sessions);
    }

    [Fact]
    public async Task The_plate_the_camera_read_wins_over_a_registered_one()
    {
        var db = NewDb();
        var (user, slot) = Seed(db);
        db.Set<Vehicle>().Add(new Vehicle { Id = Guid.NewGuid(), UserId = user.Id, PlateNumber = "REG111" });
        var log = Session(user, slot, Noon, null);
        log.AlprPlateNumber = "CAM222";
        db.ParkingLogs.Add(log);
        await db.SaveChangesAsync();

        var history = await History(db, slot.Id);

        Assert.Equal("CAM222", history.Sessions.Single().PlateNumber);
    }

    [Fact]
    public async Task Violations_issued_for_a_session_in_the_bay_are_listed()
    {
        var db = NewDb();
        var (user, slot) = Seed(db);
        var log = Session(user, slot, Noon, null);
        var rule = new PolicyRule { Id = Guid.NewGuid(), Title = "Wrong bay" };
        db.AddRange(log, rule);
        db.Set<Violation>().Add(new Violation
        {
            Id = Guid.NewGuid(),
            UserId = user.Id,
            PolicyRuleId = rule.Id,
            ParkingLogId = log.Id,
            PenaltyAmount = 50m
        });
        await db.SaveChangesAsync();

        var history = await History(db, slot.Id);

        var violation = Assert.Single(history.Violations);
        Assert.Equal("Wrong bay", violation.RuleTitle);
        Assert.Equal("Juan Cruz", violation.UserName);
    }

    [Fact]
    public async Task Unknown_bay_is_not_found_and_a_backwards_window_is_refused()
    {
        var db = NewDb();
        var (_, slot) = Seed(db);
        await db.SaveChangesAsync();

        var missing = await Service(db).GetHistoryAsync(Guid.NewGuid(), null, null, CancellationToken.None);
        Assert.IsType<NotFoundObjectResult>(missing.Result);

        var backwards = await Service(db).GetHistoryAsync(slot.Id, Noon.AddHours(1), Noon, CancellationToken.None);
        Assert.IsType<BadRequestObjectResult>(backwards.Result);
    }
}
