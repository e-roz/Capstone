using System.Net.Http.Json;
using AimPark.API.Interfaces;

namespace AimPark.API.Sync.Site
{
    /// <summary>
    /// The site server's file storage: it holds no storage credentials of its
    /// own, so it asks the cloud to store a file or to hand out a link to one.
    /// </summary>
    /// <remarks>
    /// Only the incident queue needs files here — attaching a photo to a report
    /// and opening a driver's photo. Both need the internet, and fail with an
    /// exception without it, which the incident code turns into a clear
    /// message. Registration, documents and backups run in the cloud (the site
    /// forwards those requests), so the rest of the interface is never called.
    /// </remarks>
    public class CloudFileStorage : IFileStorageService
    {
        private readonly IHttpClientFactory _http;

        public CloudFileStorage(IHttpClientFactory http)
        {
            _http = http;
        }

        public async Task<string> SaveFileAsync(string objectPath, IFormFile file, CancellationToken ct = default)
        {
            using var form = new MultipartFormDataContent();
            form.Add(new StringContent(objectPath), "objectPath");

            await using var stream = file.OpenReadStream();
            var content = new StreamContent(stream);
            if (!string.IsNullOrWhiteSpace(file.ContentType))
                content.Headers.ContentType = new System.Net.Http.Headers.MediaTypeHeaderValue(file.ContentType);
            form.Add(content, "file", file.FileName);

            using var response = await Client.PostAsync("api/site-sync/files", form, ct);
            response.EnsureSuccessStatusCode();

            return objectPath;
        }

        public async Task<string> GetFileUrlAsync(string filePath, CancellationToken ct = default)
        {
            using var response = await Client.PostAsJsonAsync(
                "api/site-sync/file-url", new FileUrlRequest { Path = filePath }, ct);
            response.EnsureSuccessStatusCode();

            var body = await response.Content.ReadFromJsonAsync<FileUrlResponse>(ct);
            return body?.Url ?? throw new InvalidOperationException("The cloud sent no link for the file.");
        }

        private HttpClient Client => _http.CreateClient(SiteOutboxPusher.CloudClient);

        private static NotSupportedException CloudOnly() =>
            new("This runs in the cloud; the site server forwards those requests there.");

        public Task<string> SaveFileAsync(Guid userId, string documentType, IFormFile file, CancellationToken ct = default)
            => throw CloudOnly();

        public Task EnsureBucketAsync(string bucket, CancellationToken ct = default)
            => throw CloudOnly();

        public Task<string> SaveBytesAsync(string bucket, string objectPath, byte[] content, string contentType, CancellationToken ct = default)
            => throw CloudOnly();

        public Task<byte[]?> DownloadAsync(string bucket, string objectPath, CancellationToken ct = default)
            => throw CloudOnly();

        public Task<IReadOnlyList<StoredObject>> ListAsync(string bucket, string prefix = "", CancellationToken ct = default)
            => throw CloudOnly();

        public Task<int> DeleteAsync(string bucket, IReadOnlyCollection<string> objectPaths, CancellationToken ct = default)
            => throw CloudOnly();
    }

    public class FileUrlRequest
    {
        public string Path { get; set; } = string.Empty;
    }

    public class FileUrlResponse
    {
        public string Url { get; set; } = string.Empty;
    }
}
