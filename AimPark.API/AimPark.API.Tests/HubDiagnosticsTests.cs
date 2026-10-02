using AimPark.API.Sync.Site.GateReaders;

namespace AimPark.API.Tests;

public class HubDiagnosticsProtocolTests
{
    [Fact]
    public void ReadsABoardsAnswer()
    {
        var line = Assert.IsType<HubDiag>(HubProtocol.Parse(
            "DIAG G1 rtt=14 rssi=-52 noderssi=-50 up=3600 heap=180 reset=POWERON fails=0 packets=812 drops=1 rc522=92"));

        Assert.Equal("G1", line.Node);
        Assert.Equal("14", line.Values["rtt"]);
        Assert.Equal("-52", line.Values["rssi"]);
        Assert.Equal("POWERON", line.Values["reset"]);
        Assert.Equal("92", line.Values["rc522"]);
    }

    [Fact]
    public void ReadsTheHubsOwnAnswer()
    {
        var line = Assert.IsType<HubDiag>(HubProtocol.Parse(
            "DIAG HUB id=20500DCF8718 proto=3 up=120 heap=200 reset=POWERON channel=1 nodes=4 fails=0"));
        Assert.Equal(HubProtocol.HubName, line.Node);
        Assert.Equal("4", line.Values["nodes"]);
    }

    [Fact]
    public void ReadsAFailedTest() =>
        Assert.Equal(new HubDiagFailed("S2", "NO_REPLY"), HubProtocol.Parse("DIAG S2 FAIL NO_REPLY"));

    [Fact]
    public void WritesTheTestCommands()
    {
        Assert.Equal("DIAG", HubProtocol.Diag());
        Assert.Equal("DIAG G2", HubProtocol.Diag("G2"));
    }

    [Fact]
    public void AHealthyBoardHasNothingToSay() =>
        Assert.Null(HubConversation.Concern("G1", Values("rssi=-55 reset=POWERON rc522=92")));

    [Theory]
    [InlineData("rssi=-88", "Weak signal (-88 dBm)")]
    [InlineData("reset=BROWNOUT", "power dip")]
    [InlineData("rc522=00", "RC522")]
    [InlineData("rc522=FF", "RC522")]
    [InlineData("sensors=9 noecho=0044", "S1/3, S1/7")]
    public void NamesWhatNeedsALook(string values, string expected) =>
        Assert.Contains(expected, HubConversation.Concern(values.Contains("noecho") ? "S1" : "G1", Values(values)));

    private static Dictionary<string, string> Values(string text) =>
        text.Split(' ').Select(p => p.Split('=')).ToDictionary(p => p[0], p => p[1]);
}

public class HubDiagnosticsConversationTests
{
    [Fact]
    public async Task TestingABoardPingsItThroughTheHub()
    {
        var hub = new FakeHub();
        await hub.BootAsync();

        var testing = hub.Server.DiagnoseAsync("G1");
        Assert.Contains("DIAG G1", hub.Sent);

        await hub.Say("DIAG G1 rtt=12 rssi=-60 noderssi=-58 up=50 heap=180 reset=POWERON fails=0 packets=20 drops=0 rc522=92");
        var result = await testing;

        Assert.True(result.Ok);
        Assert.Null(result.Problem);
        Assert.Equal("-60", result.Values["rssi"]);
        Assert.Same(result, hub.Server.Diagnoses()["G1"]);
    }

    [Fact]
    public async Task ABoardThatDoesntAnswerFailsWithAReason()
    {
        var hub = new FakeHub();
        await hub.BootAsync();

        var testing = hub.Server.DiagnoseAsync("S2");
        await hub.Say("DIAG S2 FAIL NOT_DELIVERED");
        var result = await testing;

        Assert.False(result.Ok);
        Assert.Contains("didn't hear the hub", result.Problem);
    }

    [Fact]
    public async Task AnOlderHubStillPassesTheCableTest()
    {
        var hub = new FakeHub();
        await hub.BootAsync();

        var testing = hub.Server.DiagnoseAsync(null);
        Assert.Contains("DIAG", hub.Sent);
        await hub.Say("# ERR:UNKNOWN_COMMAND DIAG");
        var result = await testing;

        Assert.True(result.Ok);
        Assert.Contains("older", result.Problem);
    }

    [Fact]
    public async Task AnOlderHubFailsABoardTest()
    {
        var hub = new FakeHub();
        await hub.BootAsync();

        var testing = hub.Server.DiagnoseAsync("G1");
        await hub.Say("# ERR:UNKNOWN_COMMAND DIAG G1");
        var result = await testing;

        Assert.False(result.Ok);
        Assert.Contains("Reflash the hub", result.Problem);
    }

    [Fact]
    public async Task TheConsoleKeepsBothDirections()
    {
        var hub = new FakeHub();
        await hub.BootAsync();
        await hub.Say("G1 ONLINE");

        var traffic = hub.Server.Traffic();
        Assert.Contains(traffic, t => t is { Out: true, Line: "STATUS" });
        Assert.Contains(traffic, t => t is { Out: false, Line: "G1 ONLINE" });

        var last = traffic[^1].Seq;
        await hub.Say("G2 ONLINE");
        Assert.Equal(["G2 ONLINE"], hub.Server.Traffic(last).Select(t => t.Line));
    }

    [Fact]
    public async Task TheConsoleKeepsOnlyTheLatestLines()
    {
        var hub = new FakeHub();
        await hub.BootAsync();
        for (var i = 0; i < HubConversation.KeptTrafficLines + 20; i++)
            await hub.Say("G1 ONLINE");

        Assert.Equal(HubConversation.KeptTrafficLines, hub.Server.Traffic().Count);
    }
}
