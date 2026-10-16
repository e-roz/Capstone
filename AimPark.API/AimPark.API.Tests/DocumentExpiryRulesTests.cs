using AimPark.API.DTOs;
using AimPark.API.Entities;
using AimPark.API.Enums;
using AimPark.API.Helpers;

namespace AimPark.API.Tests;

/// <summary>
/// An expired licence or registration stops registration; edits and typed dates
/// reach the reviewer flagged. Sample data only.
/// </summary>
public class DocumentExpiryRulesTests
{
    private static readonly DateOnly Today = new(2026, 10, 16);

    private static DateTime Day(int year, int month, int day) => new(year, month, day, 0, 0, 0, DateTimeKind.Utc);

    private static OcrLineDto Line(string text) => new() { Text = text, X = 0, Y = 0, W = 300, H = 40, Confidence = 0.9 };

    // ── Refusal ─────────────────────────────────────────────────────────────

    [Fact]
    public void AnExpiredLicenceStopsRegistrationAndSaysWhichDateWasRead()
    {
        var refusal = DocumentExpiryRules.LicenceRefusal(Day(2023, 12, 20), Today);

        Assert.NotNull(refusal);
        Assert.Contains("December 20, 2023", refusal);
        Assert.Contains("expired", refusal);
    }

    [Fact]
    public void ALicenceIsStillGoodOnTheDayItExpires()
    {
        Assert.Null(DocumentExpiryRules.LicenceRefusal(Day(2026, 10, 16), Today));
        Assert.NotNull(DocumentExpiryRules.LicenceRefusal(Day(2026, 10, 15), Today));
    }

    [Fact]
    public void ALicenceWithNoDateIsNotRefused()
    {
        // A blank is the reviewer's question, not grounds for locking someone out.
        Assert.Null(DocumentExpiryRules.LicenceRefusal(null, Today));
    }

    [Fact]
    public void AnExpiredRegistrationThatWasReadStopsRegistration()
    {
        Assert.NotNull(DocumentExpiryRules.RegistrationRefusal(Day(2025, 5, 31), calculated: false, Today));
    }

    [Fact]
    public void ACalculatedRegistrationDateNeverBlocks()
    {
        // Worked out from the plate's last digit: a misread digit moves it by months.
        Assert.Null(DocumentExpiryRules.RegistrationRefusal(Day(2025, 5, 31), calculated: true, Today));
    }

    // ── Reviewer notes ──────────────────────────────────────────────────────

    [Fact]
    public void EditingAnExpiredReadingIntoAValidDateIsNoted()
    {
        var note = DocumentExpiryRules.ExpiredReadingEditedNote(
            "licence", read: Day(2023, 12, 20), submitted: Day(2028, 12, 20), Today);

        Assert.NotNull(note);
        Assert.StartsWith(DocumentExpiryRules.ExpiredReadingEditedMarker, note);
    }

    [Fact]
    public void CorrectingAValidReadingIsNotTheExpiredDateEdit()
    {
        Assert.Null(DocumentExpiryRules.ExpiredReadingEditedNote(
            "licence", read: Day(2027, 1, 1), submitted: Day(2028, 12, 20), Today));
    }

    [Fact]
    public void ATypedDateMissingFromThePhotoIsNoted()
    {
        var note = DocumentExpiryRules.TypedDateNotOnPhotoNote(
            "licence expiry", read: null, submitted: Day(2030, 1, 1),
            [Line("C66-24-000000 2028/12/20"), Line("2005/12/20")]);

        Assert.NotNull(note);
        Assert.StartsWith(DocumentExpiryRules.TypedDateNotOnPhotoMarker, note);
    }

    [Fact]
    public void ATypedDateThatThePhotoShowsIsNotNoted()
    {
        Assert.Null(DocumentExpiryRules.TypedDateNotOnPhotoNote(
            "licence expiry", read: null, submitted: Day(2028, 12, 20),
            [Line("C66-24-000000 2028/12/20")]));
    }

    [Fact]
    public void ATypedRegistrationExpiryMatchesAMonthAndYearOnTheReceipt()
    {
        // Receipts print "valid until 05/2027", stored as the month's last day.
        Assert.Null(DocumentExpiryRules.TypedDateNotOnPhotoNote(
            "registration expiry", read: null, submitted: Day(2027, 5, 31),
            [Line("This payment is valid until"), Line("05/2027 and due for")]));
    }

    [Fact]
    public void NothingIsSaidWhenTheDateWasReadOrThePhotoHadNoText()
    {
        Assert.Null(DocumentExpiryRules.TypedDateNotOnPhotoNote(
            "licence expiry", read: Day(2028, 12, 20), submitted: Day(2030, 1, 1), [Line("2028/12/20")]));
        Assert.Null(DocumentExpiryRules.TypedDateNotOnPhotoNote(
            "licence expiry", read: null, submitted: Day(2030, 1, 1), []));
    }

    // ── Shown to the reviewer ───────────────────────────────────────────────

    [Fact]
    public void BothNotesReachTheReviewerAsFindings()
    {
        var now = Day(2026, 10, 16);
        var user = new User
        {
            Id = Guid.NewGuid(), FullName = "Sample Driver", Email = "sample@x.test",
            Affiliation = Affiliation.Faculty
        };

        var expiredEdit = DocumentExpiryRules.ExpiredReadingEditedNote(
            "licence", Day(2023, 12, 20), Day(2028, 12, 20), Today);
        var typedDate = DocumentExpiryRules.TypedDateNotOnPhotoNote(
            "registration expiry", null, Day(2030, 1, 31), [Line("05/2027 and due for")]);

        var row = new DocumentVerification
        {
            UserId = user.Id,
            ExtractedLicenseName = "SAMPLE DRIVER",
            ExtractedLicenseNumber = "X00000000000",
            ExtractedLicenseExpiry = Day(2023, 12, 20),
            ConfirmedLicenseExpiry = Day(2028, 12, 20),
            ExtractedPlateNumber = "TST 0000",
            ConfirmedRegistrationExpiry = Day(2030, 1, 31),
            NameMatch = CheckResult.NotChecked,
            PlateMatch = CheckResult.Passed,
            Notes = expiredEdit + "\n" + typedDate,
            CreatedAt = now
        };

        var checks = RegistrationChecks.Build(user, [row], [], now)!;

        var expired = checks.Findings.Single(f => f.Title == "Expired date changed by applicant");
        Assert.Equal(RegistrationChecks.Danger, expired.Severity);
        Assert.Equal("License", expired.Document);

        var typed = checks.Findings.Single(f => f.Title == "Typed date not found on the photo");
        Assert.Equal(RegistrationChecks.Warning, typed.Severity);
        Assert.Equal("OfficialReceipt", typed.Document);
    }

    [Fact]
    public void FacultyAreToldWhyTheirNameIsNotCompared()
    {
        var now = Day(2026, 10, 16);
        var user = new User
        {
            Id = Guid.NewGuid(), FullName = "", Email = "sample@x.test",
            Affiliation = Affiliation.Faculty
        };
        var row = new DocumentVerification
        {
            UserId = user.Id,
            ExtractedLicenseName = "SAMPLE DRIVER",
            ExtractedLicenseExpiry = Day(2028, 12, 20),
            NameMatch = CheckResult.NotChecked,
            CreatedAt = now
        };

        var checks = RegistrationChecks.Build(user, [row], [], now)!;

        var name = checks.Findings.Single(f => f.Key == "NameMatch");
        Assert.Contains("only a licence", name.Detail);
    }
}
