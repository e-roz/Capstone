using System.Text.Json.Serialization;

namespace AimPark.API.Sync.Site.Updates
{
    /// <summary>One entry of GitHub's releases list, only the parts used here.</summary>
    public class GitHubRelease
    {
        [JsonPropertyName("tag_name")] public string TagName { get; set; } = string.Empty;
        [JsonPropertyName("draft")] public bool Draft { get; set; }
        [JsonPropertyName("prerelease")] public bool Prerelease { get; set; }
        [JsonPropertyName("assets")] public List<GitHubAsset> Assets { get; set; } = new();
    }

    public class GitHubAsset
    {
        [JsonPropertyName("name")] public string Name { get; set; } = string.Empty;
        [JsonPropertyName("browser_download_url")] public string DownloadUrl { get; set; } = string.Empty;
    }

    /// <summary>A release this guard PC should move to, with both files it needs.</summary>
    public record UpdateRelease(Version Version, string InstallerUrl, string ChecksumUrl);

    /// <summary>
    /// The decisions behind <see cref="SiteUpdater"/>, with no clock, network
    /// or database of their own, so the tests can drive them.
    /// </summary>
    public static class UpdatePolicy
    {
        public const string TagPrefix = "site-installer-v";

        public static string InstallerName(Version v) => $"AimParkSetup-{Format(v)}.exe";

        public static string ChecksumName(Version v) => InstallerName(v) + ".sha256";

        /// <summary>1.2.0, never 1.2.0.0: how versions are tagged and shown.</summary>
        public static string Format(Version v) => $"{v.Major}.{v.Minor}.{Math.Max(v.Build, 0)}";

        /// <summary>Major.minor.patch only, so 1.2.0.0 from the assembly equals 1.2.0 from a tag.</summary>
        public static Version Normalize(Version v) => new(v.Major, v.Minor, Math.Max(v.Build, 0));

        public static Version? ParseTag(string tag) =>
            tag.StartsWith(TagPrefix, StringComparison.OrdinalIgnoreCase)
            && Version.TryParse(tag[TagPrefix.Length..], out var v)
                ? Normalize(v)
                : null;

        /// <summary>
        /// The newest published guard PC release, if it is newer than
        /// <paramref name="current"/> and carries both the installer and its
        /// checksum. Drafts, pre-releases and other tags are ignored.
        /// </summary>
        public static UpdateRelease? PickRelease(IEnumerable<GitHubRelease> releases, Version current)
        {
            current = Normalize(current);
            return releases
                .Where(r => !r.Draft && !r.Prerelease)
                .Select(r => (Release: r, Version: ParseTag(r.TagName)))
                .Where(x => x.Version is not null && x.Version > current)
                .OrderByDescending(x => x.Version)
                .Select(x =>
                {
                    var v = x.Version!;
                    var exe = x.Release.Assets.FirstOrDefault(a => a.Name.Equals(InstallerName(v), StringComparison.OrdinalIgnoreCase));
                    var sum = x.Release.Assets.FirstOrDefault(a => a.Name.Equals(ChecksumName(v), StringComparison.OrdinalIgnoreCase));
                    return exe is null || sum is null ? null : new UpdateRelease(v, exe.DownloadUrl, sum.DownloadUrl);
                })
                .FirstOrDefault(r => r is not null);
        }

        /// <summary>The hash from a .sha256 file: "abc123…" or "abc123…  AimParkSetup-1.2.0.exe".</summary>
        public static string? ParseChecksum(string text)
        {
            var hex = text.Trim().Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries).FirstOrDefault();
            return hex is { Length: 64 } && hex.All(Uri.IsHexDigit) ? hex.ToLowerInvariant() : null;
        }

        /// <summary>
        /// May a downloaded update install right now? Never while cars are
        /// tapping: the gates can't answer during the minute it takes. Beyond
        /// that, at night, once the deadline has passed, or straight away
        /// after "Update now".
        /// </summary>
        public static bool ShouldInstall(
            SiteUpdateOptions o,
            DateTime nowLocal,
            DateTime nowUtc,
            DateTime readyAtUtc,
            DateTime? lastTapUtc,
            bool updateNowRequested)
        {
            bool QuietFor(int minutes) => lastTapUtc is null || nowUtc - lastTapUtc.Value >= TimeSpan.FromMinutes(minutes);

            if (updateNowRequested)
                return QuietFor(o.UpdateNowQuietMinutes);

            if (!QuietFor(o.QuietMinutes))
                return false;

            var hour = nowLocal.Hour;
            var atNight = o.NightStartHour <= o.NightEndHour
                ? hour >= o.NightStartHour && hour < o.NightEndHour
                : hour >= o.NightStartHour || hour < o.NightEndHour;

            return atNight || nowUtc - readyAtUtc >= TimeSpan.FromHours(o.DeadlineHours);
        }
    }
}
