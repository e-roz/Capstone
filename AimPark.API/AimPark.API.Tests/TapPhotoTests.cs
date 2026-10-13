using AimPark.API.Sync;
using AimPark.API.Sync.Site.Cameras;

namespace AimPark.API.Tests;

public class TapPhotoTests : IDisposable
{
    private readonly string _root = Path.Combine(Path.GetTempPath(), "tap-photos-" + Guid.NewGuid().ToString("N"));

    public void Dispose()
    {
        if (Directory.Exists(_root)) Directory.Delete(_root, recursive: true);
    }

    private string Photo(Guid id, string day = "2026-10-14", DateTime? writtenUtc = null)
    {
        var folder = Path.Combine(_root, day);
        Directory.CreateDirectory(folder);
        var path = Path.Combine(folder, $"{id:N}.jpg");
        File.WriteAllBytes(path, [0xFF, 0xD8, 0xFF, 0xE0]);
        File.SetLastWriteTimeUtc(path, writtenUtc ?? DateTime.UtcNow.AddMinutes(-1));
        return path;
    }

    [Fact]
    public void AnUnsentPhotoIsPending()
    {
        var id = Guid.NewGuid();
        Photo(id);

        var pending = TapPhotoUploader.Pending(_root, DateTime.UtcNow, 10);

        Assert.Equal(id, Assert.Single(pending).TapId);
    }

    [Fact]
    public void ASentPhotoIsNotPendingAgain()
    {
        var path = Photo(Guid.NewGuid());
        File.WriteAllBytes(path + ".sent", []);

        Assert.Empty(TapPhotoUploader.Pending(_root, DateTime.UtcNow, 10));
    }

    [Fact]
    public void APhotoStillBeingWrittenWaitsForTheNextPass()
    {
        Photo(Guid.NewGuid(), writtenUtc: DateTime.UtcNow);

        Assert.Empty(TapPhotoUploader.Pending(_root, DateTime.UtcNow, 10));
    }

    [Fact]
    public void NewestPhotosGoFirstAndOnlyAsManyAsAsked()
    {
        var old = Guid.NewGuid();
        var recent = Guid.NewGuid();
        Photo(old, "2026-10-13", DateTime.UtcNow.AddHours(-20));
        Photo(recent, "2026-10-14", DateTime.UtcNow.AddMinutes(-5));

        var pending = TapPhotoUploader.Pending(_root, DateTime.UtcNow, 1);

        Assert.Equal(recent, Assert.Single(pending).TapId);
    }

    [Fact]
    public void AFileThatIsNotNamedForATapIsIgnored()
    {
        var folder = Path.Combine(_root, "2026-10-14");
        Directory.CreateDirectory(folder);
        File.WriteAllBytes(Path.Combine(folder, "notes.jpg"), [0xFF, 0xD8, 0xFF]);

        Assert.Empty(TapPhotoUploader.Pending(_root, DateTime.UtcNow, 10));
    }

    [Fact]
    public void OnlyAJpegIsAccepted()
    {
        Assert.True(TapPhotos.LooksLikeJpeg([0xFF, 0xD8, 0xFF, 0xE0]));
        Assert.False(TapPhotos.LooksLikeJpeg([0x89, 0x50, 0x4E, 0x47]));
        Assert.False(TapPhotos.LooksLikeJpeg([]));
    }
}
