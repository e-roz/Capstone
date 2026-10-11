using System.Text.Json;
using AimPark.API.Data;
using AimPark.API.Entities;
using AimPark.API.Enums;
using AimPark.API.Interfaces;

namespace AimPark.API.Sync.Site
{
    /// <summary>
    /// The site server's stand-in for Firebase. A push is put in the outbox
    /// and the cloud sends it when it gets there — the site may have no
    /// internet, and a barrier must never wait on a phone notification.
    /// </summary>
    public class OutboxPushSender : IPushSender
    {
        private readonly AppDbContext _db;
        private readonly OutboxSignal _signal;
        private readonly ILogger<OutboxPushSender> _logger;

        public OutboxPushSender(AppDbContext db, OutboxSignal signal, ILogger<OutboxPushSender> logger)
        {
            _db = db;
            _signal = signal;
            _logger = logger;
        }

        public Task SendToRoleAsync(UserRole? targetRole, string title, string body, IDictionary<string, string>? data, CancellationToken ct)
            => QueueAsync(new PushRequest { TargetRole = targetRole, Title = title, Body = body, Data = Copy(data) }, ct);

        public Task SendToUserAsync(Guid userId, string title, string body, IDictionary<string, string>? data, CancellationToken ct)
            => QueueAsync(new PushRequest { TargetUserId = userId, Title = title, Body = body, Data = Copy(data) }, ct);

        private async Task QueueAsync(PushRequest push, CancellationToken ct)
        {
            // Same promise as FcmPushSender: never throws.
            try
            {
                _db.Set<SyncOutboxEntry>().Add(new SyncOutboxEntry
                {
                    Kind = SyncKinds.Push,
                    Payload = JsonSerializer.Serialize(push),
                    EnqueuedAt = DateTime.UtcNow
                });

                await _db.SaveChangesAsync(ct);
                _signal.Poke();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Could not queue a push for the cloud.");
            }
        }

        private static Dictionary<string, string>? Copy(IDictionary<string, string>? data)
            => data is null ? null : new Dictionary<string, string>(data);
    }
}
