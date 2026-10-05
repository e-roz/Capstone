using AimPark.API.Sync.Cloud;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AimPark.API.Controllers
{
    /// <summary>
    /// The guard post as the cloud sees it: is it connected, when did it last
    /// send gate records, and its latest device list.
    /// </summary>
    /// <remarks>
    /// For the online panel's parking map, which reads the cloud and so needs
    /// to say how fresh that is. At the guard post this request is passed
    /// through to the cloud like any other, and the panel there prefers its
    /// own server's live device list anyway.
    /// </remarks>
    [ApiController]
    [Route("api/site-link")]
    [Authorize(AuthenticationSchemes = JwtBearerDefaults.AuthenticationScheme, Roles = "Admin,Security")]
    public class SiteLinkController : ControllerBase
    {
        private readonly SiteLinkState _link;

        public SiteLinkController(SiteLinkState link)
        {
            _link = link;
        }

        [HttpGet]
        public ActionResult<object> Get()
        {
            var s = _link.Snapshot();
            return Ok(new
            {
                now = DateTime.UtcNow,
                connected = s.Connected,
                connectedSince = s.ConnectedSince,
                disconnectedAt = s.DisconnectedAt,
                lastPushAt = s.LastPushAt,
                healthAt = s.HealthAt,
                devices = s.Devices
            });
        }
    }
}
