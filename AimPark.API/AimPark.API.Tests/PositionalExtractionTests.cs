using AimPark.API.DTOs;
using AimPark.API.Helpers;
using AimPark.API.Services;
using AimPark.API.Tests.Fixtures;

namespace AimPark.API.Tests;

/// <summary>
/// Licence and receipt values found by where they sit on the page, against real
/// readings from the OCR debug app.
/// </summary>
/// <remarks>
/// Before this, the licence number and expiry were never read on either licence
/// photo, and each receipt photo lost a different vehicle field. The negative cases
/// matter as much: a wrong value is worse than "not found", which the user types and
/// the admin sees as typed.
/// </remarks>
public class PositionalExtractionTests
{
    private static readonly DocumentExtractionService Extractor = new();

    private static ExtractedValuesDto ReadLicence(OcrPayloadDto licence)
        => Extractor.Extract(null, licence, null, null);

    private static ExtractedValuesDto ReadReceipt(OcrPayloadDto receipt)
        => Extractor.Extract(null, null, receipt, null);

    // ── School form (regression) ────────────────────────────────────────────

    [Fact]
    public void SecondRafStillReadsAllFourFields()
    {
        var result = Extractor.Extract(RafSecondProbeFixture.Payload(), null, null, null);

        Assert.Equal(RafSecondProbeFixture.StudentNumber, result.StudentNumber);
        Assert.Equal(RafSecondProbeFixture.StudentName, result.StudentName);
        Assert.Equal(RafSecondProbeFixture.Section, result.Section);
        Assert.Equal(RafSecondProbeFixture.Semester, result.Semester);
    }

    [Fact]
    public void AllThreeDocumentsTogetherStillReadEveryField()
    {
        var result = Extractor.Extract(
            RafSecondProbeFixture.Payload(),
            LicenceProbeFixture.Second(),
            ReceiptProbeFixture.Second(),
            null);

        Assert.Equal(RafSecondProbeFixture.StudentNumber, result.StudentNumber);
        Assert.Equal(LicenceProbeFixture.Number, result.LicenseNumber);
        Assert.Equal(LicenceProbeFixture.Expiry, result.LicenseExpiry);
        Assert.Equal(ReceiptProbeFixture.Plate, result.PlateNumber);
        Assert.Equal("Motorcycle", result.VehicleType);
        Assert.Equal(ReceiptProbeFixture.Color, result.Color);
        Assert.Empty(result.FieldsToCheck);
    }

    // ── Licence ─────────────────────────────────────────────────────────────

    [Fact]
    public void ReadsTheNumberAndExpiryFromOneMergedLine()
    {
        var result = ReadLicence(LicenceProbeFixture.Second());

        Assert.Equal(LicenceProbeFixture.Name, result.LicenseName);
        Assert.Equal(LicenceProbeFixture.Number, result.LicenseNumber);
        Assert.Equal(LicenceProbeFixture.Expiry, result.LicenseExpiry);
    }

    [Fact]
    public void ClosesAStraySpaceInsideTheExpiryDate()
    {
        // The first photo read 2028/03/15 as "2028/0 3/15".
        var result = ReadLicence(LicenceProbeFixture.First());

        Assert.Equal(LicenceProbeFixture.Name, result.LicenseName);
        Assert.Equal(LicenceProbeFixture.Number, result.LicenseNumber);
        Assert.Equal(LicenceProbeFixture.Expiry, result.LicenseExpiry);
    }

    [Fact]
    public void FindsTheNumberByShapeWhenItsCaptionIsMisread()
    {
        var licence = LicenceProbeFixture.Second();

        // Proves the fallback path is the one being exercised: "LjcenseNd." is too
        // damaged to match any spelling of the caption.
        Assert.Null(OcrLayout.FindAnyLabel(
            OcrCleanup.Prepare(licence.Lines), DocumentLabels.License.Number));

        Assert.Equal(LicenceProbeFixture.Number, ReadLicence(licence).LicenseNumber);
    }

    [Fact]
    public void MissingExpiryIsNotFoundRatherThanAnotherDateOnTheCard()
    {
        var licence = LicenceProbeFixture.Replace(
            LicenceProbeFixture.Second(), LicenceProbeFixture.SecondValueLine, "C66-24-004321");

        var result = ReadLicence(licence);

        Assert.Null(result.LicenseExpiry);
        Assert.True(result.IsFlagged(nameof(result.LicenseExpiry)));
        Assert.Equal(LicenceProbeFixture.Number, result.LicenseNumber);
    }

    [Fact]
    public void MissingExpiryCaptionIsNotFoundRatherThanTheBirthOrIssueDate()
    {
        var licence = LicenceProbeFixture.Without(LicenceProbeFixture.Second(), "Expiration Date");

        var result = ReadLicence(licence);

        Assert.Null(result.LicenseExpiry);
        Assert.NotEqual(LicenceProbeFixture.BirthDate, result.LicenseExpiry);
        Assert.NotEqual(LicenceProbeFixture.IssueDate, result.LicenseExpiry);
    }

    [Fact]
    public void TwoLicenceShapedNumbersWithNoReadableCaptionIsNotFound()
    {
        var licence = LicenceProbeFixture.With(
            LicenceProbeFixture.Second(),
            LicenceProbeFixture.Line("D12-34-567890", 300, 2100, 300, 40, 0.80));

        var result = ReadLicence(licence);

        Assert.Null(result.LicenseNumber);
        Assert.True(result.IsFlagged(nameof(result.LicenseNumber)));
    }

    [Fact]
    public void MissingValueLineLeavesNumberAndExpiryNotFound()
    {
        var licence = LicenceProbeFixture.Without(
            LicenceProbeFixture.First(), "C66-24-004321 2028/0 3/15");

        var result = ReadLicence(licence);

        Assert.Null(result.LicenseNumber);
        Assert.Null(result.LicenseExpiry);
    }

    [Fact]
    public void TheAgencyCodeIsNotCreditedWithTheValueUnderTheCaptionBesideIt()
    {
        var lines = OcrCleanup.Prepare(LicenceProbeFixture.Second().Lines);
        var agency = OcrLayout.FindLabel(lines, "Agency Code");

        Assert.NotNull(agency);
        Assert.Equal("C66", OcrLayout.ValueBelow(lines, agency!, DocumentLabels.License.Captions)?.Text);
    }

    [Fact]
    public void ValueBelowStopsAtTheNextCaptionInsteadOfReadingIt()
    {
        var caption = LicenceProbeFixture.Line("Expiration Date", 10, 10, 300, 40, 0.9);
        var nextCaption = LicenceProbeFixture.Line("Blood Type", 10, 60, 200, 40, 0.9);
        var lines = new List<OcrLineDto> { caption, nextCaption };

        Assert.Same(nextCaption, OcrLayout.ValueBelow(lines, caption));
        Assert.Null(OcrLayout.ValueBelow(lines, caption, DocumentLabels.License.Captions));
    }

    // ── Official receipt ────────────────────────────────────────────────────

    [Fact]
    public void ReadsTheColourWhenItIsSplitFromItsLabel()
    {
        var result = ReadReceipt(ReceiptProbeFixture.First());

        Assert.Equal(ReceiptProbeFixture.Plate, result.PlateNumber);
        Assert.Equal(ReceiptProbeFixture.Expiry, result.RegistrationExpiry);
        Assert.Equal("Motorcycle", result.VehicleType);
        Assert.Equal(ReceiptProbeFixture.Color, result.Color);
    }

    [Fact]
    public void ReadsTheVehicleTypeWhenItIsSplitFromItsLabel()
    {
        var result = ReadReceipt(ReceiptProbeFixture.Second());

        Assert.Equal(ReceiptProbeFixture.Plate, result.PlateNumber);
        Assert.Equal(ReceiptProbeFixture.Expiry, result.RegistrationExpiry);
        Assert.Equal("Motorcycle", result.VehicleType);
        Assert.Equal(ReceiptProbeFixture.Color, result.Color);
    }

    [Fact]
    public void MissingVehicleTypeDoesNotReachAcrossToTheFeeTable()
    {
        // With its value gone, the nearest line on the row is "Registration" in the
        // fee table. Taking it would record the motorcycle as a car.
        var receipt = ReceiptProbeFixture.Without(
            ReceiptProbeFixture.Second(), ReceiptProbeFixture.SecondVehicleTypeValue);

        var result = ReadReceipt(receipt);

        Assert.Null(result.VehicleType);
    }

    // The plate is printed large and bold, so the OCR can return the label and the
    // plate as two lines. The photos above happened to keep them together.
    private static OcrPayloadDto WithSplitPlate(OcrPayloadDto receipt, string label, string combined) =>
        ReceiptProbeFixture.Split(
            receipt,
            combined,
            ReceiptProbeFixture.Line(label, 377, 1530, 190, 40, 0.85),
            ReceiptProbeFixture.Line(ReceiptProbeFixture.Plate, 640, 1520, 300, 64, 0.88));

    [Fact]
    public void ReadsThePlateWhenItIsSplitFromItsLabel()
    {
        var receipt = WithSplitPlate(ReceiptProbeFixture.Second(), "Plate No:", "Plate No: 482KLM");

        Assert.Equal(ReceiptProbeFixture.Plate, ReadReceipt(receipt).PlateNumber);
    }

    [Fact]
    public void ReadsThePlateWhenTheLabelIsMisreadAndSplit()
    {
        var receipt = WithSplitPlate(ReceiptProbeFixture.First(), "Plote No:", "Plate No: 482KLM");

        Assert.Equal(ReceiptProbeFixture.Plate, ReadReceipt(receipt).PlateNumber);
    }

    [Fact]
    public void ThePlateIsStillReadWhenLabelAndValueShareALine()
    {
        Assert.Equal(ReceiptProbeFixture.Plate, ReadReceipt(ReceiptProbeFixture.First()).PlateNumber);
        Assert.Equal(ReceiptProbeFixture.Plate, ReadReceipt(ReceiptProbeFixture.Second()).PlateNumber);
    }

    [Fact]
    public void MissingPlateDoesNotReachAcrossToTheFeeTableOrTheFileNumber()
    {
        // Only the label is left. On its row, to the right, sit "MVUC" and the fee
        // table; below it sits the File No. None of them may stand in for the plate.
        var receipt = ReceiptProbeFixture.Split(
            ReceiptProbeFixture.Second(),
            "Plate No: 482KLM",
            ReceiptProbeFixture.Line("Plate No:", 377, 1530, 190, 40, 0.85));

        var result = ReadReceipt(receipt);

        Assert.Null(result.PlateNumber);
        Assert.True(result.IsFlagged(nameof(result.PlateNumber)));
    }

    [Fact]
    public void VehicleTypeIsNotReadFromTheNextFieldsCaption()
    {
        var receipt = new OcrPayloadDto
        {
            DocumentType = Enums.DocumentType.OfficialReceipt,
            ImageWidth = 1000,
            ImageHeight = 1000,
            Lines =
            [
                LicenceProbeFixture.Line("Vehicle Type:", 10, 10, 200, 40, 0.9),
                LicenceProbeFixture.Line("Fuel Type:", 250, 10, 150, 40, 0.9),
            ]
        };

        Assert.Null(ReadReceipt(receipt).VehicleType);
    }
}
