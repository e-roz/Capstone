namespace AimPark.API.Sync.Site.Cameras
{
    /// <summary>The newest picture a gate's camera sent.</summary>
    public record CameraFrame(byte[] Jpeg, DateTime At);

    /// <summary>
    /// The live picture from each gate's ALPR camera, and the photo kept for
    /// each tap.
    /// </summary>
    /// <remarks>
    /// Only the newest frame per gate is held, in memory: the guard's panel
    /// polls it a few times a second, and a frame nobody fetched in time is
    /// worth nothing. A tap copies the frame of that moment to disk under
    /// ProgramData, next to gate-readers.json, and those photos are deleted
    /// after <see cref="PhotoDays"/> days so the guard PC's disk doesn't fill.
    /// </remarks>
    public class CameraFrames : BackgroundService
    {
        /// <summary>A frame older than this means the camera app has stopped.</summary>
        public static readonly TimeSpan Fresh = TimeSpan.FromSeconds(5);

        private const int PhotoDays = 30;

        private static readonly string PhotosRoot = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData),
            "AimPark", "tap-photos");

        private readonly ILogger<CameraFrames> _logger;
        private readonly object _lock = new();
        private readonly Dictionary<int, CameraFrame> _frames = new();

        public CameraFrames(ILogger<CameraFrames> logger)
        {
            _logger = logger;
        }

        public void Put(int gate, byte[] jpeg)
        {
            lock (_lock) _frames[gate] = new CameraFrame(jpeg, DateTime.UtcNow);
        }

        /// <summary>The gate's newest frame, or null when the camera has gone quiet.</summary>
        public CameraFrame? Latest(int gate)
        {
            lock (_lock)
                return _frames.TryGetValue(gate, out var frame) && DateTime.UtcNow - frame.At <= Fresh
                    ? frame
                    : null;
        }

        /// <summary>Keeps the gate's current frame as the photo for a tap. False when there is none.</summary>
        public bool SavePhoto(int gate, Guid tapId, DateTime at)
        {
            var frame = Latest(gate);
            if (frame is null) return false;

            try
            {
                var path = PhotoPath(tapId, at);
                Directory.CreateDirectory(Path.GetDirectoryName(path)!);
                File.WriteAllBytes(path, frame.Jpeg);
                return true;
            }
            catch (Exception ex)
            {
                _logger.LogWarning("Could not save the photo for tap {Id}: {Error}", tapId, ex.Message);
                return false;
            }
        }

        public static string PhotoPath(Guid tapId, DateTime at)
            => Path.Combine(PhotosRoot, at.ToLocalTime().ToString("yyyy-MM-dd"), $"{tapId:N}.jpg");

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            while (!stoppingToken.IsCancellationRequested)
            {
                DeleteOldPhotos();

                try
                {
                    await Task.Delay(TimeSpan.FromDays(1), stoppingToken);
                }
                catch (OperationCanceledException)
                {
                    break;
                }
            }
        }

        private void DeleteOldPhotos()
        {
            if (!Directory.Exists(PhotosRoot)) return;

            var cutoff = DateTime.Now.Date.AddDays(-PhotoDays);
            foreach (var folder in Directory.GetDirectories(PhotosRoot))
            {
                if (!DateTime.TryParseExact(Path.GetFileName(folder), "yyyy-MM-dd", null,
                        System.Globalization.DateTimeStyles.None, out var day) || day >= cutoff)
                    continue;

                try
                {
                    Directory.Delete(folder, recursive: true);
                }
                catch (Exception ex)
                {
                    _logger.LogWarning("Could not delete old tap photos in {Folder}: {Error}", folder, ex.Message);
                }
            }
        }
    }
}
