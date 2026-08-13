using AimPark.API.Helpers;

namespace AimPark.API.Tests;

public class DateExtractionTests
{
    [Fact]
    public void TakesTheExpiryAndNotTheRenewalWindowBehindIt()
    {
        // The receipt reads "valid until 01/2026 and due for renewal on
        // 01/22/2026-01/31/2026". The dates after the expiry are the renewal window,
        // and a rule that accepts MM/DD/YYYY captures one of those instead.
        var text = "This payment is valid until 01/2026 and due for renewal on 01/22/2026-01/31/2026.";

        var expiry = DateExtraction.FindMonthYear(text);

        Assert.NotNull(expiry);
        Assert.Equal(2026, expiry!.Value.Year);
        Assert.Equal(1, expiry.Value.Month);
    }

    [Fact]
    public void ReturnsTheLastDayOfTheMonthForAnExpiry()
    {
        // Registration is valid through the whole month; taking the first day would
        // expire people early.
        Assert.Equal(31, DateExtraction.FindMonthYear("valid until 01/2026")!.Value.Day);
    }

    [Fact]
    public void ReadsAReceiptDateMonthFirst()
    {
        var date = DateExtraction.FindFullDate("Date: 07/11/2025");

        Assert.Equal(new DateTime(2025, 7, 11, 0, 0, 0, DateTimeKind.Utc), date);
    }

    [Fact]
    public void ReadsALicenceDateYearFirst()
    {
        Assert.Equal(
            new DateTime(2027, 5, 14, 0, 0, 0, DateTimeKind.Utc),
            DateExtraction.FindFullDate("Expiration Date 2027/05/14"));
    }

    [Fact]
    public void RepairsLookalikeDigitsBeforeReading()
    {
        // Observed on a real receipt: "o7/11/2025".
        Assert.Equal(
            new DateTime(2025, 7, 11, 0, 0, 0, DateTimeKind.Utc),
            DateExtraction.FindFullDate("Date: o7/11/2025"));
    }

    [Fact]
    public void RejectsAnImpossibleDate()
    {
        Assert.Null(DateExtraction.FindFullDate("Date: 13/45/2025"));
    }

    [Fact]
    public void ReturnsNothingWhenThereIsNoDate()
    {
        Assert.Null(DateExtraction.FindFullDate("Plate No: 130301"));
        Assert.Null(DateExtraction.FindMonthYear(null));
    }
}

/// <summary>
/// The plate-digit renewal rule, which stands in for an expiry the camera could not
/// read.
/// </summary>
public class RegistrationRenewalTests
{
    [Fact]
    public void DerivesTheExpiryPrintedOnTheSampleReceipt()
    {
        // Plate ending 1 renews in January; the receipt was paid in July 2025, so the
        // next January is 2026 — which is what the document states.
        var expiry = RegistrationRenewal.DeriveExpiry("130301", new DateTime(2025, 7, 11, 0, 0, 0, DateTimeKind.Utc));

        Assert.NotNull(expiry);
        Assert.Equal(2026, expiry!.Value.Year);
        Assert.Equal(1, expiry.Value.Month);
    }

    [Theory]
    [InlineData("130301", 1)]
    [InlineData("ABC1239", 9)]
    [InlineData("130300", 10)]
    public void MapsTheLastDigitToARenewalMonth(string plate, int expected)
    {
        // Zero means October, not month zero — the scheme uses ten months.
        Assert.Equal(expected, RegistrationRenewal.RenewalMonthFromPlate(plate));
    }

    [Fact]
    public void RollsForwardWhenPaidInTheRenewalMonth()
    {
        // Paying in your own renewal month buys the following year, not the one just
        // ending.
        var expiry = RegistrationRenewal.DeriveExpiry("130301", new DateTime(2025, 1, 20, 0, 0, 0, DateTimeKind.Utc));

        Assert.Equal(2026, expiry!.Value.Year);
    }

    [Fact]
    public void GivesNothingWithoutBothInputs()
    {
        Assert.Null(RegistrationRenewal.DeriveExpiry("130301", null));
        Assert.Null(RegistrationRenewal.DeriveExpiry("ABCDEF", new DateTime(2025, 7, 11, 0, 0, 0, DateTimeKind.Utc)));
        Assert.Null(RegistrationRenewal.RenewalMonthFromPlate(null));
    }
}
