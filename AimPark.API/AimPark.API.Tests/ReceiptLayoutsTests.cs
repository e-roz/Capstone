using AimPark.API.DTOs;
using AimPark.API.Entities;
using AimPark.API.Enums;
using AimPark.API.Helpers;
using AimPark.API.Services;
using AimPark.API.Tests.Fixtures;

namespace AimPark.API.Tests;

/// <summary>
/// Both LTO Official Receipt layouts, each against a real reading. Sample data only.
/// </summary>
/// <remarks>
/// The older layout has no vehicle type or colour label and no "valid until"
/// sentence, so each of those fields has a second way of being found. The negative
/// cases matter as much: with no evidence the answer is "not found", which the
/// applicant types and the reviewer is told was typed.
/// </remarks>
public class ReceiptLayoutsTests
{
    private static readonly DocumentExtractionService Extractor = new();

    private static ExtractedValuesDto Read(OcrPayloadDto receipt)
        => Extractor.Extract(null, null, receipt, null);

    // ── Month-name dates ────────────────────────────────────────────────────

    [Theory]
    [InlineData("JAN 1 2026 to MAR 31 2026", 2026, 3, 31)]
    [InlineData("JAN 12026 to MAR 31 2026", 2026, 3, 31)]
    [InlineData("JAN 1 2026 to MAR 312026", 2026, 3, 31)]
    [InlineData("JAN 1, 2026 to MARCH 31, 2026", 2026, 3, 31)]
    [InlineData("jan 1 2026 to dec 31 2026", 2026, 12, 31)]
    public void TakesTheLastMonthNameDate(string text, int year, int month, int day)
        => Assert.Equal(
            new DateTime(year, month, day, 0, 0, 0, DateTimeKind.Utc),
            DateExtraction.FindLastMonthNameDate(text));

    [Fact]
    public void ADateNotOnTheCalendarIsSkippedNotRolledForward()
        => Assert.Null(DateExtraction.FindLastMonthNameDate("FEB 30 2026"));

    [Fact]
    public void NoDateGivesNothing()
    {
        Assert.Null(DateExtraction.FindLastMonthNameDate(null));
        Assert.Null(DateExtraction.FindLastMonthNameDate("renewal on 05/22/2027"));
    }

    // ── Older layout ────────────────────────────────────────────────────────

    [Fact]
    public void TheOlderReceiptGivesAllFourValues()
    {
        var result = Read(ReceiptTypeBProbeFixture.Payload());

        Assert.Equal(ReceiptTypeBProbeFixture.Plate, result.PlateNumber);
        Assert.Equal(ReceiptTypeBProbeFixture.Expiry, result.RegistrationExpiry);
        Assert.Equal("Motorcycle", result.VehicleType);
        Assert.Equal(ReceiptTypeBProbeFixture.Colour, result.Color);

        // Only the receipt was sent, so the other documents' fields are rightly
        // unread. None of the receipt's own may be flagged.
        Assert.False(result.IsFlagged(nameof(result.PlateNumber)));
        Assert.False(result.IsFlagged(nameof(result.RegistrationExpiry)));
        Assert.False(result.IsFlagged(nameof(result.Color)));
    }

    [Fact]
    public void TheExpiryIsTheEndOfTheRenewalWindowNotItsStart()
    {
        // OCR damaged the first date ("JAN 12026"); the last one is the expiry.
        var expiry = Read(ReceiptTypeBProbeFixture.Payload()).RegistrationExpiry;

        Assert.Equal(new DateTime(2026, 3, 31, 0, 0, 0, DateTimeKind.Utc), expiry);
    }

    [Fact]
    public void WithoutTheRenewalLineTheExpiryIsNotFound()
    {
        // No date from the fee table, the footer or the header may stand in for it.
        var result = Read(ReceiptTypeBProbeFixture.Without(ReceiptTypeBProbeFixture.ExpiryLine));

        Assert.Null(result.RegistrationExpiry);
        Assert.True(result.IsFlagged(nameof(result.RegistrationExpiry)));
    }

    [Fact]
    public void WithoutAnyMotorcycleEvidenceTheVehicleIsNotGuessedAsACar()
    {
        // The "Car" in "Car/MC/GAS/Red" is not the vehicle type, and the other
        // line is too damaged to read. Nothing left to go on.
        var result = Read(ReceiptTypeBProbeFixture.Without(ReceiptTypeBProbeFixture.VehicleLine));

        Assert.Null(result.VehicleType);
        Assert.Null(result.Color);
        Assert.True(result.IsFlagged(nameof(result.Color)));
    }

    [Fact]
    public void TwoLinesNamingAColourAreNotGuessedBetween()
    {
        var receipt = ReceiptTypeBProbeFixture.With(
            ReceiptTypeBProbeFixture.Line("x CarMCGASBlue", 430, 1900, 271, 46, 0.57));

        Assert.Null(Read(receipt).Color);
    }

    [Fact]
    public void AColourWithSeveralWordsIsKeptWhole()
    {
        var receipt = ReceiptTypeBProbeFixture.Without(ReceiptTypeBProbeFixture.VehicleLine);
        receipt.Lines.Add(ReceiptTypeBProbeFixture.Line("e Car/MC/GAS/MATTE ORANGE/BLACK", 430, 1343, 271, 46, 0.57));

        var result = Read(receipt);

        Assert.Equal("Motorcycle", result.VehicleType);
        Assert.Equal("MATTE ORANGE/BLACK", result.Color);
    }

    // ── Newer layout is unaffected ──────────────────────────────────────────

    [Fact]
    public void ANewerReceiptWithoutItsColourLabelIsNotFilledInFromTheFuelLine()
    {
        // "Fuel Type:" and its "Gas" are separate lines with no colour after them.
        var receipt = ReceiptProbeFixture.Without(
            ReceiptProbeFixture.Second(), "Color: " + ReceiptProbeFixture.Color);

        Assert.Null(Read(receipt).Color);
    }

    [Fact]
    public void BothNewerReadingsStillGiveTheirValues()
    {
        foreach (var receipt in new[] { ReceiptProbeFixture.First(), ReceiptProbeFixture.Second() })
        {
            var result = Read(receipt);

            Assert.Equal(ReceiptProbeFixture.Plate, result.PlateNumber);
            Assert.Equal(ReceiptProbeFixture.Expiry, result.RegistrationExpiry);
            Assert.Equal("Motorcycle", result.VehicleType);
            Assert.Equal(ReceiptProbeFixture.Color, result.Color);
        }
    }

    // ── Shown to the reviewer ───────────────────────────────────────────────

    [Fact]
    public void ATypedVehicleTypeAndColourReachTheReviewerAsFindings()
    {
        var now = new DateTime(2026, 10, 16, 0, 0, 0, DateTimeKind.Utc);
        var user = new User
        {
            Id = Guid.NewGuid(), FullName = "Sample Driver", Email = "sample@x.test",
            Affiliation = Affiliation.Faculty
        };

        var row = new DocumentVerification
        {
            UserId = user.Id,
            ExtractedLicenseName = "SAMPLE DRIVER",
            ExtractedLicenseExpiry = now.AddYears(2),
            ExtractedPlateNumber = "TST 0000",
            NameMatch = CheckResult.NotChecked,
            PlateMatch = CheckResult.Passed,
            Notes = $"{RegistrationChecks.VehicleTypeTypedMarker} — the receipt could not be read for this, the applicant chose Motorcycle.\n"
                    + $"{RegistrationChecks.ColourTypedMarker} — the receipt could not be read for this, the applicant typed \"Red\".",
            CreatedAt = now
        };

        var checks = RegistrationChecks.Build(user, [row], [], now)!;

        var type = checks.Findings.Single(f => f.Key == "Typed.VehicleType");
        Assert.Equal("Vehicle type typed by applicant", type.Title);
        Assert.Equal(RegistrationChecks.Warning, type.Severity);
        Assert.Equal("OfficialReceipt", type.Document);

        var colour = checks.Findings.Single(f => f.Key == "Typed.Colour");
        Assert.Equal("Colour typed by applicant", colour.Title);
        Assert.Contains("Red", colour.Detail);
    }
}
