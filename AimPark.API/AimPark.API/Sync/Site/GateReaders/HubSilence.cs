namespace AimPark.API.Sync.Site.GateReaders
{
    /// <summary>
    /// When a linked ESP-NOW hub has said nothing for long enough that the bays
    /// its sensors watch can no longer be trusted.
    /// </summary>
    /// <remarks>
    /// A sensor board that goes offline is reported by the hub, and its bays
    /// become No signal (<see cref="SlotSensorRule.Lost"/>). But when the hub
    /// itself is unplugged or switched off with the rest of the model, nobody
    /// is left to report anything: the bays kept their last reading, and the
    /// app went on showing a lot full of free bays that nothing was watching.
    ///
    /// The hub answers STATUS every 10 s, so a working one is never quiet for
    /// long. The window is longer than <see cref="HubConversation.QuietAfter"/>
    /// plus a reboot, so a hub that hangs and is restarted by reopening its
    /// port does not blank the lot for a few seconds.
    /// </remarks>
    public static class HubSilence
    {
        public static readonly TimeSpan After = TimeSpan.FromSeconds(45);

        /// <param name="simulated">Fed by hand from the Gate Readers screen: never silent.</param>
        /// <param name="lastHeardAt">The last line the hub sent, if any.</param>
        /// <param name="watchingSince">When this PC started watching, so a fresh start waits a full window.</param>
        public static bool IsSilent(bool simulated, DateTime? lastHeardAt, DateTime watchingSince, DateTime now)
        {
            if (simulated) return false;
            var since = lastHeardAt is DateTime heard && heard > watchingSince ? heard : watchingSince;
            return now - since > After;
        }
    }
}
