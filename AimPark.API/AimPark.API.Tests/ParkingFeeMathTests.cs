using AimPark.API.Helpers;

namespace AimPark.API.Tests;

/// <summary>
/// How a visit is priced: first hour flat, then per minute, with a 7-minute
/// grace period after each payment that is charged if the driver stays past it. Numbers follow the example on the design canvas: a car
/// at ₱20/hr that entered at 1:02 PM.
/// </summary>
public class ParkingFeeMathTests
{
    private static readonly DateTime Entry = new(2026, 11, 19, 5, 2, 0, DateTimeKind.Utc); // 1:02 PM Manila
    private const decimal Car = 20m;
    private const int Grace = 7;

    private static DateTime At(double minutes) => Entry.AddMinutes(minutes);

    private static FeeBreakdown Price(double atMinutes, params double[] paidAtMinutes) =>
        ParkingFeeMath.Breakdown(Car, Entry, At(atMinutes),
            paidAtMinutes.Select(m => new SettledPayment(At(m), At(m))).ToList(), Grace);

    [Theory]
    [InlineData(1, 1)]      // one second in is a started minute
    [InlineData(60, 1)]
    [InlineData(61, 2)]
    public void A_started_minute_is_a_charged_minute(int seconds, int minutes)
        => Assert.Equal(minutes, ParkingFeeMath.ChargedMinutes(Entry, Entry.AddSeconds(seconds)));

    [Theory]
    [InlineData(1.0 / 60, 20)]   // one second
    [InlineData(39, 20)]
    [InlineData(60, 20)]         // exactly an hour
    [InlineData(61, 20.33)]
    [InlineData(150, 50)]        // 2:02–3:32 is 90 minutes: ₱30
    public void First_hour_is_flat_then_per_minute(double atMinutes, double total)
        => Assert.Equal((decimal)total, Price(atMinutes).Total);

    [Fact]
    public void Inside_the_first_hour_the_next_change_is_when_it_ends()
    {
        var b = Price(39);

        Assert.Equal(MeterState.FirstHour, b.State);
        Assert.Equal(At(60), b.FirstHourEndsAt);
        Assert.Equal(At(60), b.NextChangeAt);
        Assert.Equal(20.33m, b.NextTotal);
        var only = Assert.Single(b.Segments);
        Assert.Equal(new FeeSegment(FeeSegmentKind.FirstHour, Entry, At(60), 60, 20m), only);
    }

    [Fact]
    public void Paying_inside_the_first_hour_covers_to_its_end()
    {
        var b = Price(40, 39);

        Assert.Equal(20m, b.Total);
        Assert.Equal(At(46), b.GraceUntil);   // grace ends inside the first hour
        Assert.Equal(At(60), b.NextChangeAt); // so the first hour's end is what counts
    }

    [Fact]
    public void Past_the_first_hour_the_meter_runs_whether_paid_or_not()
    {
        var b = Price(150, 39);

        Assert.Equal(50m, b.Total);
        Assert.Equal(MeterState.Running, b.State);
        Assert.Equal(90, b.PerMinuteMinutes);
        Assert.Equal(
            new[]
            {
                new FeeSegment(FeeSegmentKind.FirstHour, Entry, At(60), 60, 20m),
                new FeeSegment(FeeSegmentKind.PerMinute, At(60), At(150), 90, 30m),
            },
            b.Segments);
    }

    [Fact]
    public void After_paying_the_meter_pauses_for_the_seven_minute_grace_period()
    {
        var b = Price(152, 39, 150);

        Assert.Equal(50m, b.Total);
        Assert.Equal(MeterState.Paused, b.State);
        Assert.Equal(At(157), b.GraceUntil);                   // 3:39 PM
        Assert.Equal(At(157), b.NextChangeAt);
        Assert.Equal(new FeeSegment(FeeSegmentKind.Grace, At(150), At(157), 7, 0m), b.Segments[^1]);
    }

    [Fact]
    public void When_the_grace_period_ends_all_of_its_minutes_are_charged_at_once()
        // 3:39:01 PM is minute 158: minutes 61–158 are 98, ₱32.67.
        => Assert.Equal(52.67m, Price(152, 39, 150).NextTotal);

    [Fact]
    public void Leaving_inside_the_grace_period_costs_nothing_more()
    {
        // Paid 3:32, left 3:37.
        var b = ParkingFeeMath.Breakdown(Car, Entry, At(155),
            [new SettledPayment(At(150), At(150))], Grace, open: false);

        Assert.Equal(50m, b.Total);
        Assert.Equal(new FeeSegment(FeeSegmentKind.Grace, At(150), At(155), 5, 0m), b.Segments[^1]);
    }

    [Fact]
    public void Leaving_on_the_last_second_of_the_grace_period_still_costs_nothing_more()
        => Assert.Equal(50m, ParkingFeeMath.Breakdown(Car, Entry, At(157),
            [new SettledPayment(At(150), At(150))], Grace, open: false).Total);

    [Theory]
    [InlineData(170, 56.67, 110, 36.67)]   // 3:52 PM: every minute from 2:02 is charged
    [InlineData(171, 57.00, 111, 37.00)]   // 3:53 PM
    public void Staying_past_the_grace_period_charges_its_minutes_too(double at, double total, int minutes, double amount)
    {
        var b = Price(at, 39, 150);

        Assert.Equal((decimal)total, b.Total);
        Assert.Equal(MeterState.Running, b.State);
        Assert.Equal(
            new[]
            {
                new FeeSegment(FeeSegmentKind.FirstHour, Entry, At(60), 60, 20m),
                new FeeSegment(FeeSegmentKind.PerMinute, At(60), At(at), minutes, (decimal)amount),
            },
            b.Segments);
    }

    [Fact]
    public void Paying_at_minute_58_and_staying_to_66_charges_from_the_first_hour_end()
    {
        var b = Price(66, 58);

        Assert.Equal(22m, b.Total);   // minutes 61–66: ₱2
        Assert.Equal(
            new[]
            {
                new FeeSegment(FeeSegmentKind.FirstHour, Entry, At(60), 60, 20m),
                new FeeSegment(FeeSegmentKind.PerMinute, At(60), At(66), 6, 2m),
            },
            b.Segments);
    }

    [Fact]
    public void Two_payments_close_together_extend_the_grace()
        => Assert.Equal(At(159), Price(153, 150, 152).GraceUntil);

    [Fact]
    public void A_motorcycle_at_30_an_hour()
        => Assert.Equal(45m, ParkingFeeMath.Breakdown(30m, Entry, At(90), [], Grace).Total);

    [Fact]
    public void With_no_rate_nothing_is_charged_and_nothing_changes()
    {
        var b = ParkingFeeMath.Breakdown(0m, Entry, At(300), [], Grace);

        Assert.Equal(0m, b.Total);
        Assert.Equal(MeterState.Free, b.State);
        Assert.Empty(b.Segments);
        Assert.Null(b.NextChangeAt);
    }

    [Fact]
    public void A_closed_visit_ends_its_last_grace_at_the_exit()
    {
        // Paid 3:53, left 3:55: the grace shows as 3:53–3:55, not to 4:00.
        var b = ParkingFeeMath.Breakdown(Car, Entry, At(173),
            [new SettledPayment(At(39), At(39)), new SettledPayment(At(150), At(150)), new SettledPayment(At(171), At(171))],
            Grace, open: false);

        Assert.Equal(new FeeSegment(FeeSegmentKind.Grace, At(171), At(173), 2, 0m), b.Segments[^1]);
        Assert.Null(b.NextChangeAt);
    }

    [Fact]
    public void Chargeable_minutes_between_skip_a_grace_period_still_running()
    {
        var b = Price(155, 39, 150);

        Assert.Equal(0, b.ChargeableMinutesBetween(At(150), At(155)));
        Assert.Equal(60, b.ChargeableMinutesBetween(Entry, At(60)));
    }

    [Fact]
    public void Chargeable_minutes_between_count_a_grace_period_that_was_lost()
        => Assert.Equal(21, Price(171, 39, 150).ChargeableMinutesBetween(At(150), At(171)));

    [Fact]
    public void The_grace_period_counts_from_the_exact_moment_of_payment()
    {
        // Paid at 3:34:12: the grace period ends at 3:41:12, not on a whole minute.
        var b = ParkingFeeMath.Breakdown(Car, Entry, At(158),
            [new SettledPayment(At(150), At(152.2))], Grace);

        Assert.Equal(At(159.2), b.GraceUntil);
        Assert.Equal(At(159.2), b.NextChangeAt);
    }

    [Fact]
    public void Time_between_pricing_a_bill_and_paying_it_is_paused_while_the_grace_period_holds()
    {
        // Priced to 3:32, paid at 3:34:12, still inside at 3:40.
        var b = ParkingFeeMath.Breakdown(Car, Entry, At(158),
            [new SettledPayment(At(150), At(152.2))], Grace);

        Assert.Equal(50m, b.Total);
        Assert.Equal(new FeeSegment(FeeSegmentKind.Grace, At(150), At(160), 10, 0m), b.Segments[^1]);
    }

    [Fact]
    public void Time_between_pricing_a_bill_and_paying_it_is_charged_once_the_grace_period_is_lost()
        // Still inside at 3:42: minutes 61–160 are all charged, ₱33.33.
        => Assert.Equal(53.33m, ParkingFeeMath.Breakdown(Car, Entry, At(160),
            [new SettledPayment(At(150), At(152.2))], Grace).Total);

    [Fact]
    public void A_payment_that_took_hours_does_not_make_those_hours_free()
    {
        // A checkout opened at 2:02 and only paid at 5:02, still in its grace
        // period at 5:04: at most 15 minutes before the payment are paused.
        var b = ParkingFeeMath.Breakdown(Car, Entry, At(242),
            [new SettledPayment(At(60), At(60)), new SettledPayment(At(61), At(240))], Grace);

        // The first payment's grace period was lost long ago. Paused 226–247.
        // Charged: 61–225, 165 minutes.
        Assert.Equal(75m, b.Total);
    }
}
