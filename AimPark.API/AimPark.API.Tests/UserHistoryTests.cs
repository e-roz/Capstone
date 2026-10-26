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
/// The tabs on a user's detail page: counts that add up, lists that page and
/// filter, and the "possibly involved" lead that must stay a lead.
/// </summary>
public class UserHistoryTests
{
    private static readonly DateTime Noon = DateTime.UtcNow.Date.AddHours(12);

    private static AppDbContext NewDb() => new(new DbContextOptionsBuilder<AppDbContext>()
        .UseInMemoryDatabase(Guid.NewGuid().ToString())
        .Options);

    private static UserHistoryService Service(AppDbContext db) => new(db);

    private static User Person(AppDbContext db, string name, string? tag = null)
    {
        var user = new User { Id = Guid.NewGuid(), FullName = name, Email = $"{Guid.NewGuid()}@x.test", RfidTagId = tag };
        db.Users.Add(user);
        return user;
    }

    private static ParkingSlot Bay(AppDbContext db, string code)
    {
        var slot = new ParkingSlot { Id = Guid.NewGuid(), SlotCode = code, Gate = 1 };
        db.Add(slot);
        return slot;
    }

    private static ParkingLog Session(User u, ParkingSlot? slot, DateTime entry, DateTime? exit, bool confirmed = false, int gate = 1) => new()
    {
        Id = Guid.NewGuid(), UserId = u.Id, SlotId = slot?.Id, EntryTime = entry, ExitTime = exit,
        SlotConfirmedAt = confirmed ? entry.AddMinutes(2) : null, Gate = gate
    };

    private static Incident Report(User by, ParkingSlot? slot, DateTime at) => new()
    {
        Id = Guid.NewGuid(), ReportedByUserId = by.Id, SlotId = slot?.Id, Category = IncidentCategory.VehicleDamage,
        Description = "x", Status = IncidentStatus.Submitted, CreatedAt = at, UpdatedAt = at
    };

    private static T Ok<T>(ActionResult<T> result) =>
        Assert.IsType<T>(Assert.IsType<OkObjectResult>(result.Result).Value);

    [Fact]
    public async Task The_summary_says_how_many_sessions_had_a_confirmed_bay_and_whether_the_current_one_is()
    {
        var db = NewDb();
        var juan = Person(db, "Juan");
        var m3 = Bay(db, "M3");
        db.AddRange(
            Session(juan, m3, Noon.AddDays(-2), Noon.AddDays(-2).AddHours(1), confirmed: true),
            Session(juan, m3, Noon.AddDays(-1), Noon.AddDays(-1).AddHours(1), confirmed: false),
            Session(juan, m3, Noon, null, confirmed: false));
        await db.SaveChangesAsync();

        var s = Ok(await Service(db).GetSummaryAsync(juan.Id, default));

        Assert.Equal(3, s.Sessions);
        Assert.Equal(1, s.SessionsConfirmed);
        Assert.True(s.IsInside);
        Assert.False(s.InsideSlotConfirmed);
    }

    [Fact]
    public async Task A_session_list_row_carries_when_the_bay_was_confirmed()
    {
        var db = NewDb();
        var juan = Person(db, "Juan");
        var m3 = Bay(db, "M3");
        var log = Session(juan, m3, Noon, Noon.AddHours(1), confirmed: true);
        db.Add(log);
        await db.SaveChangesAsync();

        var page = Ok(await Service(db).GetSessionsAsync(juan.Id, 1, 20, null, null, null, default));

        Assert.Equal(log.SlotConfirmedAt, Assert.Single(page.Items).SlotConfirmedAt);
    }

    [Fact]
    public async Task The_summary_counts_each_list_and_the_money()
    {
        var db = NewDb();
        var juan = Person(db, "Juan", tag: "T1");
        var m3 = Bay(db, "M3");
        var rule = new PolicyRule { Id = Guid.NewGuid(), Title = "Rule" };
        db.Add(rule);
        db.ParkingLogs.AddRange(Session(juan, m3, Noon.AddDays(-2), Noon.AddDays(-2).AddHours(1)), Session(juan, m3, Noon.AddHours(-1), null));
        db.Set<Violation>().Add(new Violation { Id = Guid.NewGuid(), UserId = juan.Id, PolicyRuleId = rule.Id, PenaltyAmount = 50m });
        db.Add(Report(juan, null, Noon));
        db.Set<GateTapEvent>().AddRange(
            new GateTapEvent { Id = Guid.NewGuid(), RfidTagId = "T1", At = Noon },
            new GateTapEvent { Id = Guid.NewGuid(), RfidTagId = "T1", At = Noon },
            new GateTapEvent { Id = Guid.NewGuid(), RfidTagId = "other", At = Noon });
        db.Set<PaymentTransaction>().AddRange(
            new PaymentTransaction { Id = Guid.NewGuid(), UserId = juan.Id, AmountDue = 45m, Status = PaymentStatus.Pending },
            new PaymentTransaction { Id = Guid.NewGuid(), UserId = juan.Id, AmountDue = 100m, Status = PaymentStatus.Paid, PaidAt = DateTime.UtcNow },
            new PaymentTransaction { Id = Guid.NewGuid(), UserId = juan.Id, AmountDue = 30m, Status = PaymentStatus.Processing });
        await db.SaveChangesAsync();

        var s = Ok(await Service(db).GetSummaryAsync(juan.Id, default));

        Assert.Equal(2, s.Sessions);
        Assert.Equal(1, s.Violations);
        Assert.Equal(1, s.IncidentsFiled);
        Assert.Equal(2, s.Taps);
        Assert.Equal(45m, s.Owed);
        Assert.Equal(100m, s.PaidThisYear);
        Assert.True(s.IsInside);
        Assert.Equal("M3", s.InsideSlotCode);
    }

    [Fact]
    public async Task Sessions_page_newest_first_and_filter_by_window_and_gate()
    {
        var db = NewDb();
        var juan = Person(db, "Juan");
        var a = Session(juan, null, Noon.AddDays(-3), Noon.AddDays(-3).AddHours(2), gate: 1);
        var b = Session(juan, null, Noon.AddDays(-2), Noon.AddDays(-2).AddHours(2), gate: 2);
        var c = Session(juan, null, Noon.AddDays(-1), Noon.AddDays(-1).AddHours(2), gate: 1);
        db.ParkingLogs.AddRange(a, b, c);
        await db.SaveChangesAsync();
        var service = Service(db);

        var first = Ok(await service.GetSessionsAsync(juan.Id, 1, 2, null, null, null, default));
        Assert.Equal(3, first.Total);
        Assert.Equal(new[] { c.Id, b.Id }, first.Items.Select(i => i.Id).ToArray());

        var second = Ok(await service.GetSessionsAsync(juan.Id, 2, 2, null, null, null, default));
        Assert.Equal(new[] { a.Id }, second.Items.Select(i => i.Id).ToArray());

        var window = Ok(await service.GetSessionsAsync(juan.Id, 1, 20, Noon.AddDays(-2).AddHours(-1), Noon.AddDays(-2).AddHours(1), null, default));
        Assert.Equal(new[] { b.Id }, window.Items.Select(i => i.Id).ToArray());

        var gateOne = Ok(await service.GetSessionsAsync(juan.Id, 1, 20, null, null, 1, default));
        Assert.Equal(2, gateOne.Total);
    }

    [Fact]
    public async Task A_session_says_which_bay_and_whether_the_driver_confirmed_it()
    {
        var db = NewDb();
        var juan = Person(db, "Juan");
        var m3 = Bay(db, "M3");
        db.ParkingLogs.AddRange(
            Session(juan, m3, Noon.AddDays(-2), null, confirmed: true),
            Session(juan, m3, Noon.AddDays(-1), null, confirmed: false));
        await db.SaveChangesAsync();

        var page = Ok(await Service(db).GetSessionsAsync(juan.Id, 1, 20, null, null, null, default));

        Assert.All(page.Items, i => Assert.Equal("M3", i.SlotCode));
        Assert.False(page.Items[0].SlotConfirmed);
        Assert.True(page.Items[1].SlotConfirmed);
    }

    [Fact]
    public async Task A_violation_carries_the_bay_it_happened_in()
    {
        var db = NewDb();
        var juan = Person(db, "Juan");
        var m3 = Bay(db, "M3");
        var log = Session(juan, m3, Noon.AddHours(-3), Noon.AddHours(-1));
        var rule = new PolicyRule { Id = Guid.NewGuid(), Title = "Parked across two bays" };
        db.AddRange(log, rule);
        db.Set<Violation>().AddRange(
            new Violation { Id = Guid.NewGuid(), UserId = juan.Id, PolicyRuleId = rule.Id, ParkingLogId = log.Id, PenaltyAmount = 50m },
            new Violation { Id = Guid.NewGuid(), UserId = juan.Id, PolicyRuleId = rule.Id, PenaltyAmount = 20m });
        await db.SaveChangesAsync();

        var page = Ok(await Service(db).GetViolationsAsync(juan.Id, 1, 20, default));

        Assert.Equal(2, page.Total);
        Assert.Contains(page.Items, v => v.SlotCode == "M3" && v.RuleTitle == "Parked across two bays");
        Assert.Contains(page.Items, v => v.SlotCode is null);
    }

    [Fact]
    public async Task Possibly_involved_lists_reports_about_a_bay_the_person_was_in_when_it_was_reported()
    {
        var db = NewDb();
        var juan = Person(db, "Juan");
        var carlo = Person(db, "Carlo");
        var m3 = Bay(db, "M3");
        var m4 = Bay(db, "M4");

        db.ParkingLogs.Add(Session(juan, m3, Noon.AddHours(-2), null, confirmed: true));

        var inside = Report(carlo, m3, Noon);                      // he was parked there
        var elsewhere = Report(carlo, m4, Noon);                   // a different bay
        var before = Report(carlo, m3, Noon.AddHours(-5));         // reported before he arrived
        var own = Report(juan, m3, Noon);                          // his own report
        db.AddRange(inside, elsewhere, before, own);
        await db.SaveChangesAsync();

        var result = Ok(await Service(db).GetIncidentsAsync(juan.Id, default));

        var lead = Assert.Single(result.PossiblyInvolved);
        Assert.Equal(inside.Id, lead.Id);
        Assert.Equal("M3", lead.SlotCode);
        Assert.True(lead.InvolvedConfirmed);
        Assert.Equal(own.Id, Assert.Single(result.Filed).Id);
    }

    [Fact]
    public async Task A_session_that_ended_long_before_the_report_is_not_a_lead()
    {
        var db = NewDb();
        var juan = Person(db, "Juan");
        var carlo = Person(db, "Carlo");
        var m3 = Bay(db, "M3");
        db.ParkingLogs.Add(Session(juan, m3, Noon.AddHours(-20), Noon.AddHours(-18)));
        db.Add(Report(carlo, m3, Noon));
        await db.SaveChangesAsync();

        var result = Ok(await Service(db).GetIncidentsAsync(juan.Id, default));

        Assert.Empty(result.PossiblyInvolved);
    }

    [Fact]
    public async Task Payments_say_whether_a_bill_is_a_fine_or_parking()
    {
        var db = NewDb();
        var juan = Person(db, "Juan");
        var rule = new PolicyRule { Id = Guid.NewGuid(), Title = "Rule" };
        var violation = new Violation { Id = Guid.NewGuid(), UserId = juan.Id, PolicyRuleId = rule.Id };
        db.AddRange(rule, violation);
        db.Set<PaymentTransaction>().AddRange(
            new PaymentTransaction { Id = Guid.NewGuid(), UserId = juan.Id, ViolationId = violation.Id, AmountDue = 50m, CreatedAt = Noon },
            new PaymentTransaction { Id = Guid.NewGuid(), UserId = juan.Id, DurationMinutes = 125, AmountDue = 45m, CreatedAt = Noon.AddHours(-1) });
        await db.SaveChangesAsync();

        var page = Ok(await Service(db).GetPaymentsAsync(juan.Id, 1, 20, default));

        Assert.Equal("Violation fine", page.Items[0].For);
        Assert.Equal("Parking · 125 min", page.Items[1].For);
    }

    [Fact]
    public async Task An_unknown_user_is_not_found_everywhere()
    {
        var db = NewDb();
        var service = Service(db);
        var nobody = Guid.NewGuid();

        Assert.IsType<NotFoundObjectResult>((await service.GetSummaryAsync(nobody, default)).Result);
        Assert.IsType<NotFoundObjectResult>((await service.GetSessionsAsync(nobody, 1, 20, null, null, null, default)).Result);
        Assert.IsType<NotFoundObjectResult>((await service.GetViolationsAsync(nobody, 1, 20, default)).Result);
        Assert.IsType<NotFoundObjectResult>((await service.GetIncidentsAsync(nobody, default)).Result);
        Assert.IsType<NotFoundObjectResult>((await service.GetPaymentsAsync(nobody, 1, 20, default)).Result);
    }

    [Fact]
    public void The_involvement_window_reaches_back_six_hours_and_ends_at_the_report()
    {
        var report = Noon;

        Assert.True(IncidentInvolvement.Overlaps(report.AddHours(-1), null, report));
        Assert.True(IncidentInvolvement.Overlaps(report.AddHours(-9), report.AddHours(-6), report));
        Assert.False(IncidentInvolvement.Overlaps(report.AddHours(-9), report.AddHours(-6).AddMinutes(-1), report));
        Assert.False(IncidentInvolvement.Overlaps(report.AddMinutes(1), null, report));
    }
}
