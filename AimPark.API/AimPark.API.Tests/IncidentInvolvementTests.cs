using AimPark.API.Helpers;

namespace AimPark.API.Tests;

public class IncidentInvolvementTests
{
    /// <summary>Manila wall time, as the UTC instant the server stores.</summary>
    private static DateTime Manila(int day, int hour, int minute = 0) =>
        new DateTime(2026, 11, day, hour, minute, 0, DateTimeKind.Utc).AddHours(-8);

    [Fact]
    public void An_afternoon_report_looks_back_to_midnight()
    {
        var reported = Manila(18, 15);

        Assert.Equal(Manila(18, 0), IncidentInvolvement.WindowStart(reported));
    }

    [Fact]
    public void A_report_just_after_midnight_still_reaches_the_evening_before()
    {
        var reported = Manila(18, 0, 30);

        Assert.Equal(Manila(17, 18, 30), IncidentInvolvement.WindowStart(reported));
    }

    [Fact]
    public void Someone_who_left_this_morning_is_involved_in_an_evening_report()
    {
        var reported = Manila(18, 19);

        Assert.True(IncidentInvolvement.Overlaps(Manila(18, 7), Manila(18, 9), reported));
    }

    [Fact]
    public void Someone_who_left_yesterday_is_not_involved()
    {
        var reported = Manila(18, 19);

        Assert.False(IncidentInvolvement.Overlaps(Manila(17, 7), Manila(17, 20), reported));
    }

    [Fact]
    public void Someone_who_arrived_after_the_report_is_not_involved()
    {
        var reported = Manila(18, 10);

        Assert.False(IncidentInvolvement.Overlaps(Manila(18, 11), null, reported));
    }

    [Fact]
    public void Someone_still_inside_is_involved()
    {
        var reported = Manila(18, 10);

        Assert.True(IncidentInvolvement.Overlaps(Manila(17, 22), null, reported));
    }
}
