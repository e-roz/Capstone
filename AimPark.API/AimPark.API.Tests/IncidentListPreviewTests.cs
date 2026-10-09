using AimPark.API.DTOs;

namespace AimPark.API.Tests;

/// <summary>
/// The "My Incident Reports" list shows a short description preview so two
/// reports in the same category can be told apart.
/// </summary>
public class IncidentListPreviewTests
{
    [Fact]
    public void ALongDescriptionIsCutWithAnEllipsisWithinEightyOneCharacters()
    {
        var preview = IncidentSummaryResponse.Preview(new string('a', 200));

        Assert.NotNull(preview);
        Assert.True(preview!.Length <= 81);
        Assert.EndsWith("…", preview);
    }

    [Fact]
    public void AShortDescriptionIsReturnedUnchanged()
    {
        Assert.Equal("Car parked across two bays", IncidentSummaryResponse.Preview("Car parked across two bays"));
    }

    [Fact]
    public void ADescriptionOfExactlyEightyCharactersIsNotCut()
    {
        var text = new string('b', 80);

        Assert.Equal(text, IncidentSummaryResponse.Preview(text));
    }

    [Fact]
    public void SurroundingWhitespaceIsTrimmed()
    {
        Assert.Equal("Blocked gate", IncidentSummaryResponse.Preview("  Blocked gate \n"));
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("   ")]
    public void AnEmptyDescriptionGivesNoPreview(string? description)
    {
        Assert.Null(IncidentSummaryResponse.Preview(description));
    }
}
