using AimPark.API.DTOs;
using AimPark.API.Enums;
using AimPark.API.Helpers;

namespace AimPark.API.Tests;

public class OcrCleanupTests
{
    private static OcrLineDto Line(int w, int h, double confidence = 0.85)
        => new() { Text = "sample", X = 100, Y = 100, W = w, H = h, Confidence = confidence };

    [Fact]
    public void TreatsATallNarrowBoxAsRotatedText()
    {
        // The CR is printed at 90° on the same sheet as the OR, and rotated text
        // comes back tall and narrow — 17x246 against the OR's 153x19.
        Assert.True(OcrCleanup.IsRotated(Line(17, 246)));
        Assert.False(OcrCleanup.IsRotated(Line(153, 19)));
    }

    [Fact]
    public void DropsRotatedLinesBeforeAnyRuleRuns()
    {
        var prepared = OcrCleanup.Prepare([Line(153, 19), Line(17, 246), Line(200, 40)]);

        Assert.Equal(2, prepared.Count);
        Assert.DoesNotContain(prepared, OcrCleanup.IsRotated);
    }

    [Fact]
    public void SortsTopToBottomThenLeftToRight()
    {
        // Text recognition returns blocks in arbitrary order — in a real probe,
        // block 0 sat at y=104, block 1 at y=224 and block 2 at y=169.
        var lines = new List<OcrLineDto>
        {
            new() { Text = "third", X = 100, Y = 400, W = 200, H = 40, Confidence = 0.9 },
            new() { Text = "first", X = 100, Y = 100, W = 200, H = 40, Confidence = 0.9 },
            new() { Text = "second", X = 500, Y = 100, W = 200, H = 40, Confidence = 0.9 },
        };

        var sorted = OcrCleanup.SortReadingOrder(lines);

        Assert.Equal(["first", "second", "third"], sorted.Select(l => l.Text));
    }

    [Fact]
    public void ReportsNoTextWhenAlmostNothingWasFound()
    {
        Assert.Equal(ScanFailureReason.NoText, OcrCleanup.Diagnose([Line(150, 20), Line(150, 20)]));
    }

    [Fact]
    public void ReportsSidewaysWhenMostLinesAreRotated()
    {
        var lines = Enumerable.Range(0, 8).Select(_ => Line(20, 200)).ToList();
        lines.Add(Line(150, 20));

        Assert.Equal(ScanFailureReason.Sideways, OcrCleanup.Diagnose(lines));
    }

    [Fact]
    public void ReportsBlurryWhenThereIsPlentyOfTextButLowConfidence()
    {
        // A real probe read a clean line at 0.90 and junk at 0.31.
        var lines = Enumerable.Range(0, 10).Select(_ => Line(150, 20, 0.31)).ToList();

        Assert.Equal(ScanFailureReason.Blurry, OcrCleanup.Diagnose(lines));
    }

    [Fact]
    public void PassesACleanPage()
    {
        var lines = Enumerable.Range(0, 10).Select(_ => Line(150, 20, 0.85)).ToList();

        Assert.Equal(ScanFailureReason.None, OcrCleanup.Diagnose(lines));
    }

    [Fact]
    public void EveryFailureCarriesAMessageSayingWhatToDo()
    {
        foreach (var reason in new[] { ScanFailureReason.NoText, ScanFailureReason.Sideways, ScanFailureReason.Blurry })
            Assert.NotEmpty(OcrCleanup.MessageFor(reason, "receipt"));

        // Success is not a failure and must not produce a message to show anyone.
        Assert.Empty(OcrCleanup.MessageFor(ScanFailureReason.None, "receipt"));
    }
}

public class PlateNormalizationTests
{
    [Theory]
    [InlineData("ABC 1234", "ABC1234")]
    [InlineData("abc-1234", "ABC1234")]
    [InlineData(" 130301 ", "130301")]
    [InlineData(null, "")]
    [InlineData("", "")]
    public void StoresEveryPlateInOneCanonicalForm(string? input, string expected)
    {
        // A gate camera reads "ABC1234" while a user types "ABC 1234". Without one
        // form the lookup misses and nothing reports an error — the driver is simply
        // denied entry with a valid card.
        Assert.Equal(expected, IdentifierNormalizer.NormalizePlate(input));
    }
}
