using AimPark.API.Entities;
using AimPark.API.Enums;
using AimPark.API.Helpers;

namespace AimPark.API.Tests;

/// <summary>
/// The review panel's arrangement of the stored checks. Sample data only.
/// </summary>
public class RegistrationChecksTests
{
    private static readonly DateTime Now = new(2026, 10, 12, 0, 0, 0, DateTimeKind.Utc);

    private static User Student() => new()
    {
        Id = Guid.NewGuid(), FullName = "Sample Student", Email = "sample@x.test",
        Affiliation = Affiliation.Student
    };

    private static DocumentVerification CleanRow(Guid userId, string? semester = "1st Term 2026-2027") => new()
    {
        UserId = userId,
        ExtractedStudentName = "Sample Student",
        ExtractedStudentNumber = "02000000000",
        ExtractedSemester = semester,
        ExtractedLicenseName = "SAMPLE STUDENT",
        ExtractedLicenseNumber = "X00000000000",
        ExtractedLicenseExpiry = Now.AddYears(2),
        ExtractedPlateNumber = "TST 0000",
        ExtractedRegistrationExpiry = Now.AddYears(1),
        NameMatch = CheckResult.Passed,
        PlateMatch = CheckResult.Passed,
        CreatedAt = Now
    };

    [Fact]
    public void AReadTermIsNotCheckedNeverPassedAndDoesNotChangeTheVerdict()
    {
        var user = Student();
        var checks = RegistrationChecks.Build(user, [CleanRow(user.Id)], [], Now)!;

        var enrolment = checks.Person!.Checks.Single(c => c.Key == "EnrollmentValidity");
        Assert.Equal(RegistrationChecks.NotChecked, enrolment.State);
        Assert.Contains("does not know the current term", enrolment.Detail);

        // Left to the reviewer, not unreadable: approval must not start asking
        // for an override note on every clean student application.
        Assert.Equal(RegistrationChecks.ClearVerdict, checks.Verdict);
        Assert.Equal(0, checks.Unreadable);

        var finding = checks.Findings.Single(f => f.Key == "EnrollmentValidity");
        Assert.Equal(RegistrationChecks.NotChecked, finding.Category);
        Assert.Equal(RegistrationChecks.Neutral, finding.Severity);
        Assert.Empty(RegistrationChecks.Flagged(checks));
    }

    [Fact]
    public void AnUnreadTermStillCountsAsUnreadable()
    {
        var user = Student();
        var checks = RegistrationChecks.Build(user, [CleanRow(user.Id, semester: null)], [], Now)!;

        Assert.Equal("Unreadable", checks.Verdict);
        Assert.Equal(1, checks.Unreadable);
        Assert.Single(RegistrationChecks.Flagged(checks));
    }

    [Fact]
    public void IdentityComesBeforeValidityAndTheLicenceNumberIsMasked()
    {
        var user = Student();
        var row = CleanRow(user.Id);
        row.NameMatch = CheckResult.Failed;
        row.ConfirmedStudentName = "Someone Else";
        row.ExtractedRegistrationExpiry = Now.AddDays(-3);
        row.ExtractedLicenseNumber = null;
        row.ConfirmedLicenseNumber = "X99999991234";

        var checks = RegistrationChecks.Build(user, [row], [], Now)!;
        var titles = checks.Findings.Select(f => f.Title).ToList();

        Assert.Equal("Name mismatch", titles[0]);
        Assert.True(titles.IndexOf("Licence number typed by applicant") < titles.IndexOf("Registration expired"));
        Assert.Equal("••••••••1234", checks.Facts.LicenseNumberMasked);
        Assert.True(checks.Facts.LicenseNumberTyped);
        Assert.DoesNotContain(checks.Findings, f => f.Detail?.Contains("X99999991234") == true);
    }
}
