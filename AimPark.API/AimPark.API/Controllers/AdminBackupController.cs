using AimPark.API.DTOs;
using AimPark.API.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;

namespace AimPark.API.Controllers
{
    /// <summary>
    /// Data Backup &amp; Restore — the maintenance module.
    ///
    /// Admin only, with no Security access at all: a restore replaces every
    /// row in the database, which is the most destructive thing the panel can
    /// do and is nobody's gate work.
    /// </summary>
    [ApiController]
    [Route("api/admin/backup")]
    [Authorize(Roles = "Admin")]
    public class AdminBackupController : ControllerBase
    {
        /// <summary>
        /// Uploads are capped well above the global 10 MB Kestrel limit, which
        /// is sized for a photograph of a licence rather than for a dump of
        /// every table.
        /// </summary>
        private const long UploadLimitBytes = 64L * 1024 * 1024;

        private readonly IBackupService _backupService;

        public AdminBackupController(IBackupService backupService)
        {
            _backupService = backupService;
        }

        /// <summary>
        /// Backups already taken, newest first, as held in storage.
        /// </summary>
        [HttpGet]
        public Task<ActionResult<BackupListResponse>> List(CancellationToken ct)
            => _backupService.ListAsync(ct);

        /// <summary>
        /// Exports every table to a JSON file, keeps a copy in storage, and
        /// returns the file for download.
        /// </summary>
        [HttpPost]
        public Task<ActionResult> Create(CancellationToken ct)
            => _backupService.CreateAsync(GetAdminUserId(), ct);

        /// <summary>
        /// Downloads a backup taken earlier, by its file name.
        /// </summary>
        [HttpGet("{fileName}")]
        public Task<ActionResult> Download(string fileName, CancellationToken ct)
            => _backupService.DownloadAsync(fileName, ct);

        /// <summary>
        /// Reports what restoring the uploaded file would do — what it holds,
        /// and what it would replace. Changes nothing.
        /// </summary>
        [HttpPost("preview")]
        [Consumes("multipart/form-data")]
        [RequestSizeLimit(UploadLimitBytes)]
        [RequestFormLimits(MultipartBodyLengthLimit = UploadLimitBytes)]
        public Task<ActionResult<RestorePreviewResponse>> Preview(IFormFile file, CancellationToken ct)
            => _backupService.PreviewAsync(file, GetAdminUserId(), ct);

        /// <summary>
        /// Replaces the database with the uploaded backup.
        /// </summary>
        /// <remarks>
        /// Three things have to line up before this runs: the caller is an
        /// administrator, they re-enter their own password, and they type the
        /// confirmation word. A safety copy of the current database is taken
        /// first, and the whole replacement happens in one transaction.
        /// </remarks>
        [HttpPost("restore")]
        [Consumes("multipart/form-data")]
        [RequestSizeLimit(UploadLimitBytes)]
        [RequestFormLimits(MultipartBodyLengthLimit = UploadLimitBytes)]
        public Task<ActionResult<RestoreResultResponse>> Restore(
            IFormFile file,
            [FromForm] string password,
            [FromForm] string confirmation,
            CancellationToken ct)
            => _backupService.RestoreAsync(file, GetAdminUserId(), password, confirmation, ct);

        private Guid GetAdminUserId()
            => Guid.Parse(User.FindFirst(ClaimTypes.NameIdentifier)!.Value);
    }
}
