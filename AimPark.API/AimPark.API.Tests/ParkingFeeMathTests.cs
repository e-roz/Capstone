using AimPark.API.Helpers;

namespace AimPark.API.Tests;

/// <summary>
/// The arithmetic every bill and the app's live fee share. The live fee card
/// refetches at <see cref="ParkingFeeMath.NextChange"/>, so if that is wrong
/// the phone shows a stale amount.
/// </summary>
public class ParkingFeeMathTests
{
    private static readonly DateTime Entry = new(2026, 11, 17, 1, 0, 0, DateTimeKind.Utc);

    [Theory]
    [InlineData(0, 0)]
    [InlineData(1, 1)]      // one second in is a started minute
    [InlineData(60, 1)]
    [InlineData(61, 2)]
    [InlineData(80, 2)]
    public void A_started_minute_is_a_charged_minute(int seconds, int minutes)
        => Assert.Equal(minutes, ParkingFeeMath.ChargedMinutes(Entry, Entry.AddSeconds(seconds)));

    [Fact]
    public void Leaving_before_entry_charges_nothing()
        => Assert.Equal(0, ParkingFeeMath.ChargedMinutes(Entry, Entry.AddMinutes(-5)));

    [Theory]
    [InlineData(0, 0)]       // nothing charged, so no minimum either
    [InlineData(20, 20)]     // ₱5 metered, raised to the ₱20 floor
    [InlineData(80, 20)]     // exactly ₱20 metered
    [InlineData(81, 20.25)]  // past the floor, metered per minute
    [InlineData(120, 30)]
    public void Metered_per_minute_with_a_floor(int minutes, double expected)
        => Assert.Equal((decimal)expected, ParkingFeeMath.Price(15m, 20m, minutes));

    [Fact]
    public void No_rate_means_no_fee_and_no_minimum()
        => Assert.Equal(0m, ParkingFeeMath.Price(0m, 20m, 300));

    [Fact]
    public void Under_the_floor_the_next_change_is_when_metering_passes_it()
    {
        // ₱15/h with a ₱20 floor: 80 minutes is ₱20 exactly, 81 is the first
        // minute that costs more. Minute 81 starts 80 minutes after entry.
        var next = ParkingFeeMath.NextChange(15m, 20m, Entry, Entry.AddMinutes(10));

        Assert.NotNull(next);
        Assert.Equal(Entry.AddMinutes(80), next.Value.At);
        Assert.Equal(20.25m, next.Value.Amount);
    }

    [Fact]
    public void Past_the_floor_the_price_goes_up_when_the_next_minute_starts()
    {
        // 90.5 minutes in: charged 91. Minute 92 starts at 91 minutes.
        var next = ParkingFeeMath.NextChange(15m, 20m, Entry, Entry.AddMinutes(90.5));

        Assert.NotNull(next);
        Assert.Equal(Entry.AddMinutes(91), next.Value.At);
        Assert.Equal(ParkingFeeMath.Price(15m, 20m, 92), next.Value.Amount);
    }

    [Fact]
    public void Right_at_entry_the_first_charge_is_the_minimum_a_moment_later()
    {
        var next = ParkingFeeMath.NextChange(15m, 20m, Entry, Entry);

        Assert.NotNull(next);
        Assert.Equal(Entry, next.Value.At);
        Assert.Equal(20m, next.Value.Amount);
    }

    [Fact]
    public void With_no_rate_the_price_never_changes()
        => Assert.Null(ParkingFeeMath.NextChange(0m, 20m, Entry, Entry.AddMinutes(30)));
}
