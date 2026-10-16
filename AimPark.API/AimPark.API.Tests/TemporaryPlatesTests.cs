using AimPark.API.Entities;
using AimPark.API.Enums;
using AimPark.API.Helpers;

namespace AimPark.API.Tests;

/// <summary>
/// Temporary plates for a vehicle with no plate of its own, and what the reviewer
/// is told about one. Sample data only.
/// </summary>
public class TemporaryPlatesTests
{
    // ── Telling a temporary plate from a real one ───────────────────────────

    [Theory]
    [InlineData("TP0001", true)]
    [InlineData("TP-0042", true)]
    [InlineData("tp 0007", true)]
    [InlineData("TP12345", true)]
    [InlineData("EB0001", false)]   // an e-bike's, not a motor vehicle's
    [InlineData("TPA1234", false)]  // a real car plate that happens to start with TP
    [InlineData("TP123", false)]    // too short to be issued
    [InlineData("705TEY", false)]
    [InlineData("", false)]
    [InlineData(null, false)]
    public void RecognisesAMotorVehicleTemporaryPlate(string? plate, bool expected)
        => Assert.Equal(expected, TemporaryPlates.IsVehicleTemporary(plate));

    [Theory]
    [InlineData("EB0001", true)]
    [InlineData("TP0001", true)]
    [InlineData("TPA1234", false)]
    [InlineData("705TEY", false)]
    public void RecognisesEitherKindOfTemporaryPlate(string plate, bool expected)
        => Assert.Equal(expected, TemporaryPlates.IsTemporary(plate));

    // ── Numbering ───────────────────────────────────────────────────────────

    [Fact]
    public void TheFirstPlateIsOne()
        => Assert.Equal("TP0001", TemporaryPlates.Next("TP", []));

    [Fact]
    public void TheNextPlateFollowsTheHighest()
        => Assert.Equal("TP0008", TemporaryPlates.Next("TP", ["TP0003", "TP0007", "TP0001"]));

    [Fact]
    public void ARealPlateStartingWithTheSameLettersDoesNotMoveTheNumbering()
    {
        // "TPA1234" is somebody's car. Its suffix is not a number and must not
        // count, nor throw.
        Assert.Equal("TP0003", TemporaryPlates.Next("TP", ["TP0002", "TPA1234", "TP-X"]));
    }

    [Fact]
    public void EachKindIsNumberedOnItsOwn()
    {
        var plates = new[] { "EB0009", "TP0002" };

        Assert.Equal("EB0010", TemporaryPlates.Next("EB", plates));
        Assert.Equal("TP0003", TemporaryPlates.Next("TP", plates));
    }

    [Fact]
    public void NumberingContinuesPastFourDigits()
        => Assert.Equal("TP10000", TemporaryPlates.Next("TP", ["TP9999"]));

    // ── Display ─────────────────────────────────────────────────────────────

    [Theory]
    [InlineData("TP0007", "TP-0007")]
    [InlineData("EB0001", "EB-0001")]
    [InlineData("705TEY", "705TEY")]
    [InlineData("TPA1234", "TPA1234")]
    public void ShowsATemporaryPlateWithItsDash(string plate, string shown)
        => Assert.Equal(shown, TemporaryPlates.Format(plate));

    // ── What the reviewer sees ──────────────────────────────────────────────

    private static readonly DateTime Now = new(2026, 10, 16, 0, 0, 0, DateTimeKind.Utc);

    private static User Applicant() => new()
    {
        Id = Guid.NewGuid(), FullName = "Sample Driver", Email = "sample@x.test",
        Affiliation = Affiliation.Student
    };

    private static DocumentVerification NoPlateRow(Guid userId) => new()
    {
        UserId = userId,
        ExtractedLicenseName = "SAMPLE DRIVER",
        ExtractedLicenseNumber = "X00000000000",
        ExtractedLicenseExpiry = Now.AddYears(2),
        ExtractedRegistrationExpiry = Now.AddYears(1),
        NameMatch = CheckResult.Passed,
        PlateMatch = CheckResult.NotChecked,
        Notes = $"{RegistrationChecks.NoPlateMarker} — the applicant says the vehicle has no plate, and none "
                + "was found on the receipt. The temporary plate TP-0007 is reserved. See the vehicle in "
                + "person before approving.",
        CreatedAt = Now
    };

    [Fact]
    public void ANoPlateApplicationReachesTheReviewerAsARedFinding()
    {
        var user = Applicant();
        var checks = RegistrationChecks.Build(user, [NoPlateRow(user.Id)], [], Now)!;

        var finding = checks.Findings.Single(f => f.Key == "NoPlate");

        Assert.Equal("No plate on the vehicle", finding.Title);
        Assert.Equal(RegistrationChecks.Danger, finding.Severity);
        Assert.Equal("OfficialReceipt", finding.Document);
        Assert.Contains("TP-0007", finding.Detail);
    }

    [Fact]
    public void ThePlateCheckSaysThereIsNoPlateRatherThanThatItCouldNotBeRead()
    {
        var user = Applicant();
        var vehicle = new Vehicle { UserId = user.Id, PlateNumber = "TP0007", Color = "Red" };
        var row = NoPlateRow(user.Id);
        row.VehicleId = vehicle.Id;

        var checks = RegistrationChecks.Build(user, [row], [vehicle], Now)!;

        var plate = checks.Vehicles.SelectMany(g => g.Checks).Single(c => c.Key == "PlateMatch");

        Assert.Equal(RegistrationChecks.NotChecked, plate.State);
        Assert.Contains("no plate yet", plate.Detail);
        Assert.DoesNotContain("Could not read", plate.Detail);
    }

    [Fact]
    public void ApprovingAVehicleWithNoPlateNeedsANote()
    {
        // NotChecked counts as unreadable, so the verdict is not Clear and the
        // approval asks for a note. That note is where the reviewer says they
        // saw the vehicle: no new screen is needed.
        var user = Applicant();
        var vehicle = new Vehicle { UserId = user.Id, PlateNumber = "TP0007", Color = "Red" };
        var row = NoPlateRow(user.Id);
        row.VehicleId = vehicle.Id;

        var checks = RegistrationChecks.Build(user, [row], [vehicle], Now)!;

        Assert.NotEqual(RegistrationChecks.ClearVerdict, checks.Verdict);
    }

    [Fact]
    public void AReceiptThatSimplyDidNotReadStillSaysSo()
    {
        var user = Applicant();
        var row = NoPlateRow(user.Id);
        row.Notes = null;

        var checks = RegistrationChecks.Build(user, [row], [], Now)!;

        var plate = checks.Vehicles.SelectMany(g => g.Checks).SingleOrDefault(c => c.Key == "PlateMatch");

        Assert.DoesNotContain(checks.Findings, f => f.Key == "NoPlate");
        if (plate is not null)
            Assert.Contains("Could not read", plate.Detail);
    }
}
