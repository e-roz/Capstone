using AimPark.API.Sync.Site;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AimPark.API.Controllers
{
    /// <summary>
    /// Every piece of hardware the guard post depends on, in one list: the
    /// hub and the boards behind it, the USB readers, each gate's camera, and
    /// the link to the cloud. For the Overview (Security) and the dashboard
    /// (Admin).
    /// </summary>
    /// <remarks>
    /// Site server only, like <see cref="GateReadersController"/>: it reports
    /// what is plugged into this PC. The list itself is built by
    /// <see cref="DeviceHealthReport"/>, which also feeds the copy the cloud
    /// keeps for the online panel. What to do about a row is the panel's to say.
    /// </remarks>
    [ApiController]
    [Route("api/site/device-health")]
    [Authorize(AuthenticationSchemes = JwtBearerDefaults.AuthenticationScheme, Roles = "Admin,Security")]
    public class DeviceHealthController : ControllerBase
    {
        private readonly IServiceProvider _services;

        public DeviceHealthController(IServiceProvider services)
        {
            _services = services;
        }

        [HttpGet]
        public async Task<ActionResult<object>> Get(CancellationToken ct)
        {
            // Only registered on the site server: the cloud has no devices
            // plugged into it. The online panel reads GET /api/site-link instead.
            var report = _services.GetService<DeviceHealthReport>();
            if (report is null)
                return BadRequest(new
                {
                    message = "Device health is read from the guard post's server. Open the panel from the guard post's PC."
                });

            var health = await report.BuildAsync(ct);
            return Ok(new { checkedAt = health.CheckedAt, devices = health.Devices });
        }
    }
}
