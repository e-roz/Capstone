using AimPark.API.Enums;
using AimPark.API.Helpers;
using static AimPark.API.Helpers.WrongBayRule;

namespace AimPark.API.Tests;

public class WrongBayRuleTests
{
    private const VehicleType Car = VehicleType.Car;
    private const VehicleType Moto = VehicleType.Motorcycle;
    private const ParkingSlotStatus Free = ParkingSlotStatus.Available;
    private const ParkingSlotStatus Taken = ParkingSlotStatus.Occupied;

    private static readonly DateTime Now = new(2026, 10, 9, 8, 0, 0, DateTimeKind.Utc);

    // A small lot: two car bays (C1, C2) and two motorcycle bays (M1, M2).
    private static readonly Guid C1 = Guid.NewGuid(), C2 = Guid.NewGuid(), M1 = Guid.NewGuid(), M2 = Guid.NewGuid();

    private static List<Bay> Lot(
        ParkingSlotStatus c1 = Free, ParkingSlotStatus c2 = Free,
        ParkingSlotStatus m1 = Free, ParkingSlotStatus m2 = Free) =>
        [new(C1, Car, c1), new(C2, Car, c2), new(M1, Moto, m1), new(M2, Moto, m2)];

    private static Session In(VehicleType? type, Guid? given, int minutesAgo = 1) =>
        new(type, given, Now.AddMinutes(-minutesAgo));

    private static bool Warn(Guid bay, List<Bay> lot, params Session[] inside) =>
        ShouldWarn(lot.Single(b => b.Id == bay), lot, inside, Now);

    [Fact]
    public void ACarInItsOwnBayIsFine()
    {
        Assert.False(Warn(C1, Lot(c1: Taken), In(Car, C1)));
    }

    [Fact]
    public void ACarInAnotherCarBayIsFine()
    {
        // Given C1, parked in C2: the given bay is only a suggestion.
        Assert.False(Warn(C2, Lot(c2: Taken), In(Car, C1)));
    }

    [Fact]
    public void AMotorcycleInACarBayIsFlagged()
    {
        // Given M1, which is still empty; a car bay filled instead.
        Assert.True(Warn(C1, Lot(c1: Taken), In(Moto, M1)));
    }

    [Fact]
    public void ACarInAMotorcycleBayIsFlagged()
    {
        Assert.True(Warn(M1, Lot(m1: Taken), In(Car, C1)));
    }

    [Fact]
    public void AMotorcycleInACarBayIsFineWhenMotorcycleBaysAreFull()
    {
        Assert.False(Warn(C1, Lot(c1: Taken, m1: Taken, m2: Taken), In(Moto, null), In(Moto, M1), In(Moto, M2)));
    }

    [Fact]
    public void AMotorcycleTheGateSentToACarBayIsFine()
    {
        Assert.False(Warn(C1, Lot(c1: Taken), In(Moto, C1)));
    }

    [Fact]
    public void TooManyTakenBaysIsFlaggedEvenWithNobodyRecent()
    {
        // Two car bays taken, one car inside: something else is in one.
        Assert.True(Warn(C2, Lot(c1: Taken, c2: Taken), In(Car, C1, minutesAgo: 120)));
    }

    [Fact]
    public void ACarStillLookingForABayMakesItFine()
    {
        // A car and a motorcycle both just came in; the car bay that filled
        // is most likely the car's.
        Assert.False(Warn(C1, Lot(c1: Taken), In(Moto, M1), In(Car, C2)));
    }

    [Fact]
    public void AnUnknownVehicleNeverTipsIt()
    {
        // Has both kinds, no plate read: could be either, so no warning.
        Assert.False(Warn(C1, Lot(c1: Taken), In(null, M1)));
    }

    [Fact]
    public void AMotorcycleThatCameInLongAgoIsNotTheSuspect()
    {
        Assert.False(Warn(C1, Lot(c1: Taken), In(Car, null, minutesAgo: 120), In(Moto, M1, minutesAgo: 120)));
    }

    [Fact]
    public void AMotorcycleAlreadyInItsBayIsNotTheSuspect()
    {
        Assert.False(Warn(C2, Lot(c2: Taken, m1: Taken), In(Car, C1), In(Moto, M1)));
    }

    [Fact]
    public void AnyVehicleBaysAreNeverFlagged()
    {
        var any = Guid.NewGuid();
        List<Bay> lot = [.. Lot(), new(any, null, Taken)];
        Assert.False(Warn(any, lot, In(Moto, M1)));
    }
}
