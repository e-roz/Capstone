using System.Text.Json;
using AimPark.API.Data;
using AimPark.API.DTOs;
using AimPark.API.Entities;
using AimPark.API.Enums;
using AimPark.API.Helpers;
using AimPark.API.Interfaces;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace AimPark.API.Sync.Site.GateReaders
{
    /// <summary>What a tap at a USB gate reader came to.</summary>
    /// <param name="AwaitingVisitorCard">
    /// Set when the card was an idle visitor card: its label. The barrier stays
    /// shut and the guard is asked for the visitor's details — see
    /// <see cref="PendingVisitorRegistrations"/>.
    /// </param>
    public record GateTapOutcome(bool Opened, string Direction, string Message, string? AwaitingVisitorCard = null);

    /// <summary>
    /// Turns one card tap at a USB reader into an entry or an exit.
    /// </summary>
    /// <remarks>
    /// Both gates are entry and exit at once, so the reader never says which it
    /// is. The card does: a car that is inside is leaving, and one that is not
    /// is arriving. Everything past that choice is the same entry and exit the
    /// network readers use — suspension, plate match, slot, fee — logged
    /// against the reader's own <see cref="GateDevice"/> so the plate check
    /// looks at the camera on the same gate.
    /// </remarks>
    public class GateTapHandler
    {
        /// <summary>
        /// A tap this soon after entering is a second tap, not a car leaving.
        /// Without it a driver who taps twice at the barrier is let in and
        /// straight back out, and billed for it.
        /// </summary>
        public static readonly TimeSpan MinimumStay = TimeSpan.FromSeconds(20);

        private readonly AppDbContext _db;
        private readonly IParkingHistoryService _parking;

        public GateTapHandler(AppDbContext db, IParkingHistoryService parking)
        {
            _db = db;
            _parking = parking;
        }

        /// <summary>A tap at a reader registered in Gate Devices.</summary>
        public async Task<GateTapOutcome> HandleAsync(Guid deviceId, string rawTag, CancellationToken ct)
        {
            var device = await _db.Set<GateDevice>().AsNoTracking()
                .FirstOrDefaultAsync(d => d.Id == deviceId, ct);

            if (device is null || device.IsRevoked)
                return new GateTapOutcome(false, "-",
                    "This reader has been revoked. Link the port to another reader in Gate Readers.");

            return await HandleAsync(device.Gate, device.Id, rawTag, ct);
        }

        /// <summary>
        /// A tap at a gate known only by its number: a paired wireless gate
        /// board, which needs no Gate Devices entry. <paramref name="deviceId"/>
        /// stands for it in ParkingLog.LoggedByDeviceId, so the tap takes the
        /// device path (plate check included) and the log shows which board.
        /// </summary>
        public async Task<GateTapOutcome> HandleAsync(int gate, Guid deviceId, string rawTag, CancellationToken ct)
        {
            var tag = RfidTag.Normalize(rawTag);

            var enteredAt = await _db.Set<ParkingLog>().AsNoTracking()
                .Where(l => l.ExitTime == null
                         && ((l.User != null && l.User.RfidTagId == tag)
                          || (l.VisitorPass != null && l.VisitorPass.RfidTagId == tag)))
                .Select(l => (DateTime?)l.EntryTime)
                .FirstOrDefaultAsync(ct);

            if (enteredAt is DateTime entered)
            {
                var waited = DateTime.UtcNow - entered;
                if (waited < MinimumStay)
                {
                    var left = (int)Math.Ceiling((MinimumStay - waited).TotalSeconds);
                    return new GateTapOutcome(false, "OUT",
                        $"Just entered. Tap again in {left}s to leave.");
                }

                var exit = await _parking.LogExitAsync(
                    new LogParkingExitDto { RfidTagId = tag },
                    loggedByUserId: null, loggedByDeviceId: deviceId, ct);

                return Describe(exit, "OUT");
            }

            // A visitor card nobody is holding yet: the guard has to say who is
            // in the car before it opens anything. A card already lent at the
            // desk falls through to the ordinary visitor entry.
            var card = await _db.Set<VisitorCard>().AsNoTracking()
                .FirstOrDefaultAsync(c => c.RfidTagId == tag, ct);

            if (card is not null)
            {
                if (card.State == VisitorCardState.Blocked)
                    return new GateTapOutcome(false, "IN",
                        $"Visitor card {card.Label} is blocked. Keep it and lend a different card.");

                var now = DateTime.UtcNow;
                var lent = await _db.Set<VisitorPass>().AsNoTracking()
                    .AnyAsync(p => p.RfidTagId == tag
                                && p.Status == VisitorPassStatus.Active
                                && p.ExpiresAt > now, ct);

                if (!lent)
                    return new GateTapOutcome(false, "IN",
                        $"Visitor card {card.Label}. Waiting for the guard to enter the visitor's details.",
                        AwaitingVisitorCard: card.Label);
            }

            var entry = await _parking.LogEntryAsync(
                new LogParkingEntryDto { RfidTagId = tag, Gate = gate },
                loggedByUserId: null, loggedByDeviceId: deviceId, ct);

            return Describe(entry, "IN");
        }

        /// <summary>
        /// Reads the barrier's answer off the same response the HTTP endpoints
        /// return, so a USB tap and a network tap can never disagree.
        /// </summary>
        private static GateTapOutcome Describe(ActionResult<object> result, string direction)
        {
            var (status, body) = result.Result is ObjectResult obj
                ? (obj.StatusCode ?? 200, obj.Value)
                : (200, result.Value);

            var json = body is null ? default : JsonSerializer.SerializeToElement(body);
            string? Text(string name) =>
                json.ValueKind == JsonValueKind.Object && json.TryGetProperty(name, out var v)
                    && v.ValueKind is not JsonValueKind.Null
                    ? v.ToString()
                    : null;

            var message = Text("message") ?? (status < 300 ? "Done." : "Refused.");

            if (Text("slotCode") is { } slot)
                message += $" Slot {slot}.";

            if (decimal.TryParse(Text("amountDue"), out var due) && due > 0)
                message += $" ₱{due:0.##} due.";

            return new GateTapOutcome(status is >= 200 and < 300, direction, message);
        }
    }
}
