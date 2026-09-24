using AimPark.API.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;

namespace AimPark.API.Sync.Cloud
{
    /// <summary>
    /// Watches every save on the cloud for changes to data the gates read,
    /// and has the site server told once the save has committed.
    /// </summary>
    /// <remarks>
    /// Sitting on the save itself, rather than calls sprinkled through the
    /// services, is what makes "instant" hold: a suspension, a new card, a
    /// changed plate or a visitor pass reaches the site whichever screen or
    /// endpoint made it — including ones written after this.
    /// </remarks>
    public class MasterDataChangeInterceptor : SaveChangesInterceptor
    {
        private readonly MasterDataChangeNotifier _notifier;
        private readonly SyncSuppression _suppression;
        private bool _pending;

        public MasterDataChangeInterceptor(MasterDataChangeNotifier notifier, SyncSuppression suppression)
        {
            _notifier = notifier;
            _suppression = suppression;
        }

        public override InterceptionResult<int> SavingChanges(
            DbContextEventData eventData, InterceptionResult<int> result)
        {
            Inspect(eventData.Context);
            return result;
        }

        public override ValueTask<InterceptionResult<int>> SavingChangesAsync(
            DbContextEventData eventData, InterceptionResult<int> result, CancellationToken cancellationToken = default)
        {
            Inspect(eventData.Context);
            return ValueTask.FromResult(result);
        }

        public override int SavedChanges(SaveChangesCompletedEventData eventData, int result)
        {
            Flush();
            return result;
        }

        public override ValueTask<int> SavedChangesAsync(
            SaveChangesCompletedEventData eventData, int result, CancellationToken cancellationToken = default)
        {
            Flush();
            return ValueTask.FromResult(result);
        }

        public override void SaveChangesFailed(DbContextErrorEventData eventData) => _pending = false;

        public override Task SaveChangesFailedAsync(DbContextErrorEventData eventData, CancellationToken cancellationToken = default)
        {
            _pending = false;
            return Task.CompletedTask;
        }

        private void Inspect(DbContext? context)
        {
            if (context is null || _suppression.Active)
                return;

            // The interceptor runs before EF's own DetectChanges, so without
            // this a property set on a tracked entity would not show yet.
            context.ChangeTracker.DetectChanges();

            foreach (var entry in context.ChangeTracker.Entries())
            {
                if (entry.State is not (EntityState.Added or EntityState.Modified or EntityState.Deleted))
                    continue;

                if (IsGateData(entry))
                {
                    _pending = true;
                    return;
                }
            }
        }

        private static bool IsGateData(Microsoft.EntityFrameworkCore.ChangeTracking.EntityEntry entry) => entry.Entity switch
        {
            User or Vehicle or VisitorPass or ParkingSlot or ParkingRate => true,

            // Every authenticated device request moves LastSeenAt, the site's
            // own included. Counting that would have the site re-download on
            // a loop driven by its own requests.
            GateDevice => entry.State != EntityState.Modified ||
                          entry.Properties.Any(p => p.IsModified && p.Metadata.Name != nameof(GateDevice.LastSeenAt)),

            _ => false
        };

        private void Flush()
        {
            if (!_pending)
                return;

            _pending = false;
            _notifier.Notify();
        }
    }
}
