using AimPark.API.Data;
using AimPark.API.DTOs;
using AimPark.API.Entities;
using AimPark.API.Enums;
using AimPark.API.Interfaces;
using AimPark.API.Services;
using AimPark.API.Sync.Cloud;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace AimPark.API.Tests;

/// <summary>
/// A driver says which bay they parked in. The sensors never do this for them,
/// so these pin down who may confirm what, and that the word survives the
/// site server sending the session again.
/// </summary>
public class SlotConfirmationTests
{
    // 11:00 in Manila, so a few hours either side stays on the same day there.
    private static readonly DateTime Now = new(2026, 10, 20, 3, 0, 0, DateTimeKind.Utc);

    private static AppDbContext NewDb() => new(new DbContextOptionsBuilder<AppDbContext>()
        .UseInMemoryDatabase(Guid.NewGuid().ToString())
        .Options);

    private static User NewUser(AppDbContext db)
    {
        var user = new User { Id = Guid.NewGuid(), FullName = "Juan Cruz", Email = $"{Guid.NewGuid()}@x.test" };
        db.Add(user);
        return user;
    }

    private static ParkingSlot NewSlot(AppDbContext db, string code, int gate = 1)
    {
        var slot = new ParkingSlot { Id = Guid.NewGuid(), SlotCode = code, Gate = gate };
        db.Add(slot);
        return slot;
    }

    private static ParkingLog NewLog(AppDbContext db, User user, DateTime entry, DateTime? exit = null,
        ParkingSlot? slot = null, DateTime? confirmed = null)
    {
        var log = new ParkingLog
        {
            Id = Guid.NewGuid(),
            UserId = user.Id,
            SlotId = slot?.Id,
            EntryTime = entry,
            ExitTime = exit,
            SlotConfirmedAt = confirmed,
        };
        db.Add(log);
        return log;
    }

    private static Task<ConfirmSlotResponse> Confirm(AppDbContext db, Guid userId, Guid logId, Guid slotId)
        => new SlotConfirmationService(db).ConfirmAsync(
            userId, new ConfirmSlotRequest { LogId = logId, SlotId = slotId }, CancellationToken.None);

    [Fact]
    public async Task Confirming_an_open_session_stores_the_bay_and_the_time()
    {
        var db = NewDb();
        var user = NewUser(db);
        var suggested = NewSlot(db, "M1");
        var parked = NewSlot(db, "M2");
        var log = NewLog(db, user, DateTime.UtcNow.AddMinutes(-20), slot: suggested);
        await db.SaveChangesAsync();

        var result = await Confirm(db, user.Id, log.Id, parked.Id);

        Assert.Equal(SlotConfirmResult.Confirmed, result.Result);
        Assert.Equal("M2", result.SlotCode);
        Assert.False(result.Late);
        var saved = await db.Set<ParkingLog>().AsNoTracking().SingleAsync();
        Assert.Equal(parked.Id, saved.SlotId);
        Assert.NotNull(saved.SlotConfirmedAt);
    }

    [Fact]
    public async Task Confirming_never_changes_what_the_sensors_say_about_the_bay()
    {
        var db = NewDb();
        var user = NewUser(db);
        var parked = NewSlot(db, "M2");
        parked.Status = ParkingSlotStatus.Available;
        var log = NewLog(db, user, DateTime.UtcNow.AddMinutes(-5));
        await db.SaveChangesAsync();

        await Confirm(db, user.Id, log.Id, parked.Id);

        Assert.Equal(ParkingSlotStatus.Available, (await db.Set<ParkingSlot>().AsNoTracking().SingleAsync()).Status);
    }

    [Fact]
    public async Task Someone_elses_session_is_not_found()
    {
        var db = NewDb();
        var owner = NewUser(db);
        var other = NewUser(db);
        var slot = NewSlot(db, "M2");
        var log = NewLog(db, owner, DateTime.UtcNow.AddMinutes(-5));
        await db.SaveChangesAsync();

        var result = await Confirm(db, other.Id, log.Id, slot.Id);

        Assert.Equal(SlotConfirmResult.LogNotFound, result.Result);
        Assert.Null((await db.Set<ParkingLog>().AsNoTracking().SingleAsync()).SlotConfirmedAt);
    }

    [Fact]
    public async Task A_bay_that_does_not_exist_is_refused()
    {
        var db = NewDb();
        var user = NewUser(db);
        var log = NewLog(db, user, DateTime.UtcNow.AddMinutes(-5));
        await db.SaveChangesAsync();

        var result = await Confirm(db, user.Id, log.Id, Guid.NewGuid());

        Assert.Equal(SlotConfirmResult.SlotNotFound, result.Result);
    }

    [Fact]
    public async Task A_bay_in_the_other_column_or_of_the_other_kind_is_still_accepted()
    {
        // The lot is one lane. The driver may be in any bay; the sensors flag a
        // wrong kind on their own, and refusing would stop the truth being told.
        var db = NewDb();
        var user = NewUser(db);
        var far = NewSlot(db, "C5", gate: 2);
        far.VehicleType = VehicleType.Car;
        var log = NewLog(db, user, DateTime.UtcNow.AddMinutes(-5));
        log.Gate = 1;
        log.VehicleType = VehicleType.Motorcycle;
        await db.SaveChangesAsync();

        var result = await Confirm(db, user.Id, log.Id, far.Id);

        Assert.Equal(SlotConfirmResult.Confirmed, result.Result);
    }

    [Fact]
    public async Task A_bay_another_driver_has_confirmed_at_the_same_time_is_refused()
    {
        var db = NewDb();
        var first = NewUser(db);
        var second = NewUser(db);
        var bay = NewSlot(db, "M2");
        NewLog(db, first, DateTime.UtcNow.AddMinutes(-30), slot: bay, confirmed: DateTime.UtcNow.AddMinutes(-25));
        var mine = NewLog(db, second, DateTime.UtcNow.AddMinutes(-5));
        await db.SaveChangesAsync();

        var result = await Confirm(db, second.Id, mine.Id, bay.Id);

        Assert.Equal(SlotConfirmResult.SlotTaken, result.Result);
        Assert.Null((await db.Set<ParkingLog>().AsNoTracking().SingleAsync(l => l.Id == mine.Id)).SlotConfirmedAt);
    }

    [Fact]
    public async Task A_bay_someone_confirmed_earlier_and_left_can_be_confirmed_again()
    {
        var db = NewDb();
        var first = NewUser(db);
        var second = NewUser(db);
        var bay = NewSlot(db, "M2");
        NewLog(db, first, DateTime.UtcNow.AddHours(-3), DateTime.UtcNow.AddHours(-2),
            slot: bay, confirmed: DateTime.UtcNow.AddHours(-3));
        var mine = NewLog(db, second, DateTime.UtcNow.AddMinutes(-5));
        await db.SaveChangesAsync();

        var result = await Confirm(db, second.Id, mine.Id, bay.Id);

        Assert.Equal(SlotConfirmResult.Confirmed, result.Result);
    }

    [Fact]
    public async Task A_confirmed_bay_is_final_for_the_driver()
    {
        var db = NewDb();
        var user = NewUser(db);
        var first = NewSlot(db, "M2");
        var second = NewSlot(db, "M3");
        var confirmedAt = DateTime.UtcNow.AddMinutes(-15);
        var log = NewLog(db, user, DateTime.UtcNow.AddMinutes(-20), slot: first, confirmed: confirmedAt);
        await db.SaveChangesAsync();

        var result = await Confirm(db, user.Id, log.Id, second.Id);

        Assert.Equal(SlotConfirmResult.AlreadyConfirmed, result.Result);
        Assert.Contains("M2", result.Message);
        var saved = await db.Set<ParkingLog>().AsNoTracking().SingleAsync();
        Assert.Equal(first.Id, saved.SlotId);
        Assert.Equal(confirmedAt, saved.SlotConfirmedAt);
    }

    // ---- an admin correcting a confirm ----------------------------------

    private static Task<CorrectBayResponse> Correct(AppDbContext db, Guid adminId, Guid logId, Guid slotId, string reason = "Car seen in the other bay")
        => new SlotConfirmationService(db).CorrectAsync(
            adminId, logId, new CorrectBayRequest { SlotId = slotId, Reason = reason }, CancellationToken.None);

    [Fact]
    public async Task An_admin_correction_moves_the_bay_and_keeps_the_drivers_answer()
    {
        var db = NewDb();
        var user = NewUser(db);
        var admin = NewUser(db);
        var said = NewSlot(db, "C3");
        var real = NewSlot(db, "C2");
        var confirmedAt = DateTime.UtcNow.AddMinutes(-15);
        var log = NewLog(db, user, DateTime.UtcNow.AddMinutes(-20), slot: said, confirmed: confirmedAt);
        await db.SaveChangesAsync();

        var result = await Correct(db, admin.Id, log.Id, real.Id);

        Assert.Equal(BayCorrectResult.Corrected, result.Result);
        var saved = await db.Set<ParkingLog>().AsNoTracking().SingleAsync();
        Assert.Equal(real.Id, saved.SlotId);
        Assert.Equal(confirmedAt, saved.SlotConfirmedAt);
        var correction = await db.Set<SlotConfirmCorrection>().AsNoTracking().SingleAsync();
        Assert.Equal(said.Id, correction.FromSlotId);
        Assert.Equal(real.Id, correction.ToSlotId);
        Assert.Equal(admin.Id, correction.CorrectedByUserId);
        Assert.Equal("Car seen in the other bay", correction.Reason);
        var audit = await db.Set<AdminAuditLog>().AsNoTracking().SingleAsync();
        Assert.Equal(user.Id, audit.TargetUserId);
        Assert.Equal("C3", audit.OldValue);
        Assert.Equal("C2", audit.NewValue);

        var history = await new SlotConfirmationService(db).GetHistoryAsync(log.Id, CancellationToken.None);
        Assert.NotNull(history);
        Assert.Equal("C3", history!.DriverSlotCode);
        Assert.Equal("C2", history.CurrentSlotCode);
        var item = Assert.Single(history.Corrections);
        Assert.Equal("C3", item.FromSlotCode);
        Assert.Equal("C2", item.ToSlotCode);
    }

    [Fact]
    public async Task A_correction_needs_a_reason_and_a_confirmed_session()
    {
        var db = NewDb();
        var user = NewUser(db);
        var admin = NewUser(db);
        var bay = NewSlot(db, "C3");
        var other = NewSlot(db, "C2");
        var confirmed = NewLog(db, user, DateTime.UtcNow.AddMinutes(-20), slot: bay, confirmed: DateTime.UtcNow.AddMinutes(-15));
        var unconfirmed = NewLog(db, user, DateTime.UtcNow.AddHours(-3), DateTime.UtcNow.AddHours(-2), slot: bay);
        await db.SaveChangesAsync();

        Assert.Equal(BayCorrectResult.ReasonRequired, (await Correct(db, admin.Id, confirmed.Id, other.Id, "  ")).Result);
        Assert.Equal(BayCorrectResult.NotConfirmed, (await Correct(db, admin.Id, unconfirmed.Id, other.Id)).Result);
        Assert.Equal(BayCorrectResult.SameBay, (await Correct(db, admin.Id, confirmed.Id, bay.Id)).Result);
        Assert.Empty(await db.Set<SlotConfirmCorrection>().ToListAsync());
    }

    [Fact]
    public async Task A_correction_into_a_bay_another_driver_confirmed_at_the_same_time_is_refused()
    {
        var db = NewDb();
        var user = NewUser(db);
        var other = NewUser(db);
        var admin = NewUser(db);
        var said = NewSlot(db, "C3");
        var taken = NewSlot(db, "C2");
        var log = NewLog(db, user, DateTime.UtcNow.AddMinutes(-20), slot: said, confirmed: DateTime.UtcNow.AddMinutes(-15));
        NewLog(db, other, DateTime.UtcNow.AddMinutes(-30), slot: taken, confirmed: DateTime.UtcNow.AddMinutes(-25));
        await db.SaveChangesAsync();

        var result = await Correct(db, admin.Id, log.Id, taken.Id);

        Assert.Equal(BayCorrectResult.SlotTaken, result.Result);
        Assert.Equal(said.Id, (await db.Set<ParkingLog>().AsNoTracking().SingleAsync(l => l.Id == log.Id)).SlotId);
    }

    // ---- where a session stands --------------------------------------------

    [Fact]
    public void A_sessions_confirm_state_follows_the_rules()
    {
        var user = Guid.NewGuid();
        var entry = Now.AddHours(-2);

        Assert.Equal(BayConfirmState.NotYet, SlotConfirmPolicy.StateOf(user, entry, null, null));
        Assert.Equal(BayConfirmState.Unconfirmed, SlotConfirmPolicy.StateOf(user, entry, entry.AddHours(1), null));
        Assert.Equal(BayConfirmState.Confirmed, SlotConfirmPolicy.StateOf(user, entry, entry.AddHours(1), entry.AddMinutes(5)));
        Assert.Equal(BayConfirmState.ConfirmedLate, SlotConfirmPolicy.StateOf(user, entry, entry.AddHours(1), entry.AddHours(2)));
        // A visitor has no app; a short stay never really parked.
        Assert.Equal(BayConfirmState.NotCounted, SlotConfirmPolicy.StateOf(null, entry, entry.AddHours(1), null));
        Assert.Equal(BayConfirmState.NotCounted, SlotConfirmPolicy.StateOf(user, entry, entry.AddMinutes(5), null));
    }

    [Fact]
    public async Task After_leaving_the_same_day_a_confirm_is_accepted_and_marked_late()
    {
        var db = NewDb();
        var user = NewUser(db);
        var bay = NewSlot(db, "M2");
        // Came in and left within the last few minutes: same Manila day as now.
        var log = NewLog(db, user, DateTime.UtcNow.AddMinutes(-2), DateTime.UtcNow.AddMinutes(-1));
        await db.SaveChangesAsync();

        var result = await Confirm(db, user.Id, log.Id, bay.Id);

        Assert.Equal(SlotConfirmResult.Confirmed, result.Result);
        Assert.True(result.Late);
    }

    [Fact]
    public async Task After_leaving_on_an_earlier_day_a_confirm_is_too_late()
    {
        var db = NewDb();
        var user = NewUser(db);
        var bay = NewSlot(db, "M2");
        var log = NewLog(db, user, DateTime.UtcNow.AddDays(-2), DateTime.UtcNow.AddDays(-2).AddHours(1));
        await db.SaveChangesAsync();

        var result = await Confirm(db, user.Id, log.Id, bay.Id);

        Assert.Equal(SlotConfirmResult.TooLate, result.Result);
    }

    [Fact]
    public async Task The_site_servers_copy_does_not_wipe_the_drivers_confirmation()
    {
        var db = NewDb();
        var user = NewUser(db);
        var bay = NewSlot(db, "M2");
        var suggested = NewSlot(db, "M1");
        var cloud = NewLog(db, user, Now, slot: bay, confirmed: Now.AddMinutes(5));
        await db.SaveChangesAsync();

        // What the site sends when the session closes: the gate's own suggestion,
        // no confirmation, and the exit time.
        var fromSite = new ParkingLog
        {
            Id = cloud.Id,
            UserId = user.Id,
            SlotId = suggested.Id,
            EntryTime = Now,
            ExitTime = Now.AddHours(2),
        };
        EventIngestor.MergeParkingLog(db, cloud, fromSite);
        await db.SaveChangesAsync();

        var saved = await db.Set<ParkingLog>().AsNoTracking().SingleAsync();
        Assert.Equal(bay.Id, saved.SlotId);
        Assert.Equal(Now.AddMinutes(5), saved.SlotConfirmedAt);
        Assert.Equal(Now.AddHours(2), saved.ExitTime);
    }

    [Fact]
    public async Task The_site_servers_copy_still_updates_a_session_nobody_confirmed()
    {
        var db = NewDb();
        var user = NewUser(db);
        var suggested = NewSlot(db, "M1");
        var other = NewSlot(db, "M4");
        var cloud = NewLog(db, user, Now, slot: suggested);
        await db.SaveChangesAsync();

        var fromSite = new ParkingLog
        {
            Id = cloud.Id,
            UserId = user.Id,
            SlotId = other.Id,
            EntryTime = Now,
            ExitTime = Now.AddHours(1),
        };
        EventIngestor.MergeParkingLog(db, cloud, fromSite);
        await db.SaveChangesAsync();

        var saved = await db.Set<ParkingLog>().AsNoTracking().SingleAsync();
        Assert.Equal(other.Id, saved.SlotId);
        Assert.Null(saved.SlotConfirmedAt);
    }

    // ---- the reminder --------------------------------------------------

    [Fact]
    public async Task A_driver_still_unconfirmed_after_ten_minutes_is_reminded_once()
    {
        var db = NewDb();
        var user = NewUser(db);
        var log = NewLog(db, user, Now.AddMinutes(-11));
        await db.SaveChangesAsync();
        var notices = new Recorder(db);

        var first = await SlotConfirmReminderService.RemindAsync(db, notices, Now, CancellationToken.None);
        var second = await SlotConfirmReminderService.RemindAsync(db, notices, Now.AddMinutes(1), CancellationToken.None);

        Assert.Equal(1, first);
        Assert.Equal(0, second);
        var sent = Assert.Single(notices.Sent);
        Assert.Equal(user.Id, sent.UserId);
        Assert.Equal("parking-slots", sent.Data!["screen"]);
        Assert.Equal(log.Id.ToString(), sent.Data["logId"]);
    }

    [Fact]
    public async Task Nobody_is_reminded_too_early_or_after_confirming_or_after_leaving_or_when_stale()
    {
        var db = NewDb();
        var user = NewUser(db);
        var bay = NewSlot(db, "M2");
        NewLog(db, user, Now.AddMinutes(-5));                                          // too early
        NewLog(db, user, Now.AddMinutes(-30), slot: bay, confirmed: Now.AddMinutes(-20)); // already said
        NewLog(db, user, Now.AddMinutes(-30), Now.AddMinutes(-10));                     // already left
        NewLog(db, user, Now.AddHours(-9));                                             // stale
        await db.SaveChangesAsync();

        var sent = await SlotConfirmReminderService.RemindAsync(db, new Recorder(db), Now, CancellationToken.None);

        Assert.Equal(0, sent);
    }

    // ---- leaving without confirming, again and again --------------------

    private static readonly SlotConfirmPolicyOptions Policy = new()
    {
        CountFrom = Now.AddDays(-60),
        StrikesFrom = Now.AddDays(-60),
    };

    /// <summary>One unconfirmed hour-long visit a day, starting <paramref name="daysAgo"/> days back.</summary>
    private static void UnconfirmedVisits(AppDbContext db, User user, int count, int daysAgo = 1)
    {
        for (var i = 0; i < count; i++)
        {
            var entry = Now.AddDays(-(daysAgo + i));
            NewLog(db, user, entry, entry.AddHours(1));
        }
    }

    [Fact]
    public async Task Three_unconfirmed_visits_bring_one_warning()
    {
        var db = NewDb();
        var user = NewUser(db);
        UnconfirmedVisits(db, user, 3);
        await db.SaveChangesAsync();
        var notices = new Recorder(db);
        var staff = new StaffRecorder();

        var first = await UnconfirmedParkingService.RunAsync(db, notices, staff, Policy, Now, CancellationToken.None);
        var second = await UnconfirmedParkingService.RunAsync(db, notices, staff, Policy, Now.AddHours(1), CancellationToken.None);

        Assert.Equal((1, 0), first);
        Assert.Equal((0, 0), second);
        Assert.Equal("UnconfirmedWarning", Assert.Single(notices.Sent).Data!["kind"]);
        Assert.Empty(staff.Raised);
    }

    [Fact]
    public async Task Five_unconfirmed_visits_go_to_an_admin_once_strikes_have_started()
    {
        var db = NewDb();
        var user = NewUser(db);
        UnconfirmedVisits(db, user, 5);
        await db.SaveChangesAsync();
        var staff = new StaffRecorder();

        var graceOnly = new SlotConfirmPolicyOptions { CountFrom = Policy.CountFrom, StrikesFrom = Now.AddDays(1) };
        var inGrace = await UnconfirmedParkingService.RunAsync(db, new Recorder(db), staff, graceOnly, Now, CancellationToken.None);
        Assert.Equal((1, 0), inGrace);
        Assert.Empty(staff.Raised);

        var after = await UnconfirmedParkingService.RunAsync(db, new Recorder(db), staff, Policy, Now, CancellationToken.None);
        Assert.Equal((0, 1), after);
        Assert.Equal((StaffAlertKind.UnconfirmedParking, user.Id), Assert.Single(staff.Raised));
    }

    [Fact]
    public async Task Confirmed_short_visitor_todays_and_old_visits_are_not_counted()
    {
        var db = NewDb();
        var user = NewUser(db);
        var bay = NewSlot(db, "C1");
        var day = Now.AddDays(-2);
        NewLog(db, user, day, day.AddHours(1), slot: bay, confirmed: day.AddMinutes(5)); // confirmed
        NewLog(db, user, day, day.AddHours(1), slot: bay, confirmed: day.AddHours(2));   // confirmed late
        NewLog(db, user, day, day.AddMinutes(5));                                        // short stay
        NewLog(db, user, Now.AddHours(-2), Now.AddHours(-1));                            // today: can still confirm
        NewLog(db, user, Now.AddDays(-40), Now.AddDays(-40).AddHours(1));                // outside the window
        db.Add(new ParkingLog { Id = Guid.NewGuid(), EntryTime = day, ExitTime = day.AddHours(1), VisitorPassId = Guid.NewGuid() });
        await db.SaveChangesAsync();

        var counts = await UnconfirmedParkingService.CountAsync(db, Policy, Now, CancellationToken.None);

        Assert.Empty(counts);
    }

    [Fact]
    public async Task Nothing_counts_before_the_policy_starts()
    {
        var db = NewDb();
        var user = NewUser(db);
        UnconfirmedVisits(db, user, 5);
        await db.SaveChangesAsync();

        var off = await UnconfirmedParkingService.CountAsync(db, new SlotConfirmPolicyOptions(), Now, CancellationToken.None);
        var notYet = await UnconfirmedParkingService.CountAsync(db, new SlotConfirmPolicyOptions { CountFrom = Now }, Now, CancellationToken.None);

        Assert.Empty(off);
        Assert.Empty(notYet);
    }

    private sealed class StaffRecorder : IStaffAlerts
    {
        public List<(StaffAlertKind Kind, Guid UserId)> Raised { get; } = [];

        public Task RaiseAsync(StaffAlertKind kind, Guid aboutUserId, CancellationToken ct)
        {
            Raised.Add((kind, aboutUserId));
            return Task.CompletedTask;
        }
    }

    /// <summary>Writes the notification row the way the real service does, so the "already sent" check has something to find.</summary>
    private sealed class Recorder(AppDbContext db) : INotificationService
    {
        public List<(Guid UserId, IDictionary<string, string>? Data)> Sent { get; } = [];

        public async Task NotifyUserAsync(Guid userId, NotificationType type, string title, string message,
            IDictionary<string, string>? data, CancellationToken ct)
        {
            Sent.Add((userId, data));
            db.Add(new Notification
            {
                TargetUserId = userId,
                Type = type,
                Title = title,
                Message = message,
                Data = data is null ? null : System.Text.Json.JsonSerializer.Serialize(data),
            });
            await db.SaveChangesAsync(ct);
        }

        public Task<ActionResult<object>> BroadcastAsync(BroadcastNotificationDto dto, Guid adminUserId, CancellationToken ct) => throw new NotImplementedException();
        public Task NotifyRoleAsync(UserRole role, NotificationType type, string title, string message, CancellationToken ct) => throw new NotImplementedException();
        public Task<ActionResult<NotificationListResponse>> ListAllAsync(int page, int pageSize, CancellationToken ct) => throw new NotImplementedException();
        public Task<ActionResult<NotificationListResponse>> ListSystemAsync(DateTime? from, DateTime? to, int take, CancellationToken ct) => throw new NotImplementedException();
        public Task<ActionResult<NotificationListResponse>> ListForUserAsync(Guid userId, UserRole role, int page, int pageSize, CancellationToken ct) => throw new NotImplementedException();
        public Task<ActionResult<object>> MarkReadAsync(Guid userId, Guid notificationId, CancellationToken ct) => throw new NotImplementedException();
        public Task<ActionResult<object>> MarkAllReadAsync(Guid userId, UserRole role, CancellationToken ct) => throw new NotImplementedException();
    }
}
