using AimPark.API.Data;
using AimPark.API.Entities;
using AimPark.API.Helpers;
using AimPark.API.Services;
using AimPark.API.Sync.Site.Cameras;
using Microsoft.EntityFrameworkCore;

namespace AimPark.API.Sync.Site.GateReaders
{
    /// <summary>
    /// Writes each tap to the guard's live log: who the card belongs to, what
    /// the camera read, the plates on file, and a photo of the moment.
    /// </summary>
    /// <remarks>
    /// Runs after the barrier has its answer, and looks everything up again
    /// rather than threading it out of <see cref="GateTapHandler"/>. That keeps
    /// the gate decision untouched, and a refused tap — which never gets as far
    /// as a parking log — is described just as fully as an accepted one.
    /// </remarks>
    public class GateTapRecorder
    {
        private readonly AppDbContext _db;
        private readonly CameraFrames _cameras;

        public GateTapRecorder(AppDbContext db, CameraFrames cameras)
        {
            _db = db;
            _cameras = cameras;
        }

        public async Task RecordTapAsync(
            Guid deviceId, string rawTag, DateTime tappedAt, GateTapOutcome outcome, CancellationToken ct)
        {
            var device = await _db.Set<GateDevice>().AsNoTracking()
                .Where(d => d.Id == deviceId)
                .Select(d => new { d.Name, d.Gate })
                .FirstOrDefaultAsync(ct);

            await RecordTapAsync(device?.Gate ?? 0, device?.Name, rawTag, tappedAt, outcome, ct);
        }

        /// <summary>A tap at a gate known by its number, e.g. a paired wireless gate board.</summary>
        public async Task RecordTapAsync(
            int gate, string? readerName, string rawTag, DateTime tappedAt, GateTapOutcome outcome, CancellationToken ct)
        {
            var tag = RfidTag.Normalize(rawTag);

            var tap = new GateTapEvent
            {
                At = tappedAt,
                Gate = gate,
                ReaderName = readerName,
                Direction = outcome.Direction,
                Opened = outcome.Opened,
                Message = Trim(outcome.Message, 500),
                RfidTagId = tag
            };

            var user = await _db.Set<User>().AsNoTracking()
                .Where(u => u.RfidTagId == tag)
                .Select(u => new { u.Id, u.FullName })
                .FirstOrDefaultAsync(ct);

            List<string> plates = [];

            if (user is not null)
            {
                tap.PersonKind = GateTapPersonKind.Driver;
                tap.PersonName = user.FullName;
                tap.UserId = user.Id;
                plates = await _db.Set<Vehicle>().AsNoTracking()
                    .Where(v => v.UserId == user.Id)
                    .Select(v => v.PlateNumber)
                    .ToListAsync(ct);
            }
            else
            {
                var pass = await _db.Set<VisitorPass>().AsNoTracking()
                    .Where(p => p.RfidTagId == tag)
                    .OrderByDescending(p => p.IssuedAt)
                    .Select(p => new { p.Id, p.VisitorName, p.PlateNumber })
                    .FirstOrDefaultAsync(ct);

                if (pass is not null)
                {
                    tap.PersonKind = GateTapPersonKind.Visitor;
                    tap.PersonName = pass.VisitorName;
                    tap.VisitorPassId = pass.Id;
                    plates = [pass.PlateNumber];
                }
            }

            // Consumed or not: an accepted tap consumed it, a plate mismatch
            // consumed it too, and the guard wants to see it either way.
            var windowStart = tappedAt - ParkingHistoryService.AlprMatchWindow;
            tap.CameraPlate = await _db.Set<AlprReading>().AsNoTracking()
                .Where(r => r.Gate == gate && r.ReadAt >= windowStart && r.ReadAt <= tappedAt.AddSeconds(2))
                .OrderByDescending(r => r.ReadAt)
                .Select(r => r.PlateNumber)
                .FirstOrDefaultAsync(ct);

            plates = plates.Where(p => !string.IsNullOrWhiteSpace(p)).Distinct().ToList();
            if (plates.Count > 0)
                tap.RegisteredPlates = Trim(string.Join(", ", plates), 200);

            if (tap.CameraPlate is not null && plates.Count > 0)
                tap.PlateMatches = plates.Any(p =>
                    string.Equals(IdentifierNormalizer.NormalizePlate(p), tap.CameraPlate,
                        StringComparison.OrdinalIgnoreCase));

            if (outcome.Opened && (tap.UserId is not null || tap.VisitorPassId is not null))
                tap.ParkingLogId = await _db.Set<ParkingLog>().AsNoTracking()
                    .Where(l => (tap.UserId != null && l.UserId == tap.UserId)
                             || (tap.VisitorPassId != null && l.VisitorPassId == tap.VisitorPassId))
                    .OrderByDescending(l => l.EntryTime)
                    .Select(l => (Guid?)l.Id)
                    .FirstOrDefaultAsync(ct);

            tap.HasPhoto = _cameras.SavePhoto(gate, tap.Id, tap.At);

            _db.Set<GateTapEvent>().Add(tap);
            await _db.SaveChangesAsync(ct);
        }

        public async Task RecordManualOpenAsync(Guid deviceId, string openedBy, CancellationToken ct)
        {
            var device = await _db.Set<GateDevice>().AsNoTracking()
                .Where(d => d.Id == deviceId)
                .Select(d => new { d.Name, d.Gate })
                .FirstOrDefaultAsync(ct);

            await RecordManualOpenAsync(device?.Gate ?? 0, device?.Name, openedBy, ct);
        }

        public async Task RecordManualOpenAsync(int gate, string? readerName, string openedBy, CancellationToken ct)
        {
            var tap = new GateTapEvent
            {
                Gate = gate,
                ReaderName = readerName,
                Direction = "-",
                Opened = true,
                Message = Trim($"Opened by hand by {openedBy}.", 500),
                PersonKind = GateTapPersonKind.Manual
            };
            tap.HasPhoto = _cameras.SavePhoto(tap.Gate, tap.Id, tap.At);

            _db.Set<GateTapEvent>().Add(tap);
            await _db.SaveChangesAsync(ct);
        }

        private static string Trim(string value, int max) => value.Length <= max ? value : value[..max];
    }
}
