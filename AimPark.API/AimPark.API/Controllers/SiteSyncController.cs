using AimPark.API.Auth;
using AimPark.API.Interfaces;
using AimPark.API.Sync;
using AimPark.API.Sync.Cloud;
using AimPark.API.Sync.Site;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AimPark.API.Controllers
{
    /// <summary>
    /// The cloud's side of the site server's sync. Site-server key only.
    /// </summary>
    [ApiController]
    [Route("api/site-sync")]
    [Authorize(AuthenticationSchemes = ApiKeyDefaults.AuthenticationScheme, Policy = SitePolicies.SiteServer)]
    public class SiteSyncController : ControllerBase
    {
        /// <summary>
        /// The only files the site server may touch: incident attachments.
        /// A leaked site key must not open registration documents.
        /// </summary>
        private const string IncidentEvidencePrefix = "incident-evidence/";

        private readonly SnapshotBuilder _snapshots;
        private readonly EventIngestor _ingestor;
        private readonly IFileStorageService _files;

        public SiteSyncController(SnapshotBuilder snapshots, EventIngestor ingestor, IFileStorageService files)
        {
            _snapshots = snapshots;
            _ingestor = ingestor;
            _files = files;
        }

        /// <summary>Everything a gate decision reads, for the site's own copy.</summary>
        [HttpGet("snapshot")]
        public async Task<ActionResult<SiteSnapshot>> Snapshot(CancellationToken ct)
            => Ok(await _snapshots.BuildAsync(ct));

        /// <summary>What happened at the gates since the site last sent.</summary>
        [HttpPost("events")]
        public async Task<ActionResult<object>> Events([FromBody] SiteEventBatch batch, CancellationToken ct)
        {
            var skipped = await _ingestor.IngestAsync(batch, ct);
            return Ok(new { skipped });
        }

        /// <summary>A short-lived link to an incident attachment, for the guard post to show.</summary>
        [HttpPost("file-url")]
        public async Task<ActionResult<FileUrlResponse>> FileUrl([FromBody] FileUrlRequest request, CancellationToken ct)
        {
            if (!IsIncidentEvidence(request.Path))
                return BadRequest(new { message = "Only incident attachments can be opened from the guard post." });

            return Ok(new FileUrlResponse { Url = await _files.GetFileUrlAsync(request.Path, ct) });
        }

        /// <summary>Stores a photo a guard attached to an incident report.</summary>
        [HttpPost("files")]
        [RequestSizeLimit(10 * 1024 * 1024)]
        public async Task<ActionResult<object>> Files([FromForm] string objectPath, IFormFile file, CancellationToken ct)
        {
            if (!IsIncidentEvidence(objectPath))
                return BadRequest(new { message = "Only incident attachments can be stored from the guard post." });

            await _files.SaveFileAsync(objectPath, file, ct);
            return Ok(new { objectPath });
        }

        private static bool IsIncidentEvidence(string? path) =>
            !string.IsNullOrWhiteSpace(path) &&
            path.StartsWith(IncidentEvidencePrefix, StringComparison.Ordinal) &&
            !path.Contains("..", StringComparison.Ordinal);
    }
}
