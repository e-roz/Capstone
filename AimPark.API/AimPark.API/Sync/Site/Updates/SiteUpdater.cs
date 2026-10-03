using System.Diagnostics;
using System.Net.Http.Json;
using System.Reflection;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using AimPark.API.Data;
using AimPark.API.Sync.Site.Setup;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Hosting.WindowsServices;
using Microsoft.Extensions.Options;

namespace AimPark.API.Sync.Site.Updates
{
    /// <summary>"Update now" was pressed, or there is something new to look at.</summary>
    public class UpdateSignal : SyncSignal { }

    public enum SiteUpdateState { UpToDate, Downloading, Ready, Installing, Failed }

    /// <summary>What the guard panel shows about updates, from <c>GET /api/site/status</c>.</summary>
    public class SiteUpdateStatus
    {
        private readonly object _lock = new();

        public string CurrentVersion { get; } = UpdatePolicy.Format(SiteUpdater.CurrentVersion);
        public string? AvailableVersion { get; private set; }
        public SiteUpdateState State { get; private set; } = SiteUpdateState.UpToDate;
        public DateTime? ReadyAt { get; private set; }
        public DateTime? LastCheckedAt { get; private set; }
        public string? LastError { get; private set; }
        public bool UpdateNowRequested { get; private set; }

        /// <summary>
        /// False under <c>dotnet run</c>: only the installed service replaces
        /// itself, so a developer's PC never runs an installer by surprise.
        /// </summary>
        public bool CanInstall { get; } = WindowsServiceHelpers.IsWindowsService();

        public void Set(SiteUpdateState state, string? available = null, DateTime? readyAt = null, string? error = null)
        {
            lock (_lock)
            {
                State = state;
                AvailableVersion = available;
                ReadyAt = readyAt;
                LastError = error;
                if (state != SiteUpdateState.Ready)
                    UpdateNowRequested = false;
            }
        }

        public void Checked(string? error = null)
        {
            lock (_lock)
            {
                LastCheckedAt = DateTime.UtcNow;
                if (error is not null)
                    LastError = error;
            }
        }

        public bool RequestUpdateNow()
        {
            lock (_lock)
            {
                if (State != SiteUpdateState.Ready || !CanInstall)
                    return false;
                UpdateNowRequested = true;
                return true;
            }
        }

        public object Snapshot()
        {
            lock (_lock)
            {
                return new
                {
                    currentVersion = CurrentVersion,
                    availableVersion = AvailableVersion,
                    state = State.ToString(),
                    readyAt = ReadyAt,
                    lastCheckedAt = LastCheckedAt,
                    lastError = LastError,
                    updateNowRequested = UpdateNowRequested,
                    canInstall = CanInstall
                };
            }
        }
    }

    /// <summary>
    /// Keeps the guard PC on the newest release, the way a phone keeps its
    /// apps current: looks at the GitHub releases every half hour, downloads a
    /// newer <c>AimParkSetup.exe</c> and checks it against its SHA-256 file,
    /// then installs it when the gates are quiet.
    /// </summary>
    /// <remarks>
    /// Installing stops this server for about a minute, and no gate can be
    /// answered meanwhile, so it waits for a spell with no taps: at night, or
    /// at the first quiet moment once the download is a day old, or straight
    /// away after "Update now" (<see cref="UpdatePolicy.ShouldInstall"/>).
    ///
    /// The installer stops this very service, so it can't be a child of it.
    /// It runs from a one-off scheduled task as SYSTEM instead, through
    /// <c>run-update.cmd</c>, which also starts the service again should the
    /// installer fail half way.
    /// </remarks>
    public class SiteUpdater : BackgroundService
    {
        public const string HttpClientName = "SiteUpdates";
        private const string TaskName = "AimParkUpdate";
        private const string ServiceName = "AimParkSite";

        /// <summary>A failed install isn't retried sooner than this.</summary>
        private static readonly TimeSpan RetryFailedAfter = TimeSpan.FromHours(6);

        private static readonly TimeSpan Tick = TimeSpan.FromMinutes(1);

        public static readonly Version CurrentVersion = UpdatePolicy.Normalize(
            Assembly.GetEntryAssembly()?.GetName().Version ?? new Version(0, 0, 0));

        public static readonly string Folder = Path.Combine(SiteSettingsFile.Folder, "updates");
        private static readonly string AttemptFile = Path.Combine(Folder, "attempt.json");
        private static readonly string LogFile = Path.Combine(Folder, "install.log");

        private readonly IServiceScopeFactory _scopes;
        private readonly IHttpClientFactory _http;
        private readonly UpdateSignal _signal;
        private readonly SiteUpdateStatus _status;
        private readonly SiteUpdateOptions _options;
        private readonly ILogger<SiteUpdater> _logger;

        private UpdateRelease? _ready;
        private string? _readyPath;

        public SiteUpdater(
            IServiceScopeFactory scopes,
            IHttpClientFactory http,
            UpdateSignal signal,
            SiteUpdateStatus status,
            IOptions<SiteOptions> options,
            ILogger<SiteUpdater> logger)
        {
            _scopes = scopes;
            _http = http;
            _signal = signal;
            _status = status;
            _options = options.Value.Updates;
            _logger = logger;
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            if (!_options.Enabled)
            {
                _logger.LogInformation("Automatic updates are off (Site:Updates:Enabled).");
                return;
            }

            Directory.CreateDirectory(Folder);
            var lastFailure = ReadPreviousAttempt();
            var nextCheck = DateTime.MinValue;

            while (!stoppingToken.IsCancellationRequested)
            {
                try
                {
                    if (DateTime.UtcNow >= nextCheck)
                    {
                        nextCheck = DateTime.UtcNow.AddMinutes(Math.Max(5, _options.CheckEveryMinutes));
                        await CheckAsync(lastFailure, stoppingToken);
                    }

                    if (_ready is not null && _status.State == SiteUpdateState.Ready && _status.CanInstall
                        && await QuietEnoughAsync(stoppingToken))
                    {
                        Install(_ready, _readyPath!);
                    }
                }
                catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
                {
                    return;
                }
                catch (Exception e)
                {
                    _logger.LogWarning(e, "Update check failed.");
                    _status.Checked(e.Message);
                }

                try { await _signal.WaitAsync(Tick, stoppingToken); }
                catch (OperationCanceledException) { return; }
            }
        }

        /// <summary>
        /// The last install this PC tried. Still on the old version means it
        /// failed: say so, and hold off retrying for a while.
        /// </summary>
        private (Version Version, DateTime At)? ReadPreviousAttempt()
        {
            try
            {
                if (!File.Exists(AttemptFile))
                    return null;
                var a = JsonSerializer.Deserialize<Attempt>(File.ReadAllText(AttemptFile));
                if (a is null || !Version.TryParse(a.Version, out var v) || UpdatePolicy.Normalize(v) <= CurrentVersion)
                {
                    File.Delete(AttemptFile);
                    _logger.LogInformation("Running {Version}.", UpdatePolicy.Format(CurrentVersion));
                    return null;
                }

                _logger.LogWarning("The update to {Version} didn't take. See {Log}.", a.Version, LogFile);
                return (UpdatePolicy.Normalize(v), a.At);
            }
            catch (Exception e)
            {
                _logger.LogWarning(e, "Couldn't read {File}.", AttemptFile);
                return null;
            }
        }

        private async Task CheckAsync((Version Version, DateTime At)? lastFailure, CancellationToken ct)
        {
            var client = _http.CreateClient(HttpClientName);
            var releases = await client.GetFromJsonAsync<List<GitHubRelease>>(_options.ReleasesUrl, ct) ?? new();
            var release = UpdatePolicy.PickRelease(releases, CurrentVersion);
            _status.Checked();

            if (release is null)
            {
                _ready = null;
                _status.Set(SiteUpdateState.UpToDate);
                return;
            }

            var version = UpdatePolicy.Format(release.Version);
            if (lastFailure is { } f && f.Version == release.Version && DateTime.UtcNow - f.At < RetryFailedAfter)
            {
                _status.Set(SiteUpdateState.Failed, version,
                    error: $"Installing {version} failed. It will try again after {f.At.Add(RetryFailedAfter).ToLocalTime():HH:mm}. Details: {LogFile}");
                return;
            }

            if (_ready == release && File.Exists(_readyPath))
            {
                if (_status.State != SiteUpdateState.Ready)
                    _status.Set(SiteUpdateState.Ready, version, File.GetLastWriteTimeUtc(_readyPath!));
                return;
            }

            var path = Path.Combine(Folder, UpdatePolicy.InstallerName(release.Version));
            RemoveOtherDownloads(path);

            // Only a file that passed the checksum is ever given its real name,
            // so one found here was checked before a restart.
            if (!File.Exists(path))
            {
                _status.Set(SiteUpdateState.Downloading, version);
                _logger.LogInformation("Downloading AimPark {Version}.", version);
                await DownloadAsync(client, release, path, ct);
            }

            _ready = release;
            _readyPath = path;
            _status.Set(SiteUpdateState.Ready, version, File.GetLastWriteTimeUtc(path));
            _logger.LogInformation("AimPark {Version} is ready to install.", version);
        }

        private static async Task DownloadAsync(HttpClient client, UpdateRelease release, string path, CancellationToken ct)
        {
            var expected = UpdatePolicy.ParseChecksum(await client.GetStringAsync(release.ChecksumUrl, ct))
                ?? throw new InvalidOperationException($"{UpdatePolicy.ChecksumName(release.Version)} holds no SHA-256.");

            var part = path + ".part";
            await using (var source = await client.GetStreamAsync(release.InstallerUrl, ct))
            await using (var target = File.Create(part))
                await source.CopyToAsync(target, ct);

            string actual;
            await using (var file = File.OpenRead(part))
                actual = Convert.ToHexString(await SHA256.HashDataAsync(file, ct)).ToLowerInvariant();

            if (actual != expected)
            {
                File.Delete(part);
                throw new InvalidOperationException(
                    $"The download of {UpdatePolicy.InstallerName(release.Version)} didn't match its checksum and was thrown away.");
            }

            File.Move(part, path, overwrite: true);
        }

        private static void RemoveOtherDownloads(string keep)
        {
            foreach (var file in Directory.EnumerateFiles(Folder, "AimParkSetup-*"))
            {
                if (!string.Equals(file, keep, StringComparison.OrdinalIgnoreCase))
                {
                    try { File.Delete(file); } catch (IOException) { /* in use; next time */ }
                }
            }
        }

        private async Task<bool> QuietEnoughAsync(CancellationToken ct)
        {
            using var scope = _scopes.CreateScope();
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            var lastTap = await db.GateTapEvents.MaxAsync(t => (DateTime?)t.At, ct);

            return UpdatePolicy.ShouldInstall(
                _options, DateTime.Now, DateTime.UtcNow,
                _status.ReadyAt ?? DateTime.UtcNow, lastTap, _status.UpdateNowRequested);
        }

        private void Install(UpdateRelease release, string installer)
        {
            var version = UpdatePolicy.Format(release.Version);
            _logger.LogWarning("Installing AimPark {Version}. The gates pause for about a minute.", version);

            var script = Path.Combine(Folder, "run-update.cmd");
            File.WriteAllText(script, string.Join("\r\n",
                "@echo off",
                $"\"{installer}\" /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /LOG=\"{LogFile}\"",
                $"echo %date% %time% {version} exit %errorlevel% >> \"{Path.Combine(Folder, "run-update.log")}\"",
                // The installer starts the service itself; this covers one that failed half way.
                $"net start {ServiceName}",
                $"schtasks /delete /tn {TaskName} /f",
                ""), Encoding.ASCII);

            File.WriteAllText(AttemptFile, JsonSerializer.Serialize(new Attempt { Version = version, At = DateTime.UtcNow }));
            _status.Set(SiteUpdateState.Installing, version);

            var created = RunSchtasks("/create", "/tn", TaskName, "/ru", "SYSTEM", "/rl", "HIGHEST",
                // ProgramData has no spaces in its path, so no quotes to escape.
                "/sc", "once", "/st", "00:00", "/f", "/tr", script);
            var started = created == 0 && RunSchtasks("/run", "/tn", TaskName) == 0;

            if (!started)
            {
                File.Delete(AttemptFile);
                _status.Set(SiteUpdateState.Ready, version, _status.ReadyAt,
                    "Couldn't start the installer (schtasks). It will try again.");
            }
        }

        private int RunSchtasks(params string[] args)
        {
            var info = new ProcessStartInfo("schtasks.exe")
            {
                UseShellExecute = false,
                CreateNoWindow = true,
                RedirectStandardOutput = true,
                RedirectStandardError = true
            };
            foreach (var a in args)
                info.ArgumentList.Add(a);

            using var p = Process.Start(info)!;
            var output = p.StandardOutput.ReadToEnd() + p.StandardError.ReadToEnd();
            p.WaitForExit(30_000);
            _logger.LogInformation("schtasks {Args} -> {Code}: {Output}", string.Join(' ', args), p.ExitCode, output.Trim());
            return p.ExitCode;
        }

        private class Attempt
        {
            public string Version { get; set; } = string.Empty;
            public DateTime At { get; set; }
        }
    }
}
