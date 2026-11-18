using AimPark.API.Data;
using AimPark.API.Entities;
using AimPark.API.Interfaces;
using AimPark.API.Services;
using AimPark.API.Sync.Cloud;
using Microsoft.EntityFrameworkCore;

namespace AimPark.API.Tests;

/// <summary>
/// The names on the parking map: only a driver who confirmed the bay. The
/// gate's suggestion is a guess, and a name on it points the guard at the
/// wrong car.
/// </summary>
public class BayOccupantsTests
{
    private static readonly DateTime Noon = new(2026, 11, 18, 4, 0, 0, DateTimeKind.Utc);

    [Fact]
    public async Task Lists_only_open_sessions_with_a_confirmed_bay()
    {
        var db = new AppDbContext(new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
        var user = new User { Id = Guid.NewGuid(), FullName = "Kim Enriquez", Email = $"{Guid.NewGuid()}@x.test" };
        var c1 = new ParkingSlot { Id = Guid.NewGuid(), SlotCode = "C1", Gate = 1 };
        var c2 = new ParkingSlot { Id = Guid.NewGuid(), SlotCode = "C2", Gate = 1 };
        db.AddRange(user, c1, c2);

        ParkingLog Log(ParkingSlot slot, DateTime? confirmed, DateTime? exit) => new()
        {
            Id = Guid.NewGuid(), UserId = user.Id, SlotId = slot.Id,
            EntryTime = Noon, ExitTime = exit, SlotConfirmedAt = confirmed, AlprPlateNumber = "RJJ231"
        };

        var confirmed = Log(c1, Noon.AddMinutes(2), null);
        var suggestedOnly = Log(c2, null, null);
        var left = Log(c1, Noon.AddMinutes(1), Noon.AddHours(1));
        db.ParkingLogs.AddRange(confirmed, suggestedOnly, left);
        await db.SaveChangesAsync();

        var parking = new ParkingHistoryService(
            new Repository<ParkingLog>(db), new Repository<ParkingSlot>(db),
            paymentService: null!, allocationService: null!, notificationService: null!, db, new NoSlotSensors());

        var occupants = await parking.ListBayOccupantsAsync(default);

        var only = Assert.Single(occupants);
        Assert.Equal(confirmed.Id, only.LogId);
        Assert.Equal("C1", only.SlotCode);
        Assert.Equal("Kim Enriquez", only.UserName);
        Assert.Equal("RJJ231", only.PlateNumber);
        Assert.NotNull(only.SlotConfirmedAt);
    }
}
