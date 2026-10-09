using AimPark.API.Sync.Site.GateReaders;

namespace AimPark.API.Tests;

/// <summary>
/// Telling the linked hub from whatever else is on its COM port.
/// </summary>
public class HubIdentityTests
{
    private const string HubA = "20500DCF8718";
    private const string HubB = "582ABDD0A36C";

    [Fact]
    public async Task AsksPingOnlyOnceTheBoardHadTimeToBoot()
    {
        var hub = new FakeHub();
        await hub.BootAsync();

        Assert.False(hub.Server.PingDue());

        hub.Wait(HubConversation.ReadyWithin);
        Assert.True(hub.Server.PingDue());
        Assert.False(hub.Server.PingDue());   // Paced, not every pass of the loop.

        hub.Wait(HubConversation.PingEvery);
        Assert.True(hub.Server.PingDue());
    }

    [Fact]
    public async Task LearnsTheHubsIdFromItsAnswer()
    {
        var hub = new FakeHub();
        await hub.BootAsync();

        await hub.Say($"HUB {HubA} 3");

        Assert.Equal(HubA, hub.Server.HubId);
        Assert.Null(hub.Server.IdentityProblem);
        Assert.False(hub.Server.PingDue());
    }

    [Fact]
    public async Task AcceptsTheHubItWasLinkedTo()
    {
        var hub = new FakeHub();
        hub.Server.ExpectedHubId = HubA;
        await hub.BootAsync();

        await hub.Say($"HUB {HubA.ToLowerInvariant()} 3");

        Assert.Null(hub.Server.IdentityProblem);
    }

    [Fact]
    public async Task RejectsADifferentHubOnTheSamePort()
    {
        var hub = new FakeHub();
        hub.Server.ExpectedHubId = HubA;
        await hub.BootAsync();

        await hub.Say($"HUB {HubB} 3");

        var problem = hub.Server.IdentityProblem;
        Assert.NotNull(problem);
        Assert.Contains(HubA, problem);
        Assert.Contains(HubB, problem);
    }

    [Fact]
    public async Task ADeviceThatNeverAnswersPingIsNotTheHub()
    {
        var hub = new FakeHub();
        await hub.BootAsync();

        hub.Wait(HubConversation.IdentifyWithin - TimeSpan.FromSeconds(1));
        hub.Server.CheckIdentity();
        Assert.Null(hub.Server.IdentityProblem);   // Still within the time it is given.

        hub.Wait(TimeSpan.FromSeconds(2));
        hub.Server.CheckIdentity();
        Assert.NotNull(hub.Server.IdentityProblem);
        Assert.Contains("not the ESP-NOW hub", hub.Server.IdentityProblem);
    }

    [Fact]
    public async Task ANoisyDeviceStillIsNotTheHub()
    {
        // The case from the field: some other board on COM3 printing boot noise.
        var hub = new FakeHub();
        await hub.BootAsync();

        for (var i = 0; i < 8; i++)
        {
            hub.Wait(TimeSpan.FromSeconds(3));
            await hub.Say("ets Jun  8 2016 00:22:57");
        }
        hub.Server.CheckIdentity();

        Assert.NotNull(hub.Server.IdentityProblem);
    }

    [Fact]
    public async Task AHubThatWasJustSlowToAnswerClearsTheProblem()
    {
        var hub = new FakeHub();
        hub.Server.ExpectedHubId = HubA;
        await hub.BootAsync();

        hub.Wait(HubConversation.IdentifyWithin + TimeSpan.FromSeconds(1));
        hub.Server.CheckIdentity();
        Assert.NotNull(hub.Server.IdentityProblem);

        await hub.Say($"HUB {HubA} 3");

        Assert.Null(hub.Server.IdentityProblem);
    }

    [Fact]
    public async Task ReconnectingForgetsWhoWasThereBefore()
    {
        var hub = new FakeHub();
        hub.Server.ExpectedHubId = HubA;
        await hub.BootAsync();
        await hub.Say($"HUB {HubB} 3");
        Assert.NotNull(hub.Server.IdentityProblem);

        hub.Server.Connected();

        Assert.Null(hub.Server.HubId);
        Assert.Null(hub.Server.IdentityProblem);
    }
}
