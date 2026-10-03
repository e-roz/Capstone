using AimPark.API.Data;
using AimPark.API.Entities;
using AimPark.API.Sync;
using AimPark.API.Sync.Site;
using AimPark.API.Sync.Site.Updates;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace AimPark.API.Controllers
{
    /// <summary>
    /// Is the site server keeping up with the cloud? Open to anyone who can
    /// reach it: it holds no data, and the person asking is usually standing
    /// at the guard post wondering why the app looks stale.
    /// </summary>
    [ApiController]
    [Route("api/site/status")]
    public class SiteStatusController : ControllerBase
    {
        private readonly SiteOptions _options;
        private readonly IServiceProvider _services;

        public SiteStatusController(IOptions<SiteOptions> options, IServiceProvider services)
        {
            _options = options.Value;
            _services = services;
        }

        [HttpGet]
        public async Task<ActionResult<object>> Get(CancellationToken ct)
        {
            if (!_options.IsSite)
                return Ok(new { mode = _options.Mode.ToString() });

            var status = _services.GetRequiredService<SiteSyncStatus>();
            var db = _services.GetRequiredService<AppDbContext>();

            return Ok(new
            {
                mode = _options.Mode.ToString(),
                cloudConnected = status.CloudConnected,
                lastSnapshotAt = status.LastSnapshotAt,
                lastSnapshotError = status.LastSnapshotError,
                lastPushAt = status.LastPushAt,
                lastPushError = status.LastPushError,
                waitingToSend = await db.Set<SyncOutboxEntry>().CountAsync(ct),
                // The panel reloads itself when this changes after an update.
                version = UpdatePolicy.Format(SiteUpdater.CurrentVersion),
                update = _services.GetRequiredService<SiteUpdateStatus>().Snapshot()
            });
        }

        /// <summary>
        /// "Update now" on the guard panel: install the downloaded update as
        /// soon as the gates have been quiet for a minute, instead of waiting
        /// for the night.
        /// </summary>
        [HttpPost("/api/site/update/install")]
        [Authorize(AuthenticationSchemes = JwtBearerDefaults.AuthenticationScheme, Roles = "Admin,Security")]
        public ActionResult InstallUpdate()
        {
            if (!_options.IsSite)
                return NotFound();

            var status = _services.GetRequiredService<SiteUpdateStatus>();
            if (!status.RequestUpdateNow())
                return Conflict(new { message = status.CanInstall
                    ? "There is no downloaded update to install."
                    : "Only the installed guard PC server can install updates." });

            _services.GetRequiredService<UpdateSignal>().Poke();
            return Accepted(status.Snapshot());
        }
    }
}
