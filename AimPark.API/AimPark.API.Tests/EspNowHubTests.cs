using System.Collections.Concurrent;
using AimPark.API.Enums;
using AimPark.API.Sync.Site.GateReaders;

namespace AimPark.API.Tests;

public class HubProtocolTests
{
    [Theory]
    [InlineData("G1 UID:04A1B2C3", "G1", "04A1B2C3")]
    [InlineData("  G2 UID:DEADBEEF \r", "G2", "DEADBEEF")]
    public void ReadsATap(string line, string node, string uid)
    {
        var tap = Assert.IsType<HubTap>(HubProtocol.Parse(line));
        Assert.Equal(node, tap.Node);
        Assert.Equal(uid, tap.Uid);
    }

    [Theory]
    [InlineData("S1/3 SLOT:OCCUPIED 3.7", "S1/3", true, 4)]
    [InlineData("S2/9 SLOT:FREE 0.0", "S2/9", false, 0)]
    [InlineData("S1/1 SLOT:OCCUPIED 2.4", "S1/1", true, 2)]
    [InlineData("S1/1 SLOT:FREE", "S1/1", false, 0)]
    public void ReadsASlot(string line, string node, bool occupied, int distance)
    {
        var slot = Assert.IsType<HubSlot>(HubProtocol.Parse(line));
        Assert.Equal(node, slot.Node);
        Assert.Equal(occupied, slot.Occupied);
        Assert.Equal(distance, slot.DistanceCm);
    }

    [Theory]
    [InlineData("S1/3 SLOT:FAULT 0.0", "S1/3")]
    [InlineData("S2/9 SLOT:FAULT", "S2/9")]
    public void ReadsASensorThatHearsNothing(string line, string node)
    {
        var fault = Assert.IsType<HubSlotFault>(HubProtocol.Parse(line));
        Assert.Equal(node, fault.Node);
    }

    [Fact]
    public void AFaultFromABoardIsNotASlot()
    {
        Assert.IsType<HubUnknown>(HubProtocol.Parse("S1 SLOT:FAULT 0.0"));
    }

    [Fact]
    public void ReadsPresenceAndErrors()
    {
        Assert.Equal(new HubPresence("G1", true), HubProtocol.Parse("G1 ONLINE"));
        Assert.Equal(new HubPresence("S2", false), HubProtocol.Parse("S2 OFFLINE"));
        Assert.Equal(new HubNodeError("G2", "NOT_DELIVERED"), HubProtocol.Parse("G2 ERR:NOT_DELIVERED"));
    }

    [Theory]
    [InlineData("# AimPark ESP-NOW hub")]
    [InlineData("# ERR:UNKNOWN_COMMAND G9 CMD:OPEN")]
    public void CommentsAreComments(string line) => Assert.IsType<HubComment>(HubProtocol.Parse(line));

    [Theory]
    [InlineData("UID:04A1B2C3")]          // A USB gate reader's line, not the hub's.
    [InlineData("G1 UID:")]
    [InlineData("S1/2 SLOT:MAYBE 4")]
    [InlineData("S1 SLOT:OCCUPIED 7")]    // A board isn't a slot: the old one-sensor format.
    [InlineData("hello there")]
    public void AnythingElseIsUnknown(string line) => Assert.IsType<HubUnknown>(HubProtocol.Parse(line));

    [Theory]
    [InlineData("G1", HubNodeKind.Gate)]
    [InlineData("S1", HubNodeKind.SensorBoard)]
    [InlineData("S2/7", HubNodeKind.Sensor)]
    [InlineData("G1/2", null)]
    [InlineData("X1", null)]
    public void TellsBoardsFromSensors(string node, HubNodeKind? kind) => Assert.Equal(kind, HubProtocol.KindOf(node));

    [Fact]
    public void FindsTheBoardASensorIsOn()
    {
        Assert.Equal("S2", HubProtocol.BoardOf("S2/7"));
        Assert.Equal("G1", HubProtocol.BoardOf("G1"));
    }

    [Fact]
    public void RecognisesTheBannerAndReady()
    {
        Assert.True(HubProtocol.IsBanner("# AimPark ESP-NOW hub"));
        Assert.True(HubProtocol.IsReady("# Ready on channel 1. Waiting for nodes."));
        Assert.False(HubProtocol.IsBanner("# Ready on channel 1. Waiting for nodes."));
    }

    [Fact]
    public void WritesTheServersLines()
    {
        Assert.Equal("G1 RESULT:OPEN", HubProtocol.Result("G1", true));
        Assert.Equal("G2 RESULT:SHUT", HubProtocol.Result("G2", false));
        Assert.Equal("G2 CMD:OPEN", HubProtocol.Open("G2"));
    }
}

/// <summary>
/// Plays the hub's side of the conversation: feeds it lines and keeps what the
/// server wrote back, on a clock the test moves by hand.
/// </summary>
internal sealed class FakeHub
{
    public DateTime Now = new(2026, 10, 1, 8, 0, 0, DateTimeKind.Utc);
    public readonly ConcurrentQueue<string> Sent = new();
    public readonly ConcurrentQueue<(string Node, bool Occupied, int Distance)> Slots = new();
    public readonly ConcurrentQueue<string> Lost = new();
    public Func<string, string, Task<bool>> Answer = (_, _) => Task.FromResult(true);

    public HubConversation Server { get; }

    public FakeHub()
    {
        Server = new HubConversation(
            send: line => { Sent.Enqueue(line); return true; },
            answerTap: (node, uid, _) => Answer(node, uid),
            slotSeen: (node, occupied, cm, _) => { Slots.Enqueue((node, occupied, cm)); return Task.CompletedTask; },
            now: () => Now,
            slotLost: (node, _) => { Lost.Enqueue(node); return Task.CompletedTask; });
    }

    /// <summary>Opens the port and boots, the way the hub does on Windows.</summary>
    public async Task BootAsync()
    {
        Server.Connected();
        await Server.Receive("# AimPark ESP-NOW hub");
        await Server.Receive("# Ready on channel 1. Waiting for nodes.");
    }

    public Task Say(string line) => Server.Receive(line);

    public void Wait(TimeSpan time)
    {
        Now += time;
        Server.Tick();
    }

    public HubNodeView Node(string name) => Server.Nodes().Single(n => n.Node == name);
}

public class HubConversationTests
{
    [Fact]
    public async Task AsksForStatusOnceReadyAndThenEveryTenSeconds()
    {
        var hub = new FakeHub();
        hub.Server.Connected();
        hub.Server.Tick();
        Assert.Empty(hub.Sent);   // Still booting: a command now would be lost.

        await hub.Say("# AimPark ESP-NOW hub");
        await hub.Say("# Ready on channel 1. Waiting for nodes.");
        Assert.Equal(["STATUS"], hub.Sent);

        hub.Wait(TimeSpan.FromSeconds(5));
        Assert.Single(hub.Sent);
        hub.Wait(TimeSpan.FromSeconds(5));
        Assert.Equal(2, hub.Sent.Count);
    }

    [Fact]
    public void AHubThatDidNotRebootIsAskedAnyway()
    {
        // Not every board resets when its port opens.
        var hub = new FakeHub();
        hub.Server.Connected();
        hub.Wait(HubConversation.ReadyWithin);
        Assert.Equal(["STATUS"], hub.Sent);
    }

    [Fact]
    public async Task AnswersATapAtTheGateItCameFrom()
    {
        var hub = new FakeHub();
        await hub.BootAsync();
        hub.Answer = (node, uid) => Task.FromResult(node == "G1" && uid == "04A1B2C3");

        await hub.Say("G1 UID:04A1B2C3");
        await hub.Say("G2 UID:FFFFFFFF");

        Assert.Contains("G1 RESULT:OPEN", hub.Sent);
        Assert.Contains("G2 RESULT:SHUT", hub.Sent);
        Assert.NotNull(hub.Node("G1").LastTapAt);
        Assert.True(hub.Node("G1").Online);
    }

    [Fact]
    public async Task ASlowGateDoesNotHoldUpTheOther()
    {
        var hub = new FakeHub();
        await hub.BootAsync();

        var g1Release = new TaskCompletionSource<bool>();
        hub.Answer = (node, _) => node == "G1" ? g1Release.Task : Task.FromResult(true);

        var g1 = hub.Say("G1 UID:AAAA0001");
        var g2 = hub.Say("G2 UID:BBBB0002");

        await g2.WaitAsync(TimeSpan.FromSeconds(5));
        Assert.Contains("G2 RESULT:OPEN", hub.Sent);
        Assert.DoesNotContain(hub.Sent, l => l.StartsWith("G1 "));

        g1Release.SetResult(true);
        await g1.WaitAsync(TimeSpan.FromSeconds(5));
        Assert.Contains("G1 RESULT:OPEN", hub.Sent);
    }

    [Fact]
    public async Task TapsAtOneGateAreAnsweredInOrder()
    {
        var hub = new FakeHub();
        await hub.BootAsync();

        var first = new TaskCompletionSource<bool>();
        hub.Answer = (_, uid) => uid == "00000001" ? first.Task : Task.FromResult(false);

        var a = hub.Say("G1 UID:00000001");
        var b = hub.Say("G1 UID:00000002");
        await Task.Delay(100);
        Assert.DoesNotContain(hub.Sent, l => l.StartsWith("G1 "));

        first.SetResult(true);
        await Task.WhenAll(a, b).WaitAsync(TimeSpan.FromSeconds(5));
        Assert.Equal(["G1 RESULT:OPEN", "G1 RESULT:SHUT"], hub.Sent.Where(l => l.StartsWith("G1 ")));
    }

    [Fact]
    public async Task AFailedLookupKeepsTheBarrierShut()
    {
        var hub = new FakeHub();
        await hub.BootAsync();
        hub.Answer = (_, _) => throw new InvalidOperationException("database down");

        await hub.Say("G1 UID:04A1B2C3");
        Assert.Contains("G1 RESULT:SHUT", hub.Sent);
    }

    [Fact]
    public async Task PassesSlotReadingsOnAndRemembersThem()
    {
        var hub = new FakeHub();
        await hub.BootAsync();

        await hub.Say("S1/3 SLOT:OCCUPIED 7.2");
        await hub.Say("S2/1 SLOT:FREE 0.0");

        Assert.Equal([("S1/3", true, 7), ("S2/1", false, 0)], hub.Slots);
        Assert.Equal(true, hub.Node("S1/3").Occupied);
        Assert.Equal(7, hub.Node("S1/3").DistanceCm);
        Assert.Equal(false, hub.Node("S2/1").Occupied);

        // A reading is its board checking in.
        Assert.True(hub.Node("S1").Online);
        Assert.Null(hub.Node("S1").Occupied);
    }

    [Fact]
    public async Task ABoardGoingOfflineTakesItsSensorsWithIt()
    {
        var hub = new FakeHub();
        await hub.BootAsync();
        await hub.Say("S1/1 SLOT:OCCUPIED 3.0");
        await hub.Say("S1/2 SLOT:FREE 0.0");
        await hub.Say("S2/1 SLOT:FREE 0.0");
        hub.Wait(HubConversation.SettleFor);

        await hub.Say("S1 OFFLINE");

        Assert.False(hub.Node("S1").Online);
        Assert.False(hub.Node("S1/1").Online);
        Assert.False(hub.Node("S1/2").Online);
        Assert.True(hub.Node("S2/1").Online);              // Another board: untouched.
        Assert.Equal(true, hub.Node("S1/1").Occupied);     // Last known, kept for the screen.
        Assert.Equal(3, hub.Slots.Count);                  // No reading to apply to any slot…
        Assert.Equal(["S1/1", "S1/2"], hub.Lost.Order());  // …but its bays can't be vouched for.
    }

    [Fact]
    public async Task AnOfflineWhileSettlingLosesNoSlots()
    {
        var hub = new FakeHub();
        await hub.BootAsync();
        await hub.Say("S1/1 SLOT:FREE 0.0");

        await hub.Say("S1 OFFLINE");   // Just rebooted: not heard yet, not gone.

        Assert.Empty(hub.Lost);
    }

    [Fact]
    public async Task ASensorThatHearsNothingIsDownOnItsOwn()
    {
        var hub = new FakeHub();
        await hub.BootAsync();
        await hub.Say("S1/2 SLOT:FREE 9.0");
        await hub.Say("S1/3 SLOT:OCCUPIED 3.0");

        await hub.Say("S1/3 SLOT:FAULT 0.0");

        Assert.Equal(["S1/3"], hub.Lost);
        Assert.True(hub.Node("S1/3").Fault);
        Assert.Null(hub.Node("S1/3").Occupied);   // A guess would be wrong half the time.
        Assert.True(hub.Node("S1").Online);       // Its board said so itself.
        Assert.False(hub.Node("S1/2").Fault);     // Its neighbours are fine.
    }

    [Fact]
    public async Task ASensorAnsweringAgainReadsAsUsual()
    {
        var hub = new FakeHub();
        await hub.BootAsync();
        await hub.Say("S1/3 SLOT:FAULT 0.0");

        await hub.Say("S1/3 SLOT:OCCUPIED 3.0");

        Assert.False(hub.Node("S1/3").Fault);
        Assert.Equal(true, hub.Node("S1/3").Occupied);
        Assert.Equal([("S1/3", true, 3)], hub.Slots);
    }

    [Fact]
    public async Task ListsEachBoardBeforeItsSensorsInOrder()
    {
        var hub = new FakeHub();
        await hub.BootAsync();
        await hub.Say("S2/1 SLOT:FREE 0.0");
        await hub.Say("S1/10 SLOT:FREE 0.0");
        await hub.Say("S1/2 SLOT:FREE 0.0");

        Assert.Equal(["G1", "G2", "S1", "S1/2", "S1/10", "S2", "S2/1"],
            hub.Server.Nodes().Select(n => n.Node));
    }

    [Fact]
    public async Task OfflineRightAfterABootMeansNotHeardYet()
    {
        var hub = new FakeHub();
        await hub.BootAsync();
        await hub.Say("G1 ONLINE");

        // The port reopened and rebooted the hub. Its first STATUS reports
        // everyone offline only because no heartbeat has arrived yet.
        await hub.BootAsync();
        await hub.Say("G1 OFFLINE");
        Assert.True(hub.Node("G1").Online);
        Assert.Null(hub.Node("G1").WentOfflineAt);

        // Past the settle time, OFFLINE is the hub's real verdict.
        hub.Wait(HubConversation.SettleFor);
        await hub.Say("G1 OFFLINE");
        Assert.False(hub.Node("G1").Online);
        Assert.Equal(hub.Now, hub.Node("G1").WentOfflineAt);
    }

    [Fact]
    public async Task ASensorGoingOfflineLeavesItsSlotAlone()
    {
        var hub = new FakeHub();
        await hub.BootAsync();
        await hub.Say("S1/4 SLOT:OCCUPIED 9.0");
        hub.Wait(HubConversation.SettleFor);

        await hub.Say("S1 OFFLINE");

        Assert.Single(hub.Slots);           // Nothing new to apply to the slot.
        Assert.False(hub.Node("S1/4").Online);
        Assert.Equal(true, hub.Node("S1/4").Occupied);   // Last known, kept for the screen.
    }

    [Fact]
    public async Task RemembersAnUndeliveredCommand()
    {
        var hub = new FakeHub();
        await hub.BootAsync();

        Assert.True(hub.Server.Open("G2"));
        Assert.Contains("G2 CMD:OPEN", hub.Sent);

        await hub.Say("G2 ERR:NOT_DELIVERED");
        Assert.Equal("NOT_DELIVERED", hub.Node("G2").LastError);
        Assert.Equal(hub.Now, hub.Node("G2").LastErrorAt);
    }

    [Fact]
    public async Task IgnoresCommentsButNotesTheHubsOwnFailures()
    {
        var hub = new FakeHub();
        await hub.BootAsync();

        await hub.Say("# ERR:UNKNOWN_COMMAND G9 CMD:OPEN");
        Assert.Null(hub.Server.HubError);

        await hub.Say("# This board (aa:bb) is not the hub. It is G1.");
        Assert.Contains("not the hub", hub.Server.HubError);
        Assert.Empty(hub.Slots);
    }

    [Fact]
    public async Task ListsTheExpectedBoardsAndAnyNewOnes()
    {
        var hub = new FakeHub();
        Assert.Equal(["G1", "G2", "S1", "S2"], hub.Server.Nodes().Select(n => n.Node));

        await hub.BootAsync();
        await hub.Say("S3 ONLINE");
        Assert.Contains(hub.Server.Nodes(), n => n is { Node: "S3", Kind: HubNodeKind.SensorBoard, Online: true });
    }

    [Fact]
    public async Task GoesQuietWhenTheHubStopsAnswering()
    {
        var hub = new FakeHub();
        await hub.BootAsync();
        Assert.False(hub.Server.IsQuiet());

        hub.Wait(HubConversation.QuietAfter + TimeSpan.FromSeconds(1));
        Assert.True(hub.Server.IsQuiet());

        await hub.Say("G1 ONLINE");
        Assert.False(hub.Server.IsQuiet());
    }
}

public class SlotSensorRuleTests
{
    [Fact]
    public void ACarMakesTheSlotOccupied()
    {
        Assert.Equal(ParkingSlotStatus.Occupied,
            SlotSensorRule.Next(ParkingSlotStatus.Available, occupied: true));
        Assert.Null(SlotSensorRule.Next(ParkingSlotStatus.Occupied, occupied: true));
    }

    [Fact]
    public void AnEmptySlotIsFree()
    {
        Assert.Equal(ParkingSlotStatus.Available,
            SlotSensorRule.Next(ParkingSlotStatus.Occupied, occupied: false));
        Assert.Null(SlotSensorRule.Next(ParkingSlotStatus.Available, occupied: false));
    }

    [Fact]
    public void ABayGivenAtTheGateShowsFreeWhileNoCarIsInIt()
    {
        // The claim at the gate marked it Occupied; the car is still driving
        // there, or parked elsewhere. The sensor shows what is really there;
        // the open session keeps the car counted (ParkingCapacity).
        Assert.Equal(ParkingSlotStatus.Available,
            SlotSensorRule.Next(ParkingSlotStatus.Occupied, occupied: false));
    }

    [Theory]
    [InlineData(true)]
    [InlineData(false)]
    public void OutOfServiceIsNeverOverridden(bool occupied)
    {
        Assert.Null(SlotSensorRule.Next(ParkingSlotStatus.OutOfService, occupied));
    }

    [Theory]
    [InlineData(ParkingSlotStatus.Available)]
    [InlineData(ParkingSlotStatus.Occupied)]
    public void ASensorThatStopsReadingTakesItsBayOutOfTheCount(ParkingSlotStatus current)
    {
        Assert.Equal(ParkingSlotStatus.NoSignal, SlotSensorRule.Lost(current));
    }

    [Fact]
    public void LosingTheSignalLeavesOutOfServiceAlone()
    {
        Assert.Null(SlotSensorRule.Lost(ParkingSlotStatus.OutOfService));
        Assert.Null(SlotSensorRule.Lost(ParkingSlotStatus.NoSignal));
    }

    [Theory]
    [InlineData(true, ParkingSlotStatus.Occupied)]
    [InlineData(false, ParkingSlotStatus.Available)]
    public void AReadingBringsANoSignalBayBack(bool occupied, ParkingSlotStatus expected)
    {
        Assert.Equal(expected, SlotSensorRule.Next(ParkingSlotStatus.NoSignal, occupied));
    }
}
