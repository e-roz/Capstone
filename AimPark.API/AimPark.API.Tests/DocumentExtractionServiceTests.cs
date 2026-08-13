using AimPark.API.Enums;
using AimPark.API.Services;
using AimPark.API.Tests.Fixtures;

namespace AimPark.API.Tests;

/// <summary>
/// Extraction against a real reading of a real form.
/// </summary>
public class DocumentExtractionServiceTests
{
    private static readonly DocumentExtractionService Extractor = new();

    private static AimPark.API.DTOs.ExtractedValuesDto ExtractFromRaf()
        => Extractor.Extract(RafProbeFixture.Payload(), null, null, null);

    [Fact]
    public void ReadsStudentNumberFromCaptionBelowIt()
    {
        // The caption "Student No" is printed underneath the number, not beside it.
        Assert.Equal("02000199887", ExtractFromRaf().StudentNumber);
    }

    [Fact]
    public void KeepsTheLeadingZeroOnAStudentNumber()
    {
        // Losing it would collide two students on the unique index, and the failure
        // would surface as an unexplained registration error much later.
        Assert.StartsWith("0", ExtractFromRaf().StudentNumber);
    }

    [Fact]
    public void IsNotFooledByTheStudentInformationHeading()
    {
        // "Student Information" is within edit tolerance of the label "Student No"
        // and appears above it. Taking the first match instead of the closest one
        // pointed the rule at the wrong line and returned nothing at all.
        Assert.NotNull(ExtractFromRaf().StudentNumber);
    }

    [Fact]
    public void AssemblesTheNameFromThreeSeparateCells()
    {
        var name = ExtractFromRaf().StudentName;

        Assert.NotNull(name);
        Assert.Contains("MARIA ELENA", name);
        Assert.Contains("CRUZ", name);
        Assert.Contains("SANTOS", name);
    }

    [Fact]
    public void DoesNotTakeTheYearLevelAsTheMiddleName()
    {
        // "J4Y1" sits within the vertical gap above "Middle Name" and would be
        // collected on proximity alone. It only overlaps that label's width by about
        // a third, which is what rules it out.
        var name = ExtractFromRaf().StudentName;

        Assert.NotNull(name);
        Assert.DoesNotContain("4Y1", name);
    }

    [Fact]
    public void PrefersTheSpelledOutTermOverTheCodedOne()
    {
        // The header carries "2627/1T"; the charges heading spells it out. The
        // spelled form is what an administrator has to read.
        Assert.Equal("2026-2027/1st Term", ExtractFromRaf().Semester);
    }

    [Fact]
    public void TakesTheSectionThatAppearsMostOften()
    {
        // Seven copies in the subject table, one of them damaged to "BSIT-48" and
        // one run together with the units. The damaged copies disagree with each
        // other; the correct one does not.
        Assert.Equal("BSIT-4B", ExtractFromRaf().Section);
    }

    [Fact]
    public void RejectsTheDamagedSectionReading()
    {
        // "BSIT-48" is digits where a section ends in a letter — it must not win
        // even though it appears in the table.
        Assert.NotEqual("BSIT-48", ExtractFromRaf().Section);
    }

    [Fact]
    public void ReportsMissingFieldsRatherThanInventingThem()
    {
        // Only the school form was supplied, so nothing vehicle-related can be read.
        var result = ExtractFromRaf();

        Assert.Null(result.PlateNumber);
        Assert.True(result.IsFlagged(nameof(result.PlateNumber)));
    }

    [Fact]
    public void SeparatesUnreadableFieldsFromDerivedOnes()
    {
        // A blank the user must fill in is not the same as a value worked out from
        // the plate digit — the screen has to say different things about them.
        var result = ExtractFromRaf();

        var plate = result.FieldsToCheck.Single(f => f.Field == nameof(result.PlateNumber));
        Assert.Equal(nameof(FieldFlag.NotFound), plate.Reason);
    }

    [Fact]
    public void FlagsEachFieldOnlyOnce()
    {
        var result = ExtractFromRaf();

        Assert.Equal(
            result.FieldsToCheck.Select(f => f.Field).Distinct().Count(),
            result.FieldsToCheck.Count);
    }

    [Fact]
    public void SurvivesAnEmptyPayload()
    {
        var result = Extractor.Extract(null, null, null, null);

        Assert.Null(result.StudentNumber);
        Assert.Null(result.StudentName);
        Assert.NotEmpty(result.FieldsToCheck);
    }
}
