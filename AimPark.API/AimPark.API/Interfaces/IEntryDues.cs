using AimPark.API.Data;
using AimPark.API.Entities;
using AimPark.API.Enums;
using Microsoft.EntityFrameworkCore;

namespace AimPark.API.Interfaces
{
    /// <summary>
    /// Where the gate learns what a card holder still owes. The cloud reads its
    /// own payments; the site server cannot (see <c>SiteEntryDues</c>).
    /// </summary>
    public interface IEntryDues
    {
        /// <summary>Unpaid bills for one user, fed to <c>UnpaidBalance.Evaluate</c>.</summary>
        Task<IReadOnlyList<PaymentTransaction>> GetOwedAsync(Guid userId, CancellationToken ct);

        /// <summary>
        /// Has this one bill been settled (paid or waived)? Asked at the exit, where
        /// a driver with a fee to pay is held until it is. A bill that is only
        /// <see cref="PaymentStatus.Processing"/> is not settled: the checkout was
        /// opened, but nothing has confirmed the money.
        /// </summary>
        Task<bool> IsSettledAsync(Guid paymentId, CancellationToken ct);
    }

    /// <summary>The cloud's answer, and the default: payments are settled here.</summary>
    public sealed class DbEntryDues : IEntryDues
    {
        private readonly AppDbContext _db;

        public DbEntryDues(AppDbContext db) => _db = db;

        public async Task<IReadOnlyList<PaymentTransaction>> GetOwedAsync(Guid userId, CancellationToken ct) =>
            await _db.Set<PaymentTransaction>().AsNoTracking()
                .Where(p => p.UserId == userId && p.Status == PaymentStatus.Pending && p.AmountDue > 0m)
                .ToListAsync(ct);

        public Task<bool> IsSettledAsync(Guid paymentId, CancellationToken ct) =>
            _db.Set<PaymentTransaction>().AsNoTracking()
                .AnyAsync(p => p.Id == paymentId
                               && (p.Status == PaymentStatus.Paid || p.Status == PaymentStatus.Waived), ct);
    }
}
