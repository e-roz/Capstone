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
    public record GateTapOutcome(bool Opened, string Direction, string Message);

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

        public async Task<GateTapOutcome> HandleAsync(Guid deviceId, string rawTag, CancellationToken ct)
        {
            var device = await _db.Set<GateDevice>().AsNoTracking()
                .FirstOrDefaultAsync(d => d.Id == deviceId, ct);

            if (device is null || device.IsRevoked)
                return new GateTapOutcome(false, "-",
                    "This reader has been revoked. Link the port to another reader in Gate Readers.");

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
                    loggedByUserId: null, loggedByDeviceId: device.Id, ct);

                return Describe(exit, "OUT");
            }

            var entry = await _parking.LogEntryAsync(
                new LogParkingEntryDto { RfidTagId = tag, Gate = device.Gate },
                loggedByUserId: null, loggedByDeviceId: device.Id, ct);

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
