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
/// Working out which of a user's vehicles a parking session belongs to, from
/// the ALPR-confirmed plate alone — there's no VehicleId column on ParkingLog
/// (see its remarks for why), so this is recomputed every time history is
/// read rather than stored. See ParkingHistoryService.AttributeVehicle.
/// </summary>
public class VehicleAttributionTests
{
    private static AppDbContext NewDb() => new(new DbContextOptionsBuilder<AppDbContext>()
        .UseInMemoryDatabase(Guid.NewGuid().ToString())
        .Options);

    private static ParkingHistoryService Parking(AppDbContext db) => new(
        new Repository<ParkingLog>(db), new Repository<ParkingSlot>(db),
        paymentService: null!, allocationService: null!, notificationService: null!,
        db, new NoSlotSensors());

    private static Vehicle NewVehicle(Guid userId, string plate) => new()
    {
        Id = Guid.NewGuid(), UserId = userId, PlateNumber = plate, VehicleType = VehicleType.Car, Color = "White"
    };

    private static ParkingLog NewLog(Guid userId, string? alprPlate, DateTime? exitTime = null) => new()
    {
        Id = Guid.NewGuid(), UserId = userId, EntryTime = DateTime.UtcNow.AddHours(-1),
        ExitTime = exitTime, AlprPlateNumber = alprPlate
    };

    private static int Status(IConvertToActionResult result) =>
        result.Convert() is ObjectResult o ? o.StatusCode ?? 200 : 200;

    // ── AttributeVehicle (pure logic) ───────────────────────────────────────

    [Fact]
    public void AMatchedPlateIsAttributedToTheRightVehicle()
    {
        var vios = (Id: Guid.NewGuid(), Plate: "ABC123");
        var click = (Id: Guid.NewGuid(), Plate: "XYZ789");

        var attributed = ParkingHistoryService.AttributeVehicle("XYZ789", [vios, click]);

        Assert.Equal(click.Id, attributed);
    }

    [Fact]
    public void ANullPlateWithOneVehicleIsAttributedToIt()
    {
        var onlyCar = (Id: Guid.NewGuid(), Plate: "ABC123");

        var attributed = ParkingHistoryService.AttributeVehicle(null, [onlyCar]);

        Assert.Equal(onlyCar.Id, attributed);
    }

    [Fact]
    public void ANullPlateWithTwoVehiclesIsNotAttributed()
    {
        var vios = (Id: Guid.NewGuid(), Plate: "ABC123");
        var click = (Id: Guid.NewGuid(), Plate: "XYZ789");

        var attributed = ParkingHistoryService.AttributeVehicle(null, [vios, click]);

        Assert.Null(attributed);
    }

    [Fact]
    public void APlateThatMatchesNoVehicleIsNotAttributed()
    {
        var vios = (Id: Guid.NewGuid(), Plate: "ABC123");

        // The vehicle this plate belonged to has since been removed.
        var attributed = ParkingHistoryService.AttributeVehicle("GONE999", [vios]);

        Assert.Null(attributed);
    }

    // ── GetMyHistoryAsync's vehicleId filter ────────────────────────────────

    [Fact]
    public async Task TheVehicleFilterReturnsOnlyThatVehiclesLogsAndTheRightTotalCount()
    {
        var db = NewDb();
        var userId = Guid.NewGuid();
        var vios = NewVehicle(userId, "ABC123");
        var click = NewVehicle(userId, "XYZ789");
        db.vehicles.AddRange(vios, click);
        db.ParkingLogs.AddRange(
            NewLog(userId, "ABC123", DateTime.UtcNow),
            NewLog(userId, "ABC123", DateTime.UtcNow),
            NewLog(userId, "XYZ789", DateTime.UtcNow));
        await db.SaveChangesAsync();

        var result = await Parking(db).GetMyHistoryAsync(userId, vios.Id, page: 1, pageSize: 20, default);
        var body = (ParkingHistoryResponse)((OkObjectResult)result.Result!).Value!;

        Assert.Equal(2, body.TotalCount);
        Assert.All(body.Logs, l => Assert.Equal(vios.Id, l.VehicleId));
    }

    [Fact]
    public async Task APlatelessEntryCountsTowardTheOnlyVehicleOnFile()
    {
        var db = NewDb();
        var userId = Guid.NewGuid();
        var onlyCar = NewVehicle(userId, "ABC123");
        db.vehicles.Add(onlyCar);
        // A guard's manual log-entry stand-in never has a plate.
        db.ParkingLogs.Add(NewLog(userId, alprPlate: null, DateTime.UtcNow));
        await db.SaveChangesAsync();

        var result = await Parking(db).GetMyHistoryAsync(userId, onlyCar.Id, page: 1, pageSize: 20, default);
        var body = (ParkingHistoryResponse)((OkObjectResult)result.Result!).Value!;

        Assert.Equal(1, body.TotalCount);
        Assert.Equal(onlyCar.Id, body.Logs.Single().VehicleId);
    }

    [Fact]
    public async Task AnotherUsersVehicleIdIsNotFound()
    {
        var db = NewDb();
        var owner = Guid.NewGuid();
        var someoneElse = Guid.NewGuid();
        var vehicle = NewVehicle(owner, "ABC123");
        db.vehicles.Add(vehicle);
        await db.SaveChangesAsync();

        var result = await Parking(db).GetMyHistoryAsync(someoneElse, vehicle.Id, page: 1, pageSize: 20, default);

        Assert.Equal(404, Status(result));
    }
}
