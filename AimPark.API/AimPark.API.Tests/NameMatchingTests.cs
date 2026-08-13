using AimPark.API.Helpers;

namespace AimPark.API.Tests;

/// <summary>
/// The school form against the driver's licence — the comparison most likely to
/// reject a real applicant if it is too strict.
/// </summary>
public class NameMatchingTests
{
    [Fact]
    public void MatchesAcrossTheTwoDocumentsConventions()
    {
        // The licence puts the surname first, the school form does not. Same person.
        Assert.True(NameMatching.IsProbableMatch("REYES, JEAN ZYRIL", "Jean Zyril Reyes"));
    }

    [Fact]
    public void AllowsOneDocumentToOmitTheMiddleName()
    {
        Assert.True(NameMatching.IsProbableMatch("Jean Reyes", "REYES, JEAN ZYRIL"));
    }

    [Fact]
    public void TreatsASingleLetterAsAnInitial()
    {
        Assert.True(NameMatching.IsProbableMatch("JEAN Z REYES", "Jean Zyril Reyes"));
    }

    [Fact]
    public void IgnoresGenerationalSuffixes()
    {
        // Printed on one document and not the other often enough to matter.
        Assert.True(NameMatching.IsProbableMatch("JOSE REYES JR.", "Jose Reyes"));
    }

    [Fact]
    public void IgnoresAccents()
    {
        Assert.True(NameMatching.IsProbableMatch("JUAN PEÑA", "Juan Pena"));
    }

    [Fact]
    public void ToleratesASingleOcrSlipInALongWord()
    {
        Assert.True(NameMatching.IsProbableMatch("JEAN RODRIGUEZ", "Jean Rodriquez"));
    }

    [Fact]
    public void RejectsADifferentPerson()
    {
        Assert.False(NameMatching.IsProbableMatch("MARIA SANTOS", "REYES, JEAN ZYRIL"));
    }

    [Fact]
    public void RefusesToDecideOnASingleWord()
    {
        // One word in common is not evidence that two people are the same.
        Assert.False(NameMatching.IsProbableMatch("REYES", "REYES, JEAN ZYRIL"));
    }

    [Theory]
    [InlineData(null, "Jean Reyes")]
    [InlineData("Jean Reyes", null)]
    [InlineData("", "Jean Reyes")]
    [InlineData("   ", "Jean Reyes")]
    public void RefusesToDecideWithoutTwoNames(string? a, string? b)
    {
        // Must be false, not true — an unreadable name goes to a reviewer rather
        // than passing by default.
        Assert.False(NameMatching.IsProbableMatch(a, b));
    }
}
