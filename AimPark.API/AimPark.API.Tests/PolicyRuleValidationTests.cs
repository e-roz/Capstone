using AimPark.API.DTOs;
using AimPark.API.Enums;
using AimPark.API.Services;

namespace AimPark.API.Tests;

/// <summary>
/// Every policy rule must do something to the RFID card, a suspension is
/// counted in hours, and a rule that revokes the card carries no fine.
/// </summary>
public class PolicyRuleValidationTests
{
    private static UpsertPolicyRuleDto Rule(
        string type = "Temporary", int? hours = 24, decimal fine = 20m, string category = "Parking") => new()
    {
        Title = "Illegal parking",
        Category = category,
        DefaultSuspensionType = type,
        DefaultSuspensionHours = hours,
        DefaultPenaltyAmount = fine
    };

    private static string? Check(UpsertPolicyRuleDto dto) =>
        ViolationService.ValidateRuleDto(dto, out _, out _)?.Value?.ToString();

    [Fact]
    public void ARuleThatSuspendsTheCardForHoursIsAccepted()
    {
        Assert.Null(Check(Rule(hours: 3)));
    }

    [Fact]
    public void AnActiveRuleWithNoActionOnTheCardIsRefused()
    {
        Assert.NotNull(Check(Rule(type: "None")));
    }

    [Fact]
    public void AnInactiveRuleWithNoActionCanStillBeSaved()
    {
        var dto = Rule(type: "None");
        dto.IsActive = false;
        Assert.Null(Check(dto));
    }

    [Theory]
    [InlineData(null)]
    [InlineData(0)]
    [InlineData(-5)]
    public void ASuspensionNeedsAtLeastOneHour(int? hours)
    {
        Assert.NotNull(Check(Rule(hours: hours)));
    }

    [Fact]
    public void ARevokingRuleWithAFineIsRefused()
    {
        Assert.NotNull(Check(Rule(type: "Permanent", hours: null, fine: 50m)));
    }

    [Fact]
    public void ARevokingRuleWithNoFineIsAccepted()
    {
        Assert.Null(Check(Rule(type: "Permanent", hours: null, fine: 0m)));
    }

    [Theory]
    [InlineData("Parking", PolicyCategory.Parking)]
    [InlineData("Conduct", PolicyCategory.Conduct)]
    public void OnlyParkingAndConductAreCategories(string text, PolicyCategory expected)
    {
        Assert.Null(ViolationService.ValidateRuleDto(Rule(category: text), out _, out var category));
        Assert.Equal(expected, category);
    }

    [Theory]
    [InlineData("Access")]
    [InlineData("Documentation")]
    [InlineData("Other")]
    public void TheOldCategoriesAreNoLongerAccepted(string text)
    {
        Assert.NotNull(Check(Rule(category: text)));
    }

    [Theory]
    [InlineData(1, "1 hour")]
    [InlineData(6, "6 hours")]
    [InlineData(24, "1 day")]
    [InlineData(36, "1 day 12 hours")]
    [InlineData(48, "2 days")]
    [InlineData(720, "30 days")]
    public void HoursReadAsDaysWhereTheyFit(int hours, string expected)
    {
        Assert.Equal(expected, ViolationService.FormatHours(hours));
    }
}
