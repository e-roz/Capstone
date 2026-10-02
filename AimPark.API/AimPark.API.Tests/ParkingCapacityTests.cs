using AimPark.API.Enums;
using AimPark.API.Services;

namespace AimPark.API.Tests;

public class ParkingCapacityTests
{
    private const ParkingSlotStatus Free = ParkingSlotStatus.Available;
    private const ParkingSlotStatus Taken = ParkingSlotStatus.Occupied;
    private const ParkingSlotStatus Down = ParkingSlotStatus.OutOfService;

    // The model's Gate 1: three car bays, six motorcycle bays.
    private static List<(VehicleType? Type, ParkingSlotStatus Status)> Lot(int carsSeen = 0, int motorcyclesSeen = 0) =>
    [
        .. Enumerable.Range(0, 3).Select(i => ((VehicleType?)VehicleType.Car, i < carsSeen ? Taken : Free)),
        .. Enumerable.Range(0, 6).Select(i => ((VehicleType?)VehicleType.Motorcycle, i < motorcyclesSeen ? Taken : Free)),
    ];

    private static (bool, VehicleType?) GivenA(VehicleType type) => (true, type);

    [Fact]
    public void AnEmptyLotIsAllFree()
    {
        var room = ParkingCapacity.Of(Lot(), []);
        Assert.Equal(new ParkingRoom(9, 3, 6), room);
    }

    [Fact]
    public void ACarThatEnteredCountsBeforeItParks()
    {
        // Tapped in, given a motorcycle bay, still driving to it: the bay is green.
        var room = ParkingCapacity.Of(Lot(), [GivenA(VehicleType.Motorcycle)]);
        Assert.Equal(5, room.FreeMotorcycles);
        Assert.Equal(8, room.Free);
    }

    [Fact]
    public void ParkingAnywhereStillCountsOnce()
    {
        // Parked in a different motorcycle bay than the one it was given.
        var room = ParkingCapacity.Of(Lot(motorcyclesSeen: 1), [GivenA(VehicleType.Motorcycle)]);
        Assert.Equal(8, room.Free);
    }

    [Fact]
    public void LiftedOutWithoutTappingOutStillCounts()
    {
        // The user's test: the bay goes green again, the car is still inside.
        var room = ParkingCapacity.Of(Lot(motorcyclesSeen: 0), [GivenA(VehicleType.Motorcycle)]);
        Assert.Equal(8, room.Free);
    }

    [Fact]
    public void TheExitTapGivesTheRoomBack()
    {
        Assert.Equal(9, ParkingCapacity.Of(Lot(), []).Free);
    }

    [Fact]
    public void ACarSeenWithNoSessionStillTakesItsBay()
    {
        // Tapped out but not yet driven off, or a manual entry still to come.
        var room = ParkingCapacity.Of(Lot(carsSeen: 1), []);
        Assert.Equal(2, room.FreeCars);
        Assert.Equal(8, room.Free);
    }

    [Fact]
    public void BayTypesAreCountedApart()
    {
        // Two motorcycles inside don't take car bays.
        var room = ParkingCapacity.Of(Lot(), [GivenA(VehicleType.Motorcycle), GivenA(VehicleType.Motorcycle)]);
        Assert.Equal(3, room.FreeCars);
        Assert.Equal(4, room.FreeMotorcycles);
    }

    [Fact]
    public void OutOfServiceBaysAreNotRoom()
    {
        List<(VehicleType?, ParkingSlotStatus)> lot = [(VehicleType.Car, Down), (VehicleType.Car, Free)];
        Assert.Equal(1, ParkingCapacity.Of(lot, []).FreeCars);
    }

    [Fact]
    public void NeverBelowZero()
    {
        List<(VehicleType?, ParkingSlotStatus)> lot = [(VehicleType.Car, Free)];
        var room = ParkingCapacity.Of(lot, [GivenA(VehicleType.Car), GivenA(VehicleType.Car), (false, null)]);
        Assert.Equal(new ParkingRoom(0, 0, 0), room);
    }

    [Fact]
    public void ASessionGivenNoBayTakesFromTheTotal()
    {
        var room = ParkingCapacity.Of(Lot(), [(false, null)]);
        Assert.Equal(8, room.Free);
        Assert.Equal(3, room.FreeCars);
    }

    [Fact]
    public void AVehicleMayUseItsFallbackTier()
    {
        var room = ParkingCapacity.Of(Lot(motorcyclesSeen: 6), []);
        Assert.Equal(0, room.FreeOf([VehicleType.Motorcycle]));
        Assert.Equal(3, room.FreeOf([VehicleType.Car]));
    }
}
