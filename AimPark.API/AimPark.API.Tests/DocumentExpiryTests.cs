using AimPark.API.Helpers;

namespace AimPark.API.Tests;

public class DocumentExpiryTests
{
    private static readonly DateOnly Today = new(2026, 10, 15);

    [Fact]
    public void ADocumentIsGoodThroughTheDayItExpires()
    {
        // Expiring on the 15th still works on the 15th. Refusing at 00:01 on the
        // day would turn a driver away with a day left on their licence.
        Assert.False(DocumentExpiry.IsExpired(new DateTime(2026, 10, 15), Today));
    }

    [Fact]
    public void ADocumentIsExpiredTheDayAfter()
    {
        Assert.True(DocumentExpiry.IsExpired(new DateTime(2026, 10, 14), Today));
    }

    [Fact]
    public void ALaterExpiryIsNotExpired()
    {
        Assert.False(DocumentExpiry.IsExpired(new DateTime(2027, 1, 30), Today));
    }

    [Fact]
    public void NoDateIsNotExpired()
    {
        // A document nobody could read a date from is a question for an admin;
        // the barrier does not turn someone away over a blank.
        Assert.False(DocumentExpiry.IsExpired(null, Today));
    }

    [Fact]
    public void TheTimeOfDayDoesNotMatter()
    {
        Assert.False(DocumentExpiry.IsExpired(new DateTime(2026, 10, 15, 23, 59, 0), Today));
        Assert.True(DocumentExpiry.IsExpired(new DateTime(2026, 10, 14, 23, 59, 0), Today));
    }
}
