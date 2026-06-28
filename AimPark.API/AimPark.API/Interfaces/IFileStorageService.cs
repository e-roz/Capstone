namespace AimPark.API.Interfaces
{
    public interface IFileStorageService
    {
        Task<string> SaveFileAsync(Guid userId, string documentType, IFormFile file, CancellationToken ct = default);
        Task<string> GetFileUrlAsync(string filePath, CancellationToken ct = default);
    }
}
