using AimPark.API.Data;
using AimPark.API.Entities;
using AimPark.API.Enums;
using AimPark.API.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace AimPark.API.Sync.Site
{
    /// <summary>The cloud's unpaid-bill list as of the last snapshot, held in memory.</summary>
    public class SiteDues
    {
        private volatile Copy? _current;

        public Copy? Current => _current;

        public void Set(SiteSnapshot snapshot)
        {
            // An older cloud sends no bill list. Keep "unknown" unknown so the
            // gate never blocks on data it was not given.
            _current = snapshot.Dues is null
                ? null
                : new Copy(
                    snapshot.GeneratedAt,
                    snapshot.Dues.ToLookup(d => d.UserId),
                    snapshot.Dues.Select(d => d.Id).ToHashSet(),
                    (snapshot.SettledPaymentIds ?? []).ToHashSet());
        }

        public sealed record Copy(
            DateTime GeneratedAt,
            ILookup<Guid, SyncDue> ByUser,
            HashSet<Guid> UnpaidIds,
            HashSet<Guid> SettledIds);
    }

    /// <summary>
    /// What a user owes, as the site server can best tell.
    /// </summary>
    /// <remarks>
    /// The site creates a parking fee when a car leaves, but never hears when it
    /// is paid, and fines are born in the cloud. Its own PaymentTransactions
    /// table therefore cannot answer alone. So: the cloud's list is
    /// authoritative, plus any bill the site created in the few minutes the
    /// snapshot may not yet have seen — unless the cloud says it was settled.
    /// No snapshot (or one from an older cloud) means no blocking.
    /// </remarks>
    public sealed class SiteEntryDues : IEntryDues
    {
        // How long a bill the site just made may take to reach the cloud.
        private static readonly TimeSpan CloudCatchUp = TimeSpan.FromMinutes(10);

        private readonly AppDbContext _db;
        private readonly SiteDues _dues;

        public SiteEntryDues(AppDbContext db, SiteDues dues)
        {
            _db = db;
            _dues = dues;
        }

        public async Task<IReadOnlyList<PaymentTransaction>> GetOwedAsync(Guid userId, CancellationToken ct)
        {
            var copy = _dues.Current;
            if (copy is null)
                return [];

            var bills = copy.ByUser[userId]
                .Select(d => new PaymentTransaction
                {
                    Id = d.Id,
                    UserId = d.UserId,
                    Source = d.Source,
                    Status = d.Status,
                    AmountDue = d.AmountDue,
                    DueAt = d.DueAt,
                    CreatedAt = d.CreatedAt
                })
                .ToList();

            var cutoff = copy.GeneratedAt - CloudCatchUp;
            var local = await _db.Set<PaymentTransaction>().AsNoTracking()
                .Where(p => p.UserId == userId
                            && p.Status == PaymentStatus.Pending
                            && p.AmountDue > 0m
                            && p.CreatedAt > cutoff)
                .ToListAsync(ct);

            bills.AddRange(local.Where(p => !copy.UnpaidIds.Contains(p.Id) && !copy.SettledIds.Contains(p.Id)));
            return bills;
        }
    }
}
