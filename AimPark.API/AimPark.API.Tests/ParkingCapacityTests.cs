using AimPark.API.Enums;
using AimPark.API.Services;

namespace AimPark.API.Tests;

public class ParkingCapacityTests
{
    private const ParkingSlotStatus Free = ParkingSlotStatus.Available;
    private const ParkingSlotStatus Taken = ParkingSlotStatus.Occupied;
    private const ParkingSlotStatus Down = ParkingSlotStatus.OutOfService;
    private const ParkingSlotStatus Silent = ParkingSlotStatus.NoSignal;

    private const VehicleType Car = VehicleType.Car;
    private const VehicleType Moto = VehicleType.Motorcycle;

    // The model's Gate 1: three car bays, six motorcycle bays, every sensor
    // reading. The first `seen` bays of a type read Occupied.
    private static List<(VehicleType? Type, ParkingSlotStatus Status)> Lot(int carsSeen = 0, int motorcyclesSeen = 0)
    {
        IEnumerable<(VehicleType?, ParkingSlotStatus)> Bays(VehicleType type, int count, int seen) =>
            Enumerable.Range(0, count).Select(i => ((VehicleType?)type, i < seen ? Taken : Free));

        return [.. Bays(Car, 3, carsSeen), .. Bays(Moto, 6, motorcyclesSeen)];
    }

    private static VehicleType?[] Inside(int cars = 0, int motorcycles = 0, int unknown = 0) =>
    [
        .. Enumerable.Repeat<VehicleType?>(Car, cars),
        .. Enumerable.Repeat<VehicleType?>(Moto, motorcycles),
        .. Enumerable.Repeat<VehicleType?>(null, unknown)
    ];

    [Fact]
    public void AnEmptyLotIsAllFree()
    {
        Assert.Equal(new ParkingRoom(9, 3, 6), ParkingCapacity.Of(Lot(), Inside()));
    }

    [Fact]
    public void RoomFollowsTheCardsNotTheSensors()
    {
        // A car set down in a bay with no tap: the sensor sees it, but nobody
        // has tapped in, so the count of cars inside is what decides.
        var room = ParkingCapacity.Of(Lot(carsSeen: 1), Inside());
        Assert.Equal(9, room.Free);
        Assert.Equal(3, room.FreeCars);
    }

    [Fact]
    public void ACarTakingTwoBaysDoesNotTurnTheNextDriverAway()
    {
        // 18 bays, 17 cars tapped in, one of them across two bays: all 18 read
        // taken, yet one tap of room is left.
        List<(VehicleType?, ParkingSlotStatus)> lot =
            [.. Enumerable.Range(0, 18).Select(_ => ((VehicleType?)Moto, Taken))];
        var room = ParkingCapacity.Of(lot, Inside(motorcycles: 17));
        Assert.Equal(1, room.Free);
        Assert.Equal(1, room.FreeMotorcycles);
    }

    [Fact]
    public void EveryCarInsideTakesRoomWhereverItParked()
    {
        var room = ParkingCapacity.Of(Lot(), Inside(motorcycles: 1));
        Assert.Equal(8, room.Free);
        Assert.Equal(5, room.FreeMotorcycles);
        Assert.Equal(3, room.FreeCars);
    }

    [Fact]
    public void ABayWithNoSignalLeavesTheTotalAtOnce()
    {
        List<(VehicleType?, ParkingSlotStatus)> lot = [(Car, Silent), (Car, Free), (Car, Free)];
        var room = ParkingCapacity.Of(lot, Inside());
        Assert.Equal(2, room.Free);
        Assert.Equal(2, room.FreeCars);
    }

    [Fact]
    public void ABayComesBackWithItsSensor()
    {
        List<(VehicleType?, ParkingSlotStatus)> lot = [(Car, Free), (Car, Free), (Car, Free)];
        Assert.Equal(3, ParkingCapacity.Of(lot, Inside()).FreeCars);
    }

    [Fact]
    public void OutOfServiceBaysAreNotRoom()
    {
        List<(VehicleType?, ParkingSlotStatus)> lot = [(Car, Down), (Car, Free)];
        Assert.Equal(1, ParkingCapacity.Of(lot, Inside()).FreeCars);
    }

    [Fact]
    public void FullWhenAsManyCarsAreInsideAsWorkingBays()
    {
        List<(VehicleType?, ParkingSlotStatus)> lot = [(Car, Silent), (Car, Free), (Car, Free)];
        var room = ParkingCapacity.Of(lot, Inside(cars: 2));
        Assert.Equal(new ParkingRoom(0, 0, 0), room);
    }

    [Fact]
    public void BayTypesAreCountedApart()
    {
        // Two motorcycles inside don't take car bays.
        var room = ParkingCapacity.Of(Lot(), Inside(motorcycles: 2));
        Assert.Equal(3, room.FreeCars);
        Assert.Equal(4, room.FreeMotorcycles);
    }

    [Fact]
    public void AMotorcycleOverflowTakesFourWheelBays()
    {
        var room = ParkingCapacity.Of(Lot(), Inside(motorcycles: 7));
        Assert.Equal(0, room.FreeMotorcycles);
        Assert.Equal(2, room.FreeCars);
    }

    [Fact]
    public void ASessionOfUnknownTypeTakesFromTheTotalOnly()
    {
        var room = ParkingCapacity.Of(Lot(), Inside(unknown: 1));
        Assert.Equal(8, room.Free);
        Assert.Equal(3, room.FreeCars);
        Assert.Equal(6, room.FreeMotorcycles);
    }

    [Fact]
    public void NeverBelowZero()
    {
        List<(VehicleType?, ParkingSlotStatus)> lot = [(Car, Free)];
        Assert.Equal(new ParkingRoom(0, 0, 0), ParkingCapacity.Of(lot, Inside(cars: 3)));
    }

    [Fact]
    public void AVehicleMayUseItsFallbackTier()
    {
        var room = ParkingCapacity.Of(Lot(), Inside(motorcycles: 6));
        Assert.Equal(0, room.FreeOf([VehicleType.Motorcycle]));
        Assert.Equal(3, room.FreeOf([VehicleType.Car]));
    }

    [Fact]
    public void TheCountsAreReadSideBySide()
    {
        ParkingSlotStatus[] bays = [Taken, Taken, Free, Silent, Down];
        var count = ParkingCapacity.CountOf(bays, usersInside: 3);

        Assert.Equal(3, count.UsersInside);
        Assert.Equal(2, count.SensorsDetected);
        Assert.Equal(3, count.TotalBays);
        Assert.Equal(1, count.NoSignalBays);
        Assert.False(count.Comparable);
    }

    [Fact]
    public void TheCountsCompareWhenEverySensorReads()
    {
        ParkingSlotStatus[] bays = [Taken, Free, Down];
        Assert.True(ParkingCapacity.CountOf(bays, usersInside: 1).Comparable);
    }
}
