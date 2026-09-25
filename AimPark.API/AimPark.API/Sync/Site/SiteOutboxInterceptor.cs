using AimPark.API.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;

namespace AimPark.API.Sync.Site
{
    /// <summary>
    /// On the site server, notes every gate record a save touches in the
    /// outbox — in the same save, so a record and its outbox row are stored
    /// together or not at all.
    /// </summary>
    /// <remarks>
    /// On the save itself rather than in the gate services, so the entry and
    /// exit code stays exactly as it was, and a new gate feature cannot forget
    /// to report what it did.
    /// </remarks>
    public class SiteOutboxInterceptor : SaveChangesInterceptor
    {
        private readonly SyncSuppression _suppression;
        private readonly OutboxSignal _signal;
        private bool _queued;

        public SiteOutboxInterceptor(SyncSuppression suppression, OutboxSignal signal)
        {
            _suppression = suppression;
            _signal = signal;
        }

        public override InterceptionResult<int> SavingChanges(
            DbContextEventData eventData, InterceptionResult<int> result)
        {
            Enqueue(eventData.Context);
            return result;
        }

        public override ValueTask<InterceptionResult<int>> SavingChangesAsync(
            DbContextEventData eventData, InterceptionResult<int> result, CancellationToken cancellationToken = default)
        {
            Enqueue(eventData.Context);
            return ValueTask.FromResult(result);
        }

        public override int SavedChanges(SaveChangesCompletedEventData eventData, int result)
        {
            Wake();
            return result;
        }

        public override ValueTask<int> SavedChangesAsync(
            SaveChangesCompletedEventData eventData, int result, CancellationToken cancellationToken = default)
        {
            Wake();
            return ValueTask.FromResult(result);
        }

        private void Enqueue(DbContext? context)
        {
            // A snapshot being applied is the cloud's data arriving, not news for it.
            if (context is null || _suppression.Active)
                return;

            context.ChangeTracker.DetectChanges();

            var seen = new HashSet<(string, Guid)>();
            var rows = new List<SyncOutboxEntry>();

            void Add(string kind, Guid id)
            {
                if (seen.Add((kind, id)))
                    rows.Add(new SyncOutboxEntry { Kind = kind, EntityId = id, EnqueuedAt = DateTime.UtcNow });
            }

            foreach (var entry in context.ChangeTracker.Entries().ToList())
            {
                if (entry.State is not (EntityState.Added or EntityState.Modified))
                    continue;

                switch (entry.Entity)
                {
                    case AlprReading r:
                        Add(SyncKinds.AlprReading, r.Id);
                        break;

                    case ParkingLog l:
                        Add(SyncKinds.ParkingLog, l.Id);
                        // The allocator claims a bay with a bulk update the
                        // change tracker never sees. The log names the bay,
                        // so reporting it from here covers that path too.
                        if (l.SlotId is Guid slotId)
                            Add(SyncKinds.ParkingSlot, slotId);
                        break;

                    case ParkingSlot s when entry.State == EntityState.Modified:
                        Add(SyncKinds.ParkingSlot, s.Id);
                        break;

                    case GateAccessAttempt a:
                        Add(SyncKinds.GateAccessAttempt, a.Id);
                        break;

                    case PaymentTransaction p:
                        Add(SyncKinds.PaymentTransaction, p.Id);
                        break;

                    case Notification n:
                        Add(SyncKinds.Notification, n.Id);
                        break;

                    case VisitorPass v:
                        Add(SyncKinds.VisitorPass, v.Id);
                        break;

                    case Incident i:
                        Add(SyncKinds.Incident, i.Id);
                        break;

                    case IncidentEvidence e:
                        Add(SyncKinds.IncidentEvidence, e.Id);
                        break;

                    case GateDevice d when entry.State == EntityState.Modified:
                        Add(SyncKinds.GateDevice, d.Id);
                        break;
                }
            }

            if (rows.Count == 0)
                return;

            context.Set<SyncOutboxEntry>().AddRange(rows);
            _queued = true;
        }

        private void Wake()
        {
            if (!_queued)
                return;

            _queued = false;
            _signal.Poke();
        }
    }
}
