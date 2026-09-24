using AimPark.API.Auth;
using AimPark.API.Sync;
using AimPark.API.Sync.Cloud;
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
        private readonly SnapshotBuilder _snapshots;
        private readonly EventIngestor _ingestor;

        public SiteSyncController(SnapshotBuilder snapshots, EventIngestor ingestor)
        {
            _snapshots = snapshots;
            _ingestor = ingestor;
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
    }
}
