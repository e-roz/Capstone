using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json.Serialization;
using AimPark.API.Interfaces;

namespace AimPark.API.Services
{
    public class FileStorageService : IFileStorageService
    {
        private const string Bucket = "documents";

        private readonly HttpClient _httpClient;
        private readonly IConfiguration _configuration;

        public FileStorageService(HttpClient httpClient, IConfiguration configuration)
        {
            _httpClient = httpClient;
            _configuration = configuration;
        }

        public Task<string> SaveFileAsync(Guid userId, string documentType, IFormFile file, CancellationToken ct = default)
        {
            var ext = Path.GetExtension(file.FileName).ToLowerInvariant();
            var objectPath = $"{userId}/{documentType.ToLowerInvariant()}{ext}";
            return SaveFileAsync(objectPath, file, ct);
        }

        public async Task<string> SaveFileAsync(string objectPath, IFormFile file, CancellationToken ct = default)
        {
            await using var stream = file.OpenReadStream();
            using var content = new StreamContent(stream);
            content.Headers.ContentType = new MediaTypeHeaderValue(
                string.IsNullOrWhiteSpace(file.ContentType) ? "application/octet-stream" : file.ContentType);

            var request = BuildRequest(HttpMethod.Post, $"/storage/v1/object/{Bucket}/{objectPath}");
            request.Content = content;
            request.Headers.Add("x-upsert", "true");

            var response = await _httpClient.SendAsync(request, ct);
            if (!response.IsSuccessStatusCode)
            {
                var body = await response.Content.ReadAsStringAsync(ct);
                throw new InvalidOperationException($"Failed to upload document to storage: {response.StatusCode} {body}");
            }

            return objectPath;
        }

        public async Task<string> GetFileUrlAsync(string filePath, CancellationToken ct = default)
        {
            var request = BuildRequest(HttpMethod.Post, $"/storage/v1/object/sign/{Bucket}/{filePath}");
            request.Content = JsonContent.Create(new { expiresIn = 3600 });

            var response = await _httpClient.SendAsync(request, ct);
            if (!response.IsSuccessStatusCode)
            {
                var body = await response.Content.ReadAsStringAsync(ct);
                throw new InvalidOperationException($"Failed to generate document URL: {response.StatusCode} {body}");
            }

            var result = await response.Content.ReadFromJsonAsync<SignedUrlResponse>(cancellationToken: ct);
            var baseUrl = _configuration["Supabase:Url"]!.TrimEnd('/');
            // Supabase's signedURL is returned WITHOUT the /storage/v1 prefix
            // (e.g. "/object/sign/..."), even though that prefix is required to
            // actually resolve it — it must be added back on here.
            return $"{baseUrl}/storage/v1{result!.SignedURL}";
        }

        // ── Bucket-addressed operations ──────────────────────────────────────
        //
        // The three above are all about the "documents" bucket and say so by
        // omission. Backups live in a bucket of their own, so these take one.

        public async Task EnsureBucketAsync(string bucket, CancellationToken ct = default)
        {
            var request = BuildRequest(HttpMethod.Post, "/storage/v1/bucket");
            request.Content = JsonContent.Create(new { name = bucket, id = bucket, @public = false });

            var response = await _httpClient.SendAsync(request, ct);
            if (response.IsSuccessStatusCode) return;

            // Already there is the normal case after the first ever backup, and
            // Supabase reports it as a 400/409 carrying "already exists" rather
            // than as a success. Anything else is a real failure worth raising.
            var body = await response.Content.ReadAsStringAsync(ct);
            if (response.StatusCode is HttpStatusCode.Conflict or HttpStatusCode.BadRequest &&
                body.Contains("already exists", StringComparison.OrdinalIgnoreCase))
            {
                return;
            }

            throw new InvalidOperationException(
                $"Failed to create storage bucket {bucket}: {response.StatusCode} {body}");
        }

        public async Task<string> SaveBytesAsync(
            string bucket,
            string objectPath,
            byte[] content,
            string contentType,
            CancellationToken ct = default)
        {
            using var body = new ByteArrayContent(content);
            body.Headers.ContentType = new MediaTypeHeaderValue(contentType);

            var request = BuildRequest(HttpMethod.Post, $"/storage/v1/object/{bucket}/{objectPath}");
            request.Content = body;
            request.Headers.Add("x-upsert", "true");

            var response = await _httpClient.SendAsync(request, ct);
            if (!response.IsSuccessStatusCode)
            {
                var error = await response.Content.ReadAsStringAsync(ct);
                throw new InvalidOperationException(
                    $"Failed to upload to {bucket}: {response.StatusCode} {error}");
            }

            return objectPath;
        }

        public async Task<byte[]?> DownloadAsync(string bucket, string objectPath, CancellationToken ct = default)
        {
            var request = BuildRequest(HttpMethod.Get, $"/storage/v1/object/{bucket}/{objectPath}");

            var response = await _httpClient.SendAsync(request, ct);
            if (response.StatusCode == HttpStatusCode.NotFound) return null;

            if (!response.IsSuccessStatusCode)
            {
                var error = await response.Content.ReadAsStringAsync(ct);
                throw new InvalidOperationException(
                    $"Failed to download {objectPath} from {bucket}: {response.StatusCode} {error}");
            }

            return await response.Content.ReadAsByteArrayAsync(ct);
        }

        public async Task<IReadOnlyList<StoredObject>> ListAsync(
            string bucket,
            string prefix = "",
            CancellationToken ct = default)
        {
            var request = BuildRequest(HttpMethod.Post, $"/storage/v1/object/list/{bucket}");
            request.Content = JsonContent.Create(new
            {
                prefix,
                limit = 200,
                offset = 0,
                sortBy = new { column = "name", order = "desc" }
            });

            var response = await _httpClient.SendAsync(request, ct);

            if (!response.IsSuccessStatusCode)
            {
                var error = await response.Content.ReadAsStringAsync(ct);

                // A bucket nobody has written to yet is an empty history, not a
                // fault — the backup screen has to render before the first
                // backup is ever taken. Supabase has reported this as both 404
                // and 400 across versions, so the body is what decides.
                if (response.StatusCode is HttpStatusCode.NotFound or HttpStatusCode.BadRequest &&
                    error.Contains("not found", StringComparison.OrdinalIgnoreCase))
                {
                    return [];
                }

                throw new InvalidOperationException(
                    $"Failed to list {bucket}: {response.StatusCode} {error}");
            }

            var items = await response.Content.ReadFromJsonAsync<List<StorageListItem>>(cancellationToken: ct) ?? [];

            return items
                // Supabase returns a placeholder row for the folder itself. It
                // carries no metadata and is not a file anyone can restore.
                .Where(i => !string.IsNullOrEmpty(i.Name) && i.Metadata is not null)
                .Select(i => new StoredObject(i.Name, i.Metadata!.Size, i.UpdatedAt))
                .ToList();
        }

        private HttpRequestMessage BuildRequest(HttpMethod method, string relativePath)
        {
            var baseUrl = _configuration["Supabase:Url"]!.TrimEnd('/');
            var serviceKey = _configuration["Supabase:ServiceRoleKey"];

            var request = new HttpRequestMessage(method, $"{baseUrl}{relativePath}");
            request.Headers.Add("apikey", serviceKey);
            request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", serviceKey);
            return request;
        }

        private class SignedUrlResponse
        {
            public string SignedURL { get; set; } = string.Empty;
        }

        private class StorageListItem
        {
            [JsonPropertyName("name")]
            public string Name { get; set; } = string.Empty;

            [JsonPropertyName("updated_at")]
            public DateTime? UpdatedAt { get; set; }

            [JsonPropertyName("metadata")]
            public StorageListMetadata? Metadata { get; set; }
        }

        private class StorageListMetadata
        {
            [JsonPropertyName("size")]
            public long Size { get; set; }
        }
    }
}
