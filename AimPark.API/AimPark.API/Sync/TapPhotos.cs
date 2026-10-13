namespace AimPark.API.Sync
{
    /// <summary>
    /// Where the photo kept for each gate tap lives in the cloud, and how long.
    /// The guard PC sends them up; the online admin panel reads them back.
    /// </summary>
    public static class TapPhotos
    {
        public const string Bucket = "tap-photos";

        /// <summary>Photos older than this are deleted, here and on the guard PC.</summary>
        public const int Days = 30;

        /// <summary>A 640-pixel JPEG is tens of kilobytes; this is generous.</summary>
        public const int MaxBytes = 2 * 1024 * 1024;

        public static string ObjectPath(Guid tapId) => $"{tapId:N}.jpg";

        public static bool LooksLikeJpeg(byte[] bytes) =>
            bytes.Length > 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF;
    }
}
