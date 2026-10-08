using AimPark.API.Data;
using AimPark.API.DTOs;
using AimPark.API.Entities;
using AimPark.API.Enums;
using AimPark.API.Helpers;
using AimPark.API.Services;
using Microsoft.EntityFrameworkCore;

namespace AimPark.API.Tests;

/// <summary>
/// A second applicant presenting a first applicant's documents.
/// </summary>
public class DuplicateIdentityTests
{
    private static AppDbContext NewDb() => new(new DbContextOptionsBuilder<AppDbContext>()
        .UseInMemoryDatabase(Guid.NewGuid().ToString())
        .Options);

    private static DuplicateIdentityGuard GuardFor(AppDbContext db) => new(
        new Repository<User>(db), new Repository<Vehicle>(db), new Repository<DocumentVerification>(db));

    private static async Task<User> SubmittedApplicantAsync(
        AppDbContext db,
        string? readStudent = "02000199887",
        string? typedStudent = null,
        string? readLicense = "N01-23-456789",
        AccountStatus status = AccountStatus.PendingReview,
        RegistrationStep step = RegistrationStep.Completed)
    {
        var user = new User
        {
            Id = Guid.NewGuid(), FullName = "Maria Santos", Email = $"{Guid.NewGuid()}@x.test",
            RegistrationStep = step, AccountStatus = status
        };
        db.Users.Add(user);
        db.DocumentVerifications.Add(new DocumentVerification
        {
            UserId = user.Id,
            ExtractedStudentNumber = readStudent,
            ConfirmedStudentNumber = typedStudent,
            ExtractedLicenseNumber = IdentifierNormalizer.NormalizeLicenseNumber(readLicense),
        });
        await db.SaveChangesAsync();
        return user;
    }

    private static Task<DuplicateHit?> CheckAsync(
        AppDbContext db, Guid applicant,
        string? student = null, string? license = null, string? plate = null) =>
        GuardFor(db).FindAsync(applicant, "scan", [student], [license], [plate], default);

    [Fact]
    public async Task StopsASecondApplicantWhoseDocumentCarriesTheSameStudentNumber()
    {
        var db = NewDb();
        var a = await SubmittedApplicantAsync(db);

        var hit = await CheckAsync(db, Guid.NewGuid(), student: "02000199887");

        Assert.NotNull(hit);
        Assert.Equal(a.Id, hit!.HolderUserId);
        Assert.Equal("student number", hit.Field);
    }

    [Fact]
    public async Task StopsTheSameLicenceWhateverDashesOrSpacesOcrProduced()
    {
        var db = NewDb();
        await SubmittedApplicantAsync(db, readLicense: "N01-23-456789");

        Assert.NotNull(await CheckAsync(db, Guid.NewGuid(), license: "n01 23 456789"));
        Assert.NotNull(await CheckAsync(db, Guid.NewGuid(), license: "N0123456789"));
    }

    [Fact]
    public async Task StillStopsWhenTheOriginalApplicantEditedTheirOwnForm()
    {
        // A's stored reading is what the camera saw; B presenting the same paper
        // collides with it no matter what A later typed over it.
        var db = NewDb();
        await SubmittedApplicantAsync(db, readStudent: "02000199887", typedStudent: "02000199888");

        Assert.NotNull(await CheckAsync(db, Guid.NewGuid(), student: "02000199887"));
    }

    [Fact]
    public async Task StopsAStudentNumberHeldByAnApprovedAccount()
    {
        var db = NewDb();
        var holder = new User
        {
            Id = Guid.NewGuid(), FullName = "Approved", Email = "approved@x.test",
            StudentNumber = "02000555555", AccountStatus = AccountStatus.Active,
            RegistrationStep = RegistrationStep.Completed
        };
        db.Users.Add(holder);
        await db.SaveChangesAsync();

        var hit = await CheckAsync(db, Guid.NewGuid(), student: "02000555555");

        Assert.Equal(holder.Id, hit!.HolderUserId);
    }

    [Fact]
    public async Task StopsAPlateAlreadyOnAnotherAccount()
    {
        var db = NewDb();
        var owner = await SubmittedApplicantAsync(db);
        db.vehicles.Add(new Vehicle { PlateNumber = "ABC1234", UserId = owner.Id });
        await db.SaveChangesAsync();

        Assert.NotNull(await CheckAsync(db, Guid.NewGuid(), plate: "abc 1234"));
    }

    [Fact]
    public async Task NeverCollidesWithTheApplicantsOwnEarlierAttempts()
    {
        var db = NewDb();
        var a = await SubmittedApplicantAsync(db);

        Assert.Null(await CheckAsync(db, a.Id, student: "02000199887", license: "N01-23-456789"));
    }

    [Fact]
    public async Task IgnoresAnAbandonedScanThatWasNeverConfirmed()
    {
        // An unconfirmed scan leaves a row behind. It must not lock a stranger out
        // of their own student number.
        var db = NewDb();
        await SubmittedApplicantAsync(db, step: RegistrationStep.DocumentUpload,
            status: AccountStatus.PendingReview);

        Assert.Null(await CheckAsync(db, Guid.NewGuid(), student: "02000199887"));
    }

    [Fact]
    public async Task IgnoresARejectedApplicant()
    {
        var db = NewDb();
        await SubmittedApplicantAsync(db, status: AccountStatus.Rejected);

        Assert.Null(await CheckAsync(db, Guid.NewGuid(), student: "02000199887"));
    }

    [Fact]
    public async Task LetsDistinctDocumentsThrough()
    {
        var db = NewDb();
        await SubmittedApplicantAsync(db);

        Assert.Null(await CheckAsync(db, Guid.NewGuid(),
            student: "02000111111", license: "N99-88-777777", plate: "XYZ9999"));
    }

    [Fact]
    public async Task IgnoresBlankValues()
    {
        var db = NewDb();
        await SubmittedApplicantAsync(db, readStudent: null);

        Assert.Null(await CheckAsync(db, Guid.NewGuid(), student: "  ", license: null, plate: ""));
    }
}

public class AutoApprovalPolicyTests
{
    private static RegistrationChecksResponse Checks(string verdict, bool identityEdit = false) => new()
    {
        Verdict = verdict,
        Edits = identityEdit
            ? [new ValueEditResponse { Field = "Name", Submitted = "x", IsIdentity = true }]
            : []
    };

    [Fact]
    public void ApprovesACleanApplicationOutsideTheSpotCheck() =>
        Assert.True(AutoApprovalPolicy.ShouldAutoApprove(
            Checks(RegistrationChecks.ClearVerdict), true, AutoApprovalPolicy.SpotCheckPercent));

    [Fact]
    public void SendsASpotCheckedApplicationToAReviewer() =>
        Assert.False(AutoApprovalPolicy.ShouldAutoApprove(
            Checks(RegistrationChecks.ClearVerdict), true, AutoApprovalPolicy.SpotCheckPercent - 1));

    [Theory]
    [InlineData("LookCloser")]
    [InlineData("Unreadable")]
    public void NeverApprovesWhenAnyCheckNeedsAttention(string verdict) =>
        Assert.False(AutoApprovalPolicy.ShouldAutoApprove(Checks(verdict), true, 99));

    [Fact]
    public void NeverApprovesAfterAnIdentityFieldWasEdited() =>
        Assert.False(AutoApprovalPolicy.ShouldAutoApprove(
            Checks(RegistrationChecks.ClearVerdict, identityEdit: true), true, 99));

    [Fact]
    public void NeverApprovesWithoutTheIdentifiersTheDuplicateCheckNeeds() =>
        Assert.False(AutoApprovalPolicy.ShouldAutoApprove(
            Checks(RegistrationChecks.ClearVerdict), false, 99));

    [Fact]
    public void NeverApprovesWhenThereAreNoChecks() =>
        Assert.False(AutoApprovalPolicy.ShouldAutoApprove(null, true, 99));
}

public class LicenseNumberExtractionTests
{
    private static readonly DocumentExtractionService Extractor = new();

    private static OcrPayloadDto Licence(params string[] lines) => new()
    {
        DocumentType = DocumentType.License,
        ImageWidth = 1000,
        ImageHeight = 1000,
        Lines = lines.Select((t, i) => new OcrLineDto
        {
            Text = t, X = 10, Y = 10 + i * 60, W = 400, H = 40, Confidence = 0.9
        }).ToList()
    };

    [Fact]
    public void ReadsTheNumberPrintedBelowItsCaption()
    {
        var result = Extractor.Extract(null, Licence("License No.", "N01-23-456789"), null, null);

        Assert.Equal("N0123456789", result.LicenseNumber);
    }

    [Fact]
    public void RefusesANameStandingInForAMissedNumber()
    {
        // If the caption matched but its value did not read, the next line is a
        // name. That must come back as "not found", not as a number.
        var result = Extractor.Extract(null, Licence("License No.", "SANTOS, MARIA ELENA"), null, null);

        Assert.Null(result.LicenseNumber);
        Assert.True(result.IsFlagged(nameof(result.LicenseNumber)));
    }

    [Fact]
    public void NormalizerIgnoresCaseSpacesAndDashes()
    {
        Assert.Equal(
            IdentifierNormalizer.NormalizeLicenseNumber("N01-23-456789"),
            IdentifierNormalizer.NormalizeLicenseNumber(" n01 23 456789 "));
    }

    [Fact]
    public void StudentNumberKeepsItsLeadingZero() =>
        Assert.Equal("02000199887", IdentifierNormalizer.NormalizeStudentNumber(" 0200-0199887 "));
}
