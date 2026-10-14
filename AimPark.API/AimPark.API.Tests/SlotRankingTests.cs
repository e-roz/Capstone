using AimPark.API.Data;
using AimPark.API.Entities;
using AimPark.API.Enums;
using AimPark.API.Helpers;
using AimPark.API.Services;

namespace AimPark.API.Tests;

public class SlotRankingTests
{
    private static readonly DateTime Now = new(2026, 10, 14, 8, 0, 0, DateTimeKind.Utc);

    // The real 18-bay lot, every bay free and long since vacated.
    private static List<ParkingSlot> Lot(VehicleType type, params string[] taken) =>
        [.. ParkingSlotSeed.GetSeedSlots()
            .Where(s => s.VehicleType == type && !taken.Contains(s.SlotCode))];

    private static List<string> Order(VehicleType type, int gate, params string[] taken) =>
        [.. ParkingAllocationService.Rank(Lot(type, taken), gate, Now).Select(s => s.SlotCode)];

    [Fact]
    public void AMotorcycleAtGate1GetsTheBayRightAtGate1()
    {
        Assert.Equal(["M12", "M11", "M10"], Order(VehicleType.Motorcycle, gate: 1).Take(3));
    }

    [Fact]
    public void AMotorcycleAtGate2GetsTheBayRightAtGate2()
    {
        Assert.Equal(["M6", "M5", "M4"], Order(VehicleType.Motorcycle, gate: 2).Take(3));
    }

    [Fact]
    public void BaysTheSameDistanceAwayGoToTheLowerNumber()
    {
        // M1 and M9 are both row 4; M3 and M7 both row 6.
        Assert.Equal(["M1", "M9"], Order(VehicleType.Motorcycle, gate: 1).Skip(3).Take(2));
        Assert.Equal(["M3", "M7"], Order(VehicleType.Motorcycle, gate: 2).Skip(3).Take(2));
    }

    [Fact]
    public void SlotNumbersCompareAsNumbersNotText()
    {
        // As text, "M10" sorts before "M7".
        Assert.True(LotLayout.NumberOf("M7") < LotLayout.NumberOf("M10"));
    }

    [Fact]
    public void CarsGoToTheCarBaysNearestTheirGate()
    {
        Assert.Equal("C1", Order(VehicleType.Car, gate: 1)[0]);
        Assert.Equal("C4", Order(VehicleType.Car, gate: 2)[0]);
    }

    [Fact]
    public void WhenTheNearBaysAreTakenTheNextNearestIsGiven()
    {
        Assert.Equal("M4", Order(VehicleType.Motorcycle, gate: 2, "M6", "M5")[0]);
    }

    [Fact]
    public void TheLastFreeBayIsGivenFromEitherGate()
    {
        var allButM8 = Lot(VehicleType.Motorcycle).Select(s => s.SlotCode).Where(c => c != "M8").ToArray();

        Assert.Equal(["M8"], Order(VehicleType.Motorcycle, gate: 1, allButM8));
        Assert.Equal(["M8"], Order(VehicleType.Motorcycle, gate: 2, allButM8));
    }

    [Fact]
    public void ABayJustVacatedIsOfferedLast()
    {
        var lot = Lot(VehicleType.Motorcycle);
        lot.Single(s => s.SlotCode == "M6").UpdatedAt = Now.AddSeconds(-30);

        var order = ParkingAllocationService.Rank(lot, 2, Now).Select(s => s.SlotCode).ToList();

        Assert.Equal("M5", order[0]);
        Assert.Equal("M6", order[^1]);
    }

    [Fact]
    public void TheAppSendsTheDriverToTheGateWithTheNearestFreeBay()
    {
        // Both motorcycle bays at Gate 1's end are taken; Gate 2's are not.
        var free = Lot(VehicleType.Motorcycle, "M12", "M11", "M10");

        Assert.Equal(2, ParkingAllocationService.EntryGateFor(free, lastGate: null));
    }

    [Fact]
    public void WhenBothGatesAreAsCloseTheAppPicksTheGateTheDriverUsedLast()
    {
        var free = Lot(VehicleType.Motorcycle);

        Assert.Equal(2, ParkingAllocationService.EntryGateFor(free, lastGate: 2));
        Assert.Equal(1, ParkingAllocationService.EntryGateFor(free, lastGate: null));
    }
}
