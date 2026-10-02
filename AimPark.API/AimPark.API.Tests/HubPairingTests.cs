using AimPark.API.Sync.Site.GateReaders;

namespace AimPark.API.Tests;

public class HubPairingProtocolTests
{
    [Fact]
    public void ReadsAJoinRequest()
    {
        Assert.Equal(new HubPairRequest("582ABDD0A36C", HubNodeKind.Gate),
            HubProtocol.Parse("PAIRREQ 582ABDD0A36C GATE"));
        Assert.Equal(new HubPairRequest("4CC382ED1DA4", HubNodeKind.SensorBoard),
            HubProtocol.Parse("PAIRREQ 4CC382ED1DA4 SENSOR"));
    }

    [Fact]
    public void ReadsTheHubsAnswers()
    {
        Assert.Equal(new HubPaired("G1", "582ABDD0A36C", HubNodeKind.Gate),
            HubProtocol.Parse("PAIRED G1 582ABDD0A36C GATE"));
        Assert.Equal(new HubForgot("S2"), HubProtocol.Parse("FORGOT S2"));
        Assert.Equal(new HubCommandError("582ABDD0A36C", "didn't answer. Try again."),
            HubProtocol.Parse("ERR 582ABDD0A36C didn't answer. Try again."));
        Assert.Equal(new HubHello("20500DCF8718", 3), HubProtocol.Parse("HUB 20500DCF8718 3"));
    }

    [Theory]
    [InlineData("PAIRREQ 582ABDD0A36C HUB")]   // Only gates and sensor boards join.
    [InlineData("PAIRREQ NOTANID GATE")]
    [InlineData("PAIRED S1 582ABDD0A36C GATE")] // A gate can't be called S1.
    [InlineData("PAIRED G0 582ABDD0A36C GATE")]
    public void RefusesMalformedPairingLines(string line) =>
        Assert.IsNotType<HubPaired>(HubProtocol.Parse(line));

    [Theory]
    [InlineData("G1", HubNodeKind.Gate, true)]
    [InlineData("G9", HubNodeKind.Gate, true)]
    [InlineData("S2", HubNodeKind.SensorBoard, true)]
    [InlineData("S1", HubNodeKind.Gate, false)]
    [InlineData("G10", HubNodeKind.Gate, false)]
    [InlineData("S2/3", HubNodeKind.SensorBoard, false)]
    public void KnowsWhatABoardMayBeCalled(string node, HubNodeKind kind, bool fits) =>
        Assert.Equal(fits, HubProtocol.FitsName(node, kind));

    [Theory]
    [InlineData("G1", 1)]
    [InlineData("G2", 2)]
    [InlineData("S1", null)]
    [InlineData("S1/3", null)]
    public void AGateNodeIsTheGateInItsName(string node, int? gate) => Assert.Equal(gate, HubProtocol.GateOf(node));

    [Fact]
    public void WritesThePairingCommands()
    {
        Assert.Equal("PAIR 582ABDD0A36C G1", HubProtocol.Pair("582ABDD0A36C", "G1"));
        Assert.Equal("FORGET S2", HubProtocol.Forget("S2"));
    }
}

public class HubPairingConversationTests
{
    [Fact]
    public async Task ListsABoardAskingToJoinUntilItStopsAsking()
    {
        var hub = new FakeHub();
        await hub.BootAsync();

        await hub.Say("PAIRREQ 582ABDD0A36C GATE");
        Assert.Equal([("582ABDD0A36C", HubNodeKind.Gate)], hub.Server.Requests());

        hub.Wait(HubConversation.RequestShownFor + TimeSpan.FromSeconds(1));
        Assert.Empty(hub.Server.Requests());
    }

    [Fact]
    public async Task AcceptingABoardNamesIt()
    {
        var hub = new FakeHub();
        await hub.BootAsync();
        await hub.Say("PAIRREQ 582ABDD0A36C GATE");

        var accepting = hub.Server.PairAsync("582ABDD0A36C", "G1");
        Assert.Contains("PAIR 582ABDD0A36C G1", hub.Sent);

        await hub.Say("PAIRED G1 582ABDD0A36C GATE");
        Assert.Null(await accepting);
        Assert.Equal("582ABDD0A36C", hub.Server.IdOf("G1"));
        Assert.Empty(hub.Server.Requests());
    }

    [Fact]
    public async Task PassesOnWhyTheHubRefused()
    {
        var hub = new FakeHub();
        await hub.BootAsync();
        await hub.Say("PAIRREQ 582ABDD0A36C GATE");

        var accepting = hub.Server.PairAsync("582ABDD0A36C", "G1");
        await hub.Say("ERR 582ABDD0A36C didn't answer. Keep it powered near the hub and try again.");

        Assert.Equal("didn't answer. Keep it powered near the hub and try again.", await accepting);
    }

    [Fact]
    public async Task WontNameAGateLikeASensorBoard()
    {
        var hub = new FakeHub();
        await hub.BootAsync();
        await hub.Say("PAIRREQ 582ABDD0A36C GATE");

        Assert.NotNull(await hub.Server.PairAsync("582ABDD0A36C", "S1"));
        Assert.DoesNotContain(hub.Sent, line => line.StartsWith("PAIR "));
    }

    [Fact]
    public async Task WontAcceptABoardThatIsNotAsking()
    {
        var hub = new FakeHub();
        await hub.BootAsync();

        Assert.NotNull(await hub.Server.PairAsync("582ABDD0A36C", "G1"));
    }

    [Fact]
    public async Task AReplacementTakesTheName()
    {
        var hub = new FakeHub();
        await hub.BootAsync();
        await hub.Say("PAIRED G1 582ABDD0A36C GATE");

        await hub.Say("FORGOT G1");
        await hub.Say("PAIRED G1 20500DCFCD00 GATE");

        Assert.Equal("20500DCFCD00", hub.Server.IdOf("G1"));
    }

    [Fact]
    public async Task ForgettingASensorBoardTakesItsSensorsWithIt()
    {
        var hub = new FakeHub();
        await hub.BootAsync();
        await hub.Say("PAIRED S2 4CC382ED1DA4 SENSOR");
        await hub.Say("S2/3 SLOT:OCCUPIED 3.7");
        Assert.Contains(hub.Server.Nodes(), n => n.Node == "S2/3");

        var forgetting = hub.Server.ForgetAsync("S2");
        await hub.Say("FORGOT S2");

        Assert.Null(await forgetting);
        Assert.DoesNotContain(hub.Server.Nodes(), n => n.Node == "S2/3");
        Assert.Null(hub.Server.IdOf("S2"));
        // S2 is one of the boards the lot is built with: it stays listed, offline.
        Assert.False(hub.Node("S2").Online);
    }
}
