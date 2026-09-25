using System.Net.Http.Json;
using System.Text.Json;
using AimPark.API.Data;
using AimPark.API.Entities;
using Microsoft.EntityFrameworkCore;

namespace AimPark.API.Sync.Site
{
    /// <summary>
    /// Sends the outbox to the cloud: straight away when a car moves, and
    /// again every few seconds for anything that could not go the first time.
    /// </summary>
    /// <remarks>
    /// Rows leave the outbox only after the cloud has answered OK. If the
    /// internet is down they simply wait — the gate has already made its
    /// decision and does not need the cloud to agree.
    /// </remarks>
    public class SiteOutboxPusher : BackgroundService
    {
        public const string CloudClient = "AimParkCloud";

        private const int BatchSize = 200;
        private static readonly TimeSpan RetryEvery = TimeSpan.FromSeconds(15);

        private readonly IServiceScopeFactory _scopes;
        private readonly IHttpClientFactory _http;
        private readonly OutboxSignal _signal;
        private readonly SiteSyncStatus _status;
        private readonly ILogger<SiteOutboxPusher> _logger;

        public SiteOutboxPusher(
            IServiceScopeFactory scopes,
            IHttpClientFactory http,
            OutboxSignal signal,
            SiteSyncStatus status,
            ILogger<SiteOutboxPusher> logger)
        {
            _scopes = scopes;
            _http = http;
            _signal = signal;
            _status = status;
            _logger = logger;
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            while (!stoppingToken.IsCancellationRequested)
            {
                try
                {
                    // Keep going while full batches come back — a backlog from
                    // a day offline should drain in one go, not one batch per wait.
                    while (await PushOnceAsync(stoppingToken)) { }

                    _status.LastPushError = null;
                }
                catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
                {
                    return;
                }
                catch (Exception ex)
                {
                    _status.LastPushError = ex.Message;
                    _logger.LogWarning("Could not send gate records to the cloud yet: {Error}", ex.Message);
                }

                try
                {
                    await _signal.WaitAsync(RetryEvery, stoppingToken);
                }
                catch (OperationCanceledException)
                {
                    return;
                }
            }
        }

        /// <returns>True when a full batch went, so there may be more.</returns>
        private async Task<bool> PushOnceAsync(CancellationToken ct)
        {
            using var scope = _scopes.CreateScope();
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();

            var rows = await db.Set<SyncOutboxEntry>().AsNoTracking()
                .OrderBy(o => o.Id)
                .Take(BatchSize)
                .ToListAsync(ct);

            if (rows.Count == 0)
                return false;

            var batch = await BuildBatchAsync(db, rows, ct);

            if (!batch.IsEmpty)
            {
                var client = _http.CreateClient(CloudClient);
                using var response = await client.PostAsJsonAsync("api/site-sync/events", batch, ct);

                if (!response.IsSuccessStatusCode)
                    throw new HttpRequestException(
                        $"Cloud answered {(int)response.StatusCode} to the outbox.");
            }

            // By id, not "everything up to the last one": ids are handed out
            // when a save starts, not when it commits, so a slower save can
            // land a lower id after this batch was read.
            var sentIds = rows.Select(r => r.Id).ToList();
            await db.Set<SyncOutboxEntry>().Where(o => sentIds.Contains(o.Id)).ExecuteDeleteAsync(ct);

            _status.LastPushAt = DateTime.UtcNow;
            return rows.Count == BatchSize;
        }

        private static async Task<SiteEventBatch> BuildBatchAsync(
            AppDbContext db, List<SyncOutboxEntry> rows, CancellationToken ct)
        {
            List<Guid> Ids(string kind) => rows
                .Where(r => r.Kind == kind && r.EntityId is not null)
                .Select(r => r.EntityId!.Value)
                .Distinct()
                .ToList();

            var slotIds = Ids(SyncKinds.ParkingSlot);
            var deviceIds = Ids(SyncKinds.GateDevice);
            var passIds = Ids(SyncKinds.VisitorPass);
            var incidentIds = Ids(SyncKinds.Incident);
            var evidenceIds = Ids(SyncKinds.IncidentEvidence);
            var readingIds = Ids(SyncKinds.AlprReading);
            var logIds = Ids(SyncKinds.ParkingLog);
            var attemptIds = Ids(SyncKinds.GateAccessAttempt);
            var paymentIds = Ids(SyncKinds.PaymentTransaction);
            var notificationIds = Ids(SyncKinds.Notification);

            return new SiteEventBatch
            {
                // Read as they are now, not as they were when queued — see
                // SyncOutboxEntry. A row deleted since simply isn't found.
                VisitorPasses = await db.Set<VisitorPass>().AsNoTracking()
                    .Where(p => passIds.Contains(p.Id)).ToListAsync(ct),

                Incidents = await db.Set<Incident>().AsNoTracking()
                    .Where(i => incidentIds.Contains(i.Id)).ToListAsync(ct),

                IncidentEvidence = await db.Set<IncidentEvidence>().AsNoTracking()
                    .Where(e => evidenceIds.Contains(e.Id)).ToListAsync(ct),

                AlprReadings = await db.Set<AlprReading>().AsNoTracking()
                    .Where(r => readingIds.Contains(r.Id)).ToListAsync(ct),

                ParkingLogs = await db.Set<ParkingLog>().AsNoTracking()
                    .Where(l => logIds.Contains(l.Id)).ToListAsync(ct),

                SlotStatuses = await db.Set<ParkingSlot>().AsNoTracking()
                    .Where(s => slotIds.Contains(s.Id))
                    .Select(s => new SlotStatusUpdate { Id = s.Id, Status = s.Status, UpdatedAt = s.UpdatedAt })
                    .ToListAsync(ct),

                GateAccessAttempts = await db.Set<GateAccessAttempt>().AsNoTracking()
                    .Where(a => attemptIds.Contains(a.Id)).ToListAsync(ct),

                PaymentTransactions = await db.Set<PaymentTransaction>().AsNoTracking()
                    .Where(p => paymentIds.Contains(p.Id)).ToListAsync(ct),

                Notifications = await db.Set<Notification>().AsNoTracking()
                    .Where(n => notificationIds.Contains(n.Id)).ToListAsync(ct),

                DevicesSeen = await db.Set<GateDevice>().AsNoTracking()
                    .Where(d => deviceIds.Contains(d.Id) && d.LastSeenAt != null)
                    .Select(d => new DeviceSeenUpdate { Id = d.Id, LastSeenAt = d.LastSeenAt!.Value })
                    .ToListAsync(ct),

                Pushes = rows
                    .Where(r => r.Kind == SyncKinds.Push && r.Payload is not null)
                    .Select(r => JsonSerializer.Deserialize<PushRequest>(r.Payload!))
                    .OfType<PushRequest>()
                    .ToList()
            };
        }
    }
}
