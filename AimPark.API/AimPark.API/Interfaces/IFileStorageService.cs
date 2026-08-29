namespace AimPark.API.Interfaces
{
    /// <summary>One object in a storage bucket, as the listing returns it.</summary>
    public record StoredObject(string Name, long SizeBytes, DateTime? UpdatedAt);

    public interface IFileStorageService
    {
        Task<string> SaveFileAsync(Guid userId, string documentType, IFormFile file, CancellationToken ct = default);
        Task<string> SaveFileAsync(string objectPath, IFormFile file, CancellationToken ct = default);
        Task<string> GetFileUrlAsync(string filePath, CancellationToken ct = default);

        // ── Bucket-addressed operations ──────────────────────────────────────
        // The three above are all about the "documents" bucket and say so by
        // omission. Backups live in their own bucket, so these take one.

        /// <summary>
        /// Creates <paramref name="bucket"/> if it does not exist yet. Safe to
        /// call on every write — an existing bucket is not an error.
        /// </summary>
        Task EnsureBucketAsync(string bucket, CancellationToken ct = default);

        Task<string> SaveBytesAsync(string bucket, string objectPath, byte[] content, string contentType, CancellationToken ct = default);

        /// <summary>Null when the object does not exist.</summary>
        Task<byte[]?> DownloadAsync(string bucket, string objectPath, CancellationToken ct = default);

        /// <summary>Newest first. An absent bucket lists as empty, not an error.</summary>
        Task<IReadOnlyList<StoredObject>> ListAsync(string bucket, string prefix = "", CancellationToken ct = default);
    }
}
