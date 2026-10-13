using System.Net.Http.Headers;

namespace AimPark.API.Sync.Site.Cameras
{
    /// <summary>
    /// Sends the photo kept for each tap up to the cloud, so an admin can open
    /// it from the online panel.
    /// </summary>
    /// <remarks>
    /// The photo is saved on this PC first, at the tap, and the gate never waits
    /// on this. A photo goes up once; a small <c>.sent</c> file beside it says
    /// so. With no internet a pass simply stops and tries again a little later,
    /// so a day offline sends everything it missed when the connection returns.
    /// The local copy stays for 30 days either way.
    /// </remarks>
    public class TapPhotoUploader : BackgroundService
    {
        private const string SentMarker = ".sent";
        private const int PerPass = 50;

        private static readonly TimeSpan Every = TimeSpan.FromSeconds(20);

        /// <summary>A photo this new may still be being written.</summary>
        private static readonly TimeSpan Settle = TimeSpan.FromSeconds(2);

        private readonly IHttpClientFactory _http;
        private readonly ILogger<TapPhotoUploader> _logger;

        public TapPhotoUploader(IHttpClientFactory http, ILogger<TapPhotoUploader> logger)
        {
            _http = http;
            _logger = logger;
        }

        /// <summary>The photos under <paramref name="root"/> not yet sent, newest first.</summary>
        public static List<(Guid TapId, string Path)> Pending(string root, DateTime nowUtc, int max)
        {
            if (!Directory.Exists(root)) return [];

            var pending = new List<(Guid TapId, string Path, DateTime At)>();

            foreach (var file in Directory.EnumerateFiles(root, "*.jpg", SearchOption.AllDirectories))
            {
                if (!Guid.TryParseExact(System.IO.Path.GetFileNameWithoutExtension(file), "N", out var tapId))
                    continue;

                if (File.Exists(file + SentMarker))
                    continue;

                var written = File.GetLastWriteTimeUtc(file);
                if (nowUtc - written < Settle)
                    continue;

                pending.Add((tapId, file, written));
            }

            return [.. pending
                .OrderByDescending(p => p.At)
                .Take(max)
                .Select(p => (p.TapId, p.Path))];
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            while (!stoppingToken.IsCancellationRequested)
            {
                try
                {
                    await SendPendingAsync(stoppingToken);
                }
                catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
                {
                    return;
                }
                catch (Exception ex)
                {
                    // No internet, or the cloud said no. Whatever was not sent
                    // is still on disk and is picked up on the next pass.
                    _logger.LogWarning("Could not send tap photos to the cloud yet: {Error}", ex.Message);
                }

                try
                {
                    await Task.Delay(Every, stoppingToken);
                }
                catch (OperationCanceledException)
                {
                    return;
                }
            }
        }

        private async Task SendPendingAsync(CancellationToken ct)
        {
            var client = _http.CreateClient(SiteOutboxPusher.CloudClient);

            foreach (var (tapId, path) in Pending(CameraFrames.PhotosRoot, DateTime.UtcNow, PerPass))
            {
                byte[] bytes;
                try
                {
                    bytes = await File.ReadAllBytesAsync(path, ct);
                }
                catch (IOException)
                {
                    continue; // Deleted or still open; the next pass looks again.
                }

                using var content = new ByteArrayContent(bytes);
                content.Headers.ContentType = new MediaTypeHeaderValue("image/jpeg");

                using var response = await client.PostAsync($"api/site-sync/tap-photos/{tapId:N}", content, ct);
                response.EnsureSuccessStatusCode();

                await File.WriteAllBytesAsync(path + SentMarker, [], ct);
            }
        }
    }
}
