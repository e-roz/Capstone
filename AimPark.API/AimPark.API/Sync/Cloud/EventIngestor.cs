using System.Collections.Concurrent;
using AimPark.API.Data;
using AimPark.API.Entities;
using AimPark.API.Enums;
using AimPark.API.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace AimPark.API.Sync.Cloud
{
    /// <summary>
    /// Stores what the site server did — entries, exits, plate reads, fees —
    /// so the mobile app, admin panel and reports see it.
    /// </summary>
    /// <remarks>
    /// Every row is matched on its id, so a batch that arrives twice (the site
    /// never heard the first "OK") changes nothing the second time.
    ///
    /// The whole batch is tried in one save first. If that fails, each row is
    /// tried on its own and the ones that still fail are logged and skipped:
    /// one bad row must not wedge the site's outbox forever with everything
    /// behind it waiting.
    /// </remarks>
    public class EventIngestor
    {
        /// <summary>
        /// A push older than this is left in the app's notification list but
        /// not sent to the phone. "The lot is full" an hour late is noise.
        /// </summary>
        private static readonly TimeSpan PushFreshness = TimeSpan.FromMinutes(30);

        private readonly AppDbContext _db;
        private readonly SyncSuppression _suppression;
        private readonly IPushSender _push;
        private readonly SentPushLedger _sentPushes;
        private readonly ILogger<EventIngestor> _logger;

        public EventIngestor(
            AppDbContext db,
            SyncSuppression suppression,
            IPushSender push,
            SentPushLedger sentPushes,
            ILogger<EventIngestor> logger)
        {
            _db = db;
            _suppression = suppression;
            _push = push;
            _sentPushes = sentPushes;
            _logger = logger;
        }

        public async Task<int> IngestAsync(SiteEventBatch batch, CancellationToken ct)
        {
            // Writes that came from the site are not news to the site.
            _suppression.Active = true;

            // Parents before children, so a foreign key always finds its row.
            var steps = new List<(string What, Func<CancellationToken, Task> Stage)>();
            steps.AddRange(batch.VisitorPasses.Select(p => ($"visitor pass {p.Id}", (Func<CancellationToken, Task>)(c => StageVisitorPassAsync(p, c)))));
            steps.AddRange(batch.Incidents.Select(i => ($"incident {i.Id}", (Func<CancellationToken, Task>)(c => StageIncidentAsync(i, c)))));
            steps.AddRange(batch.IncidentEvidence.Select(e => ($"incident attachment {e.Id}", (Func<CancellationToken, Task>)(c => InsertOnceAsync(e, e.Id, c)))));
            steps.AddRange(batch.AlprReadings.Select(r => ($"plate read {r.Id}", (Func<CancellationToken, Task>)(c => UpsertAsync(r, r.Id, c)))));
            steps.AddRange(batch.ParkingLogs.Select(l => ($"parking log {l.Id}", (Func<CancellationToken, Task>)(c => UpsertAsync(l, l.Id, c)))));
            steps.AddRange(batch.SlotStatuses.Select(s => ($"slot {s.Id}", (Func<CancellationToken, Task>)(c => StageSlotStatusAsync(s, c)))));
            steps.AddRange(batch.GateAccessAttempts.Select(a => ($"gate attempt {a.Id}", (Func<CancellationToken, Task>)(c => UpsertAsync(a, a.Id, c)))));
            steps.AddRange(batch.PaymentTransactions.Select(p => ($"payment {p.Id}", (Func<CancellationToken, Task>)(c => InsertOnceAsync(p, p.Id, c)))));
            steps.AddRange(batch.Notifications.Select(n => ($"notification {n.Id}", (Func<CancellationToken, Task>)(c => InsertOnceAsync(n, n.Id, c)))));
            steps.AddRange(batch.DevicesSeen.Select(d => ($"device {d.Id}", (Func<CancellationToken, Task>)(c => StageDeviceSeenAsync(d, c)))));

            var failed = 0;

            try
            {
                foreach (var step in steps)
                    await step.Stage(ct);

                await _db.SaveChangesAsync(ct);
            }
            catch (DbUpdateException ex)
            {
                _logger.LogWarning(ex, "Site batch failed as a whole; storing its rows one at a time.");
                _db.ChangeTracker.Clear();

                foreach (var step in steps)
                {
                    try
                    {
                        await step.Stage(ct);
                        await _db.SaveChangesAsync(ct);
                    }
                    catch (DbUpdateException rowEx)
                    {
                        failed++;
                        _logger.LogError(rowEx, "Skipped {What} from the site server.", step.What);
                        _db.ChangeTracker.Clear();
                    }
                }
            }

            // After the rows are stored, so a phone opening the notification
            // finds the payment it points at.
            foreach (var push in batch.Pushes)
                await ReplayPushAsync(push, ct);

            return failed;
        }

        private async Task UpsertAsync<T>(T incoming, Guid id, CancellationToken ct) where T : class
        {
            var existing = await _db.Set<T>().FindAsync([id], ct);
            if (existing is null)
                _db.Set<T>().Add(incoming);
            else
                _db.Entry(existing).CurrentValues.SetValues(incoming);
        }

        /// <summary>
        /// For records the cloud owns once they exist: a payment is settled
        /// here, and a notification is marked read here. The site's copy is
        /// only ever the first version.
        /// </summary>
        private async Task InsertOnceAsync<T>(T incoming, Guid id, CancellationToken ct) where T : class
        {
            if (await _db.Set<T>().FindAsync([id], ct) is null)
                _db.Set<T>().Add(incoming);
        }

        /// <summary>
        /// Passes are issued and returned on both sides, so the newer edit wins.
        /// </summary>
        private async Task StageVisitorPassAsync(VisitorPass incoming, CancellationToken ct)
        {
            var existing = await _db.Set<VisitorPass>().FindAsync([incoming.Id], ct);
            if (existing is null)
                _db.Set<VisitorPass>().Add(incoming);
            else if (incoming.UpdatedAt >= existing.UpdatedAt)
                _db.Entry(existing).CurrentValues.SetValues(incoming);
        }

        /// <summary>
        /// A guard can edit or withdraw their report at the guard post while an
        /// admin reviews it here; the two never touch a report at the same
        /// stage, so the newer edit wins.
        /// </summary>
        private async Task StageIncidentAsync(Incident incoming, CancellationToken ct)
        {
            var existing = await _db.Set<Incident>().FindAsync([incoming.Id], ct);
            if (existing is null)
                _db.Set<Incident>().Add(incoming);
            else if (incoming.UpdatedAt >= existing.UpdatedAt)
                _db.Entry(existing).CurrentValues.SetValues(incoming);
        }

        /// <summary>
        /// The site owns whether a bay has a car in it. The cloud owns whether
        /// the bay is in service at all — an admin's "out of service" is never
        /// overwritten by the site, only by the admin.
        /// </summary>
        private async Task StageSlotStatusAsync(SlotStatusUpdate incoming, CancellationToken ct)
        {
            var slot = await _db.Set<ParkingSlot>().FindAsync([incoming.Id], ct);
            if (slot is null || slot.Status == ParkingSlotStatus.OutOfService)
                return;

            if (incoming.UpdatedAt < slot.UpdatedAt)
                return;

            slot.Status = incoming.Status;
            slot.UpdatedAt = incoming.UpdatedAt;
        }

        private async Task StageDeviceSeenAsync(DeviceSeenUpdate incoming, CancellationToken ct)
        {
            var device = await _db.Set<GateDevice>().FindAsync([incoming.Id], ct);
            if (device is not null && (device.LastSeenAt is null || incoming.LastSeenAt > device.LastSeenAt))
                device.LastSeenAt = incoming.LastSeenAt;
        }

        private async Task ReplayPushAsync(PushRequest push, CancellationToken ct)
        {
            if (DateTime.UtcNow - push.CreatedAt > PushFreshness)
                return;

            // A batch the site sends again must not buzz the phone again.
            if (!_sentPushes.TryClaim(push.Id))
                return;

            if (push.TargetUserId is Guid userId)
                await _push.SendToUserAsync(userId, push.Title, push.Body, push.Data, ct);
            else
                await _push.SendToRoleAsync(push.TargetRole, push.Title, push.Body, push.Data, ct);
        }
    }

    /// <summary>
    /// Push ids already sent, remembered for a day. Kept in memory because a
    /// resend comes within seconds or minutes of the first attempt; a restart
    /// in between could send one twice, which is a duplicate buzz, not a
    /// wrong record.
    /// </summary>
    public class SentPushLedger
    {
        private static readonly TimeSpan Keep = TimeSpan.FromDays(1);
        private readonly ConcurrentDictionary<Guid, DateTime> _sent = new();

        public bool TryClaim(Guid pushId)
        {
            var now = DateTime.UtcNow;

            if (_sent.Count > 5000)
            {
                foreach (var (id, at) in _sent)
                    if (now - at > Keep)
                        _sent.TryRemove(id, out _);
            }

            return _sent.TryAdd(pushId, now);
        }
    }
}
