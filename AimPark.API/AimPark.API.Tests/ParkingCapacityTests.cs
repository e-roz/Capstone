using AimPark.API.Enums;
using AimPark.API.Services;

namespace AimPark.API.Tests;

public class ParkingCapacityTests
{
    private const ParkingSlotStatus Free = ParkingSlotStatus.Available;
    private const ParkingSlotStatus Taken = ParkingSlotStatus.Occupied;
    private const ParkingSlotStatus Down = ParkingSlotStatus.OutOfService;
    private const ParkingSlotStatus Silent = ParkingSlotStatus.NoSignal;

    // The model's Gate 1: three car bays, six motorcycle bays. The first
    // `seen` bays of a type read Occupied; the `held` bays after them were
    // given to a car still inside, unless `heldSeen` puts them on the seen ones.
    private static List<(VehicleType? Type, ParkingSlotStatus Status, bool Held)> Lot(
        int carsSeen = 0, int motorcyclesSeen = 0, int carsHeld = 0, int motorcyclesHeld = 0, bool heldSeen = false)
    {
        IEnumerable<(VehicleType?, ParkingSlotStatus, bool)> Bays(VehicleType type, int count, int seen, int held)
        {
            var heldFrom = heldSeen ? 0 : seen;
            return Enumerable.Range(0, count).Select(i =>
                ((VehicleType?)type, i < seen ? Taken : Free, i >= heldFrom && i < heldFrom + held));
        }

        return [.. Bays(VehicleType.Car, 3, carsSeen, carsHeld), .. Bays(VehicleType.Motorcycle, 6, motorcyclesSeen, motorcyclesHeld)];
    }

    [Fact]
    public void AnEmptyLotIsAllFree()
    {
        Assert.Equal(new ParkingRoom(9, 3, 6), ParkingCapacity.Of(Lot()));
    }

    [Fact]
    public void ACarSetDownWithNoTapTakesItsBay()
    {
        // The miniature: placed in a bay by hand, the sensor sees it.
        var room = ParkingCapacity.Of(Lot(carsSeen: 1));
        Assert.Equal(2, room.FreeCars);
        Assert.Equal(8, room.Free);
    }

    [Fact]
    public void LiftingItOutGivesTheBayBack()
    {
        Assert.Equal(9, ParkingCapacity.Of(Lot(carsSeen: 0)).Free);
    }

    [Fact]
    public void ACarThatEnteredCountsBeforeItParks()
    {
        // Tapped in, given a motorcycle bay, still driving to it: the bay is green.
        var room = ParkingCapacity.Of(Lot(motorcyclesHeld: 1));
        Assert.Equal(5, room.FreeMotorcycles);
        Assert.Equal(8, room.Free);
    }

    [Fact]
    public void ParkingInItsBayCountsOnce()
    {
        var room = ParkingCapacity.Of(Lot(carsSeen: 1, carsHeld: 1, heldSeen: true));
        Assert.Equal(2, room.FreeCars);
        Assert.Equal(8, room.Free);
    }

    [Fact]
    public void ParkingElsewhereHoldsBothBaysUntilExit()
    {
        // Errs toward full: the bay it was given stays held until the exit tap.
        var room = ParkingCapacity.Of(Lot(motorcyclesSeen: 1, motorcyclesHeld: 1));
        Assert.Equal(4, room.FreeMotorcycles);
    }

    [Fact]
    public void NoSignalBaysAreNotFree()
    {
        List<(VehicleType?, ParkingSlotStatus, bool)> lot = [(VehicleType.Car, Silent, false), (VehicleType.Car, Free, false)];
        Assert.Equal(1, ParkingCapacity.Of(lot).FreeCars);
    }

    [Fact]
    public void OutOfServiceBaysAreNotRoom()
    {
        List<(VehicleType?, ParkingSlotStatus, bool)> lot = [(VehicleType.Car, Down, false), (VehicleType.Car, Free, false)];
        Assert.Equal(1, ParkingCapacity.Of(lot).FreeCars);
    }

    [Fact]
    public void BayTypesAreCountedApart()
    {
        // Two motorcycles inside don't take car bays.
        var room = ParkingCapacity.Of(Lot(motorcyclesHeld: 2));
        Assert.Equal(3, room.FreeCars);
        Assert.Equal(4, room.FreeMotorcycles);
    }

    [Fact]
    public void ASessionGivenNoBayTakesFromTheTotal()
    {
        var room = ParkingCapacity.Of(Lot(), unplaced: 1);
        Assert.Equal(8, room.Free);
        Assert.Equal(3, room.FreeCars);
    }

    [Fact]
    public void NeverBelowZero()
    {
        List<(VehicleType?, ParkingSlotStatus, bool)> lot = [(VehicleType.Car, Free, true)];
        Assert.Equal(new ParkingRoom(0, 0, 0), ParkingCapacity.Of(lot, unplaced: 2));
    }

    [Fact]
    public void AVehicleMayUseItsFallbackTier()
    {
        var room = ParkingCapacity.Of(Lot(motorcyclesHeld: 6));
        Assert.Equal(0, room.FreeOf([VehicleType.Motorcycle]));
        Assert.Equal(3, room.FreeOf([VehicleType.Car]));
    }
}
