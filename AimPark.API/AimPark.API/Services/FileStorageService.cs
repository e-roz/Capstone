using AimPark.API.Interfaces;

namespace AimPark.API.Services
{
    public class FileStorageService : IFileStorageService
    {
        private readonly IConfiguration _configuration;

        public FileStorageService(IConfiguration configuration)
        {
            _configuration = configuration;
        }

        public async Task<string> SaveFileAsync(Guid userId, string documentType, IFormFile file, CancellationToken ct = default)
        {
            var uploadPath = _configuration["FileStorage:UploadPath"]
                ?? Path.Combine(Path.GetTempPath(), "aimpark-uploads");

            var userFolder = Path.Combine(uploadPath, userId.ToString());
            Directory.CreateDirectory(userFolder);

            var ext = Path.GetExtension(file.FileName).ToLowerInvariant();
            var fileName = $"{documentType.ToLowerInvariant()}{ext}";
            var filePath = Path.Combine(userFolder, fileName);

            await using var stream = new FileStream(filePath, FileMode.Create);
            await file.CopyToAsync(stream, ct);

            return filePath;
        }

        public Task<string> GetFileUrlAsync(string filePath, CancellationToken ct = default)
        {
            return Task.FromResult(filePath);
        }
    }
}
