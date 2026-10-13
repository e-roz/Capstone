using AimPark.API.Services;

namespace AimPark.API.Tests;

public class ParkingMismatchWatchTests
{
    private static readonly DateTime T0 = new(2026, 10, 13, 8, 0, 0, DateTimeKind.Utc);

    private static LotCount Count(int users, int sensors, int noSignal = 0) =>
        new(users, sensors, TotalBays: 18, NoSignalBays: noSignal);

    private static DateTime At(int minutes) => T0.AddMinutes(minutes);

    [Fact]
    public void MatchingNumbersSayNothing()
    {
        var watch = new ParkingMismatchWatch();
        Assert.Null(watch.Check(Count(2, 2), At(0)));
        Assert.Null(watch.Check(Count(2, 2), At(30)));
    }

    [Fact]
    public void AGapMustHoldFiveMinutes()
    {
        var watch = new ParkingMismatchWatch();
        Assert.Null(watch.Check(Count(2, 1), At(0)));
        Assert.Null(watch.Check(Count(2, 1), At(4)));
        Assert.Equal(ParkingMismatch.UnseenCar, watch.Check(Count(2, 1), At(5)));
    }

    [Fact]
    public void MoreSensorsThanUsersMeansABayTooMany()
    {
        var watch = new ParkingMismatchWatch();
        watch.Check(Count(2, 3), At(0));
        Assert.Equal(ParkingMismatch.ExtraBay, watch.Check(Count(2, 3), At(5)));
    }

    [Fact]
    public void TheSameGapIsReportedOnce()
    {
        var watch = new ParkingMismatchWatch();
        watch.Check(Count(2, 1), At(0));
        Assert.NotNull(watch.Check(Count(2, 1), At(5)));
        Assert.Null(watch.Check(Count(2, 1), At(6)));
        Assert.Null(watch.Check(Count(2, 1), At(60)));
    }

    [Fact]
    public void ClosingTheGapRestartsTheWait()
    {
        var watch = new ParkingMismatchWatch();
        watch.Check(Count(2, 1), At(0));
        watch.Check(Count(2, 1), At(5));
        watch.Check(Count(2, 2), At(6));

        Assert.Null(watch.Check(Count(2, 1), At(7)));
        Assert.Null(watch.Check(Count(2, 1), At(11)));
        Assert.NotNull(watch.Check(Count(2, 1), At(12)));
    }

    [Fact]
    public void AGapThatChangesDirectionRestartsTheWait()
    {
        var watch = new ParkingMismatchWatch();
        watch.Check(Count(2, 1), At(0));
        Assert.Null(watch.Check(Count(2, 3), At(4)));
        Assert.Null(watch.Check(Count(2, 3), At(8)));
        Assert.Equal(ParkingMismatch.ExtraBay, watch.Check(Count(2, 3), At(9)));
    }

    [Fact]
    public void ASilentSensorPausesTheCheck()
    {
        var watch = new ParkingMismatchWatch();
        watch.Check(Count(2, 1), At(0));

        Assert.Null(watch.Check(Count(2, 1, noSignal: 1), At(5)));
        Assert.Null(watch.Check(Count(2, 1, noSignal: 1), At(30)));
    }

    [Fact]
    public void TheWaitStartsOverOnceEverySensorReadsAgain()
    {
        var watch = new ParkingMismatchWatch();
        watch.Check(Count(2, 1, noSignal: 1), At(0));

        Assert.Null(watch.Check(Count(2, 1), At(10)));
        Assert.Null(watch.Check(Count(2, 1), At(14)));
        Assert.NotNull(watch.Check(Count(2, 1), At(15)));
    }

    [Fact]
    public void TheWaitCanBeChanged()
    {
        var watch = new ParkingMismatchWatch(TimeSpan.FromMinutes(1));
        watch.Check(Count(2, 1), At(0));
        Assert.NotNull(watch.Check(Count(2, 1), At(1)));
    }
}
