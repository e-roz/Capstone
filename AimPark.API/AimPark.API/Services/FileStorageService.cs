using System.Net.Http.Headers;
using System.Net.Http.Json;
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
    }
}
