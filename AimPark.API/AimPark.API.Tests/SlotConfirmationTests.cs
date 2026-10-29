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
    public async Task A_bay_in_the_other_column_is_still_accepted()
    {
        // The lot is one lane. The driver may be in any bay of their kind.
        var db = NewDb();
        var user = NewUser(db);
        var far = NewSlot(db, "M5", gate: 2);
        far.VehicleType = VehicleType.Motorcycle;
        var log = NewLog(db, user, DateTime.UtcNow.AddMinutes(-5));
        log.Gate = 1;
        log.VehicleType = VehicleType.Motorcycle;
        await db.SaveChangesAsync();

        var result = await Confirm(db, user.Id, log.Id, far.Id);

        Assert.Equal(SlotConfirmResult.Confirmed, result.Result);
    }

    [Theory]
    [InlineData(VehicleType.Motorcycle, VehicleType.Car)]
    [InlineData(VehicleType.Car, VehicleType.Motorcycle)]
    public async Task A_bay_for_the_other_kind_of_vehicle_is_refused(VehicleType cameIn, VehicleType bay)
    {
        var db = NewDb();
        var user = NewUser(db);
        var slot = NewSlot(db, "C5");
        slot.VehicleType = bay;
        var log = NewLog(db, user, DateTime.UtcNow.AddMinutes(-5));
        log.VehicleType = cameIn;
        await db.SaveChangesAsync();

        var result = await Confirm(db, user.Id, log.Id, slot.Id);

        Assert.Equal(SlotConfirmResult.WrongVehicleType, result.Result);
        Assert.Null((await db.Set<ParkingLog>().AsNoTracking().SingleAsync()).SlotConfirmedAt);
    }

    [Fact]
    public async Task With_one_kind_on_the_account_that_kind_is_what_came_in()
    {
        var db = NewDb();
        var user = NewUser(db);
        db.Add(new Vehicle { Id = Guid.NewGuid(), UserId = user.Id, PlateNumber = "123ABC", VehicleType = VehicleType.Motorcycle });
        var car = NewSlot(db, "C1");
        car.VehicleType = VehicleType.Car;
        var log = NewLog(db, user, DateTime.UtcNow.AddMinutes(-5));
        await db.SaveChangesAsync();

        var result = await Confirm(db, user.Id, log.Id, car.Id);

        Assert.Equal(SlotConfirmResult.WrongVehicleType, result.Result);
    }

    [Fact]
    public async Task With_both_kinds_and_no_plate_read_the_driver_must_say_which_one()
    {
        var db = NewDb();
        var user = NewUser(db);
        var moto = new Vehicle { Id = Guid.NewGuid(), UserId = user.Id, PlateNumber = "123ABC", VehicleType = VehicleType.Motorcycle };
        var sedan = new Vehicle { Id = Guid.NewGuid(), UserId = user.Id, PlateNumber = "XYZ789", VehicleType = VehicleType.Car };
        db.AddRange(moto, sedan);
        var bay = NewSlot(db, "M1");
        bay.VehicleType = VehicleType.Motorcycle;
        var log = NewLog(db, user, DateTime.UtcNow.AddMinutes(-5));
        await db.SaveChangesAsync();
        var service = new SlotConfirmationService(db);

        var unsaid = await Confirm(db, user.Id, log.Id, bay.Id);
        var withCar = await service.ConfirmAsync(user.Id,
            new ConfirmSlotRequest { LogId = log.Id, SlotId = bay.Id, VehicleId = sedan.Id }, default);
        var withMoto = await service.ConfirmAsync(user.Id,
            new ConfirmSlotRequest { LogId = log.Id, SlotId = bay.Id, VehicleId = moto.Id }, default);

        Assert.Equal(SlotConfirmResult.VehicleNeeded, unsaid.Result);
        Assert.Equal(SlotConfirmResult.WrongVehicleType, withCar.Result);
        Assert.Equal(SlotConfirmResult.Confirmed, withMoto.Result);
        // Kept, so the next bay check knows without asking again.
        Assert.Equal(VehicleType.Motorcycle, (await db.Set<ParkingLog>().AsNoTracking().SingleAsync()).VehicleType);
    }

    [Fact]
    public async Task What_the_gate_read_wins_over_the_vehicle_the_driver_names()
    {
        var db = NewDb();
        var user = NewUser(db);
        var sedan = new Vehicle { Id = Guid.NewGuid(), UserId = user.Id, PlateNumber = "XYZ789", VehicleType = VehicleType.Car };
        db.Add(sedan);
        var bay = NewSlot(db, "C1");
        bay.VehicleType = VehicleType.Car;
        var log = NewLog(db, user, DateTime.UtcNow.AddMinutes(-5));
        log.VehicleType = VehicleType.Motorcycle;
        await db.SaveChangesAsync();

        var result = await new SlotConfirmationService(db).ConfirmAsync(user.Id,
            new ConfirmSlotRequest { LogId = log.Id, SlotId = bay.Id, VehicleId = sedan.Id }, default);

        Assert.Equal(SlotConfirmResult.WrongVehicleType, result.Result);
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
    public async Task Changing_your_own_bay_replaces_the_earlier_confirmation()
    {
        var db = NewDb();
        var user = NewUser(db);
        var first = NewSlot(db, "M2");
        var second = NewSlot(db, "M3");
        var log = NewLog(db, user, DateTime.UtcNow.AddMinutes(-20), slot: first, confirmed: DateTime.UtcNow.AddMinutes(-15));
        await db.SaveChangesAsync();

        var result = await Confirm(db, user.Id, log.Id, second.Id);

        Assert.Equal(SlotConfirmResult.Confirmed, result.Result);
        Assert.Equal(second.Id, (await db.Set<ParkingLog>().AsNoTracking().SingleAsync()).SlotId);
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
