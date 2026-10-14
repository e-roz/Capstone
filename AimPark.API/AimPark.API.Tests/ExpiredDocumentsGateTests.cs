using AimPark.API.Data;
using AimPark.API.DTOs;
using AimPark.API.Entities;
using AimPark.API.Enums;
using AimPark.API.Interfaces;
using AimPark.API.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Infrastructure;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;

namespace AimPark.API.Tests;

/// <summary>
/// An expired licence stops every vehicle of that driver at the entry gate, an
/// expired registration stops only its own vehicle, and nothing here ever stops
/// a driver leaving. All of it only bites when Gate:EnforceExpiredDocuments is on.
/// </summary>
public class ExpiredDocumentsGateTests
{
    private const string Tag = "04A2B3C4";

    private static readonly DateTime Expired = DateTime.UtcNow.AddDays(-5);
    private static readonly DateTime Valid = DateTime.UtcNow.AddDays(120);

    private sealed record Gate(AppDbContext Db, ParkingHistoryService Parking, User User, ParkingSlot Slot);

    private static AppDbContext NewDb() => new(new DbContextOptionsBuilder<AppDbContext>()
        .UseInMemoryDatabase(Guid.NewGuid().ToString())
        .Options);

    private static async Task<Gate> GateAsync(
        bool enforce, DateTime? licence = null, params Vehicle[] vehicles)
    {
        var db = NewDb();
        var user = new User
        {
            Id = Guid.NewGuid(), FullName = "Juan", Email = "j@x.test", RfidTagId = Tag,
            RfidStatus = RfidStatus.Active, Role = UserRole.User, AccountStatus = AccountStatus.Active,
            LicenseValidThrough = licence
        };
        var slot = new ParkingSlot { SlotCode = "A1", Status = ParkingSlotStatus.Available };
        db.AddRange(user, slot, new ParkingRate { VehicleType = null, RatePerHour = 30m });
        foreach (var v in vehicles)
        {
            v.UserId = user.Id;
            db.Add(v);
        }
        await db.SaveChangesAsync();

        var notifications = new QuietNotifications();
        var payments = new PaymentService(
            new Repository<PaymentTransaction>(db), new Repository<ParkingRate>(db),
            notifications, db, new NoGateway(), NullLogger<PaymentService>.Instance);

        var parking = new ParkingHistoryService(
            new Repository<ParkingLog>(db), new Repository<ParkingSlot>(db),
            payments, allocationService: null!, notifications, db, new NoSlotSensors(),
            entryDues: null,
            gate: Options.Create(new GateOptions { EnforceExpiredDocuments = enforce }));

        return new Gate(db, parking, user, slot);
    }

    private static Vehicle Car(string plate, DateTime? registration, bool eBike = false) => new()
    {
        PlateNumber = plate, VehicleType = VehicleType.Car, Color = "Black",
        RegistrationValidThrough = registration, IsEBike = eBike
    };

    private static Task<ActionResult<object>> EnterAsync(Gate g) =>
        g.Parking.LogEntryAsync(new LogParkingEntryDto { RfidTagId = Tag, SlotId = g.Slot.Id }, null, null, default);

    private static int Status(IConvertToActionResult r) =>
        r.Convert() is ObjectResult o ? o.StatusCode ?? 200 : 200;

    private static string Result(ActionResult<object> r)
    {
        var value = ((ObjectResult)r.Result!).Value!;
        return value.GetType().GetProperty("result")!.GetValue(value)!.ToString()!;
    }

    // ── The licence ────────────────────────────────────────────────────────

    [Fact]
    public async Task AnExpiredLicenceDeniesEntryWhenEnforced()
    {
        var g = await GateAsync(enforce: true, licence: Expired, Car("ABC1234", Valid));

        var result = await EnterAsync(g);

        Assert.Equal(400, Status(result));
        Assert.Equal("LICENSE_EXPIRED", Result(result));
        Assert.Empty(g.Db.ParkingLogs);
    }

    [Fact]
    public async Task AnExpiredLicenceOnlyWarnsWhenNotEnforced()
    {
        // The default. The check runs, but nobody is turned away.
        var g = await GateAsync(enforce: false, licence: Expired, Car("ABC1234", Valid));

        var result = await EnterAsync(g);

        Assert.Equal(200, Status(result));
        Assert.Single(g.Db.ParkingLogs);
    }

    [Fact]
    public async Task AValidLicenceLetsYouIn()
    {
        var g = await GateAsync(enforce: true, licence: Valid, Car("ABC1234", Valid));

        Assert.Equal(200, Status(await EnterAsync(g)));
    }

    [Fact]
    public async Task ALicenceWithNoDateOnFileIsNotRefused()
    {
        // Someone nobody could read a date from is a question for an admin, not
        // a reason to turn them away at the barrier.
        var g = await GateAsync(enforce: true, licence: null, Car("ABC1234", Valid));

        Assert.Equal(200, Status(await EnterAsync(g)));
    }

    [Fact]
    public async Task AnExpiredLicenceStopsEveryVehicleOfThatDriver()
    {
        var g = await GateAsync(
            enforce: true, licence: Expired, Car("ABC1234", Valid), Car("XYZ9876", Valid));

        Assert.Equal("LICENSE_EXPIRED", Result(await EnterAsync(g)));
    }

    // ── The registration ───────────────────────────────────────────────────

    [Fact]
    public async Task AnExpiredRegistrationDeniesTheOnlyVehicle()
    {
        var g = await GateAsync(enforce: true, licence: Valid, Car("ABC1234", Expired));

        var result = await EnterAsync(g);

        Assert.Equal(400, Status(result));
        Assert.Equal("REGISTRATION_EXPIRED", Result(result));
        Assert.Empty(g.Db.ParkingLogs);
    }

    [Fact]
    public async Task AnExpiredRegistrationOnlyWarnsWhenNotEnforced()
    {
        var g = await GateAsync(enforce: false, licence: Valid, Car("ABC1234", Expired));

        Assert.Equal(200, Status(await EnterAsync(g)));
    }

    [Fact]
    public async Task WithTwoVehiclesAndNoCameraReadTheRegistrationIsNotGuessedAt()
    {
        // The card alone does not say which vehicle is at the barrier. Refusing on
        // a guess would turn away the one with a valid registration.
        var g = await GateAsync(
            enforce: true, licence: Valid, Car("ABC1234", Expired), Car("XYZ9876", Valid));

        Assert.Equal(200, Status(await EnterAsync(g)));
    }

    [Fact]
    public async Task AnEBikeHasNoRegistrationToExpire()
    {
        var g = await GateAsync(enforce: true, licence: Valid, Car("EB0001", Expired, eBike: true));

        Assert.Equal(200, Status(await EnterAsync(g)));
    }

    // ── Leaving ────────────────────────────────────────────────────────────

    [Fact]
    public async Task AnExpiredLicenceNeverStopsYouLeaving()
    {
        var g = await GateAsync(enforce: true, licence: Expired, Car("ABC1234", Valid));
        g.Slot.Status = ParkingSlotStatus.Occupied;
        g.Db.Add(new ParkingLog
        {
            UserId = g.User.Id, SlotId = g.Slot.Id, EntryTime = DateTime.UtcNow.AddMinutes(-90)
        });
        await g.Db.SaveChangesAsync();

        var result = await g.Parking.LogExitAsync(new LogParkingExitDto { RfidTagId = Tag }, null, null, default);

        Assert.Equal(200, Status(result));
        Assert.Equal("EXIT_LOGGED", Result(result));
        Assert.NotNull((await g.Db.ParkingLogs.SingleAsync()).ExitTime);
    }

    // ── Stubs ──────────────────────────────────────────────────────────────

    private sealed class NoGateway : IPaymentGateway
    {
        public string Name => "None";

        public Task<GatewayCheckout> CreateCheckoutAsync(
            PaymentTransaction payment, string description, CancellationToken ct = default) =>
            throw new NotImplementedException();

        public Task<GatewayCheckout> CreateBundleCheckoutAsync(
            IReadOnlyList<PaymentTransaction> payments, CancellationToken ct = default) =>
            throw new NotImplementedException();

        public bool TryReadEvent(string rawBody, IDictionary<string, string> headers, out GatewayEvent gatewayEvent)
        {
            gatewayEvent = null!;
            return false;
        }
    }

    private sealed class QuietNotifications : INotificationService
    {
        public Task NotifyUserAsync(Guid userId, NotificationType type, string title, string message,
            IDictionary<string, string>? data, CancellationToken ct) => Task.CompletedTask;

        public Task<ActionResult<object>> BroadcastAsync(BroadcastNotificationDto dto, Guid adminUserId, CancellationToken ct) => throw new NotImplementedException();
        public Task NotifyRoleAsync(UserRole role, NotificationType type, string title, string message, CancellationToken ct) => throw new NotImplementedException();
        public Task<ActionResult<NotificationListResponse>> ListAllAsync(int page, int pageSize, CancellationToken ct) => throw new NotImplementedException();
        public Task<ActionResult<NotificationListResponse>> ListForUserAsync(Guid userId, UserRole role, int page, int pageSize, CancellationToken ct) => throw new NotImplementedException();
        public Task<ActionResult<object>> MarkReadAsync(Guid userId, Guid notificationId, CancellationToken ct) => throw new NotImplementedException();
        public Task<ActionResult<object>> MarkAllReadAsync(Guid userId, UserRole role, CancellationToken ct) => throw new NotImplementedException();
    }
}
