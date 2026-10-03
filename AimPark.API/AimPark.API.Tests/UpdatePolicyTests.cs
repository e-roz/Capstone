using AimPark.API.Sync;
using AimPark.API.Sync.Site.Updates;

namespace AimPark.API.Tests;

public class UpdatePolicyTests
{
    private static GitHubRelease Release(string tag, bool draft = false, bool pre = false, bool withChecksum = true)
    {
        var r = new GitHubRelease { TagName = tag, Draft = draft, Prerelease = pre };
        var v = UpdatePolicy.ParseTag(tag);
        if (v is not null)
        {
            r.Assets.Add(new GitHubAsset { Name = UpdatePolicy.InstallerName(v), DownloadUrl = $"https://x/{tag}.exe" });
            if (withChecksum)
                r.Assets.Add(new GitHubAsset { Name = UpdatePolicy.ChecksumName(v), DownloadUrl = $"https://x/{tag}.sha256" });
        }
        return r;
    }

    [Fact]
    public void Picks_the_newest_guard_release_above_the_current_version()
    {
        var picked = UpdatePolicy.PickRelease(
            new[] { Release("site-installer-v1.2.0"), Release("site-installer-v1.10.0"), Release("site-installer-v1.1.0") },
            new Version(1, 1, 0, 0));

        Assert.Equal(new Version(1, 10, 0), picked!.Version);
        Assert.Equal("https://x/site-installer-v1.10.0.exe", picked.InstallerUrl);
    }

    [Fact]
    public void Nothing_to_do_when_already_on_the_newest()
    {
        Assert.Null(UpdatePolicy.PickRelease(new[] { Release("site-installer-v1.1.0") }, new Version(1, 1, 0, 0)));
    }

    [Fact]
    public void Skips_drafts_prereleases_other_tags_and_releases_without_a_checksum()
    {
        var picked = UpdatePolicy.PickRelease(
            new[]
            {
                Release("site-installer-v1.5.0", draft: true),
                Release("site-installer-v1.4.0", pre: true),
                Release("site-installer-v1.3.0", withChecksum: false),
                Release("v9.0.0-test"),
                Release("site-installer-v1.2.0"),
            },
            new Version(1, 1, 0));

        Assert.Equal(new Version(1, 2, 0), picked!.Version);
    }

    [Theory]
    [InlineData("E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855  AimParkSetup-1.2.0.exe")]
    [InlineData("e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855\n")]
    public void Reads_the_hash_from_a_checksum_file(string text)
    {
        Assert.Equal("e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", UpdatePolicy.ParseChecksum(text));
    }

    [Fact]
    public void Rejects_a_checksum_file_without_a_hash()
    {
        Assert.Null(UpdatePolicy.ParseChecksum("Not Found"));
    }

    private static readonly SiteUpdateOptions Options = new();
    private static readonly DateTime Ready = new(2026, 10, 3, 9, 0, 0, DateTimeKind.Utc);

    private static bool Should(int localHour, DateTime nowUtc, int? minutesSinceTap, bool updateNow = false) =>
        UpdatePolicy.ShouldInstall(
            Options,
            new DateTime(2026, 10, 3, localHour, 0, 0),
            nowUtc,
            Ready,
            minutesSinceTap is null ? null : nowUtc.AddMinutes(-minutesSinceTap.Value),
            updateNow);

    [Fact]
    public void Installs_at_night_when_the_gates_are_quiet()
    {
        Assert.True(Should(localHour: 2, Ready.AddHours(1), minutesSinceTap: 10));
        Assert.True(Should(localHour: 2, Ready.AddHours(1), minutesSinceTap: null));
    }

    [Fact]
    public void Never_installs_while_cars_are_tapping()
    {
        Assert.False(Should(localHour: 2, Ready.AddHours(1), minutesSinceTap: 2));
        Assert.False(Should(localHour: 14, Ready.AddHours(30), minutesSinceTap: 2));
    }

    [Fact]
    public void Waits_for_the_night_during_the_day()
    {
        Assert.False(Should(localHour: 14, Ready.AddHours(3), minutesSinceTap: 60));
        Assert.False(Should(localHour: 5, Ready.AddHours(3), minutesSinceTap: 60));
    }

    [Fact]
    public void Installs_at_the_first_quiet_moment_after_the_deadline()
    {
        Assert.True(Should(localHour: 14, Ready.AddHours(24), minutesSinceTap: 6));
    }

    [Fact]
    public void Update_now_needs_only_a_minute_of_quiet()
    {
        Assert.True(Should(localHour: 14, Ready.AddMinutes(5), minutesSinceTap: 1, updateNow: true));
        Assert.False(Should(localHour: 14, Ready.AddMinutes(5), minutesSinceTap: 0, updateNow: true));
    }

    [Fact]
    public void A_night_window_across_midnight_works()
    {
        var o = new SiteUpdateOptions { NightStartHour = 23, NightEndHour = 3 };
        var now = Ready.AddHours(1);
        Assert.True(UpdatePolicy.ShouldInstall(o, new DateTime(2026, 10, 3, 23, 30, 0), now, Ready, null, false));
        Assert.True(UpdatePolicy.ShouldInstall(o, new DateTime(2026, 10, 3, 1, 0, 0), now, Ready, null, false));
        Assert.False(UpdatePolicy.ShouldInstall(o, new DateTime(2026, 10, 3, 12, 0, 0), now, Ready, null, false));
    }
}
