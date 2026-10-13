using AimPark.API.Data;
using AimPark.API.Entities;
using AimPark.API.Interfaces;
using AimPark.API.Sync;
using Microsoft.EntityFrameworkCore;

namespace AimPark.API.Services
{
    /// <summary>
    /// Deletes the tap photos the guard PC sent up once they are 30 days old.
    /// </summary>
    /// <remarks>
    /// Cloud only. The photos are named by their tap, so the taps that fell out
    /// of the 30 days in the last week say which ones to delete: the bucket
    /// listing is not ordered by time. A run that was missed is made up for by
    /// the next, up to a week later.
    /// </remarks>
    public class TapPhotoCleanupService : BackgroundService
    {
        private const int Catchup = 7;
        private const int BatchSize = 100;

        private readonly IServiceScopeFactory _scopes;
        private readonly ILogger<TapPhotoCleanupService> _logger;

        public TapPhotoCleanupService(IServiceScopeFactory scopes, ILogger<TapPhotoCleanupService> logger)
        {
            _scopes = scopes;
            _logger = logger;
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            try { await Task.Delay(TimeSpan.FromMinutes(2), stoppingToken); }
            catch (OperationCanceledException) { return; }

            while (!stoppingToken.IsCancellationRequested)
            {
                try
                {
                    using var scope = _scopes.CreateScope();
                    var removed = await DeleteOldAsync(
                        scope.ServiceProvider.GetRequiredService<AppDbContext>(),
                        scope.ServiceProvider.GetRequiredService<IFileStorageService>(),
                        DateTime.UtcNow, stoppingToken);

                    if (removed > 0)
                        _logger.LogInformation("{Count} tap photo(s) older than {Days} days deleted.", removed, TapPhotos.Days);
                }
                catch (Exception ex) when (ex is not OperationCanceledException)
                {
                    _logger.LogError(ex, "Tap photo cleanup failed.");
                }

                try { await Task.Delay(TimeSpan.FromDays(1), stoppingToken); }
                catch (OperationCanceledException) { return; }
            }
        }

        /// <returns>How many photos were actually there to delete.</returns>
        public static async Task<int> DeleteOldAsync(
            AppDbContext db, IFileStorageService files, DateTime nowUtc, CancellationToken ct)
        {
            var newest = nowUtc.AddDays(-TapPhotos.Days);
            var oldest = newest.AddDays(-Catchup);

            var ids = await db.Set<GateTapEvent>().AsNoTracking()
                .Where(t => t.HasPhoto && t.At < newest && t.At >= oldest)
                .Select(t => t.Id)
                .ToListAsync(ct);

            var removed = 0;
            foreach (var batch in ids.Chunk(BatchSize))
                removed += await files.DeleteAsync(TapPhotos.Bucket, [.. batch.Select(TapPhotos.ObjectPath)], ct);

            return removed;
        }
    }
}
