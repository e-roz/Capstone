using AimPark.API.DTOs;
using Microsoft.AspNetCore.Mvc;

namespace AimPark.API.Interfaces
{
    public interface IBackupService
    {
        /// <summary>Past backups held in storage, newest first.</summary>
        Task<ActionResult<BackupListResponse>> ListAsync(CancellationToken ct);

        /// <summary>
        /// Exports every table to one JSON file, keeps a copy in storage, and
        /// returns the bytes for the administrator to download.
        /// </summary>
        Task<ActionResult> CreateAsync(Guid adminUserId, CancellationToken ct);

        /// <summary>Re-downloads a backup taken earlier.</summary>
        Task<ActionResult> DownloadAsync(string fileName, CancellationToken ct);

        /// <summary>
        /// Reads an uploaded file and reports what restoring it would do.
        /// Writes nothing.
        /// </summary>
        Task<ActionResult<RestorePreviewResponse>> PreviewAsync(
            IFormFile file, Guid adminUserId, CancellationToken ct);

        /// <summary>
        /// Replaces the contents of every table with the uploaded file, in one
        /// transaction, after taking a safety backup of what was there.
        /// </summary>
        Task<ActionResult<RestoreResultResponse>> RestoreAsync(
            IFormFile file, Guid adminUserId, string password, string confirmation, CancellationToken ct);
    }
}
