using AimPark.API.Auth;
using AimPark.API.DTOs;
using AimPark.API.Interfaces;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;

namespace AimPark.API.Controllers
{
    /// <summary>
    /// Carries a card UID from the reader on the admin's desk to the Assign
    /// dialog on their screen.
    /// </summary>
    /// <remarks>
    /// Until now an admin read the UID off a serial monitor or a printed label
    /// and typed it in, which is the single most common way a card ends up
    /// registered in a form the gate will never match. The reader posts the
    /// UID; the panel polls for it; nobody types anything.
    ///
    /// The two halves are deliberately separate calls with separate auth: the
    /// reader may only write a scan, the admin may only read one. A reader
    /// cannot look up who holds a card, and reading the buffer does not require
    /// hardware to be online.
    /// </remarks>
    [ApiController]
    [Route("api/admin/rfid")]
    public class AdminRfidEnrollmentController : ControllerBase
    {
        private readonly IRfidEnrollmentService _enrollment;

        public AdminRfidEnrollmentController(IRfidEnrollmentService enrollment)
        {
            _enrollment = enrollment;
        }

        /// <summary>
        /// Posted by the enrollment reader on every tap. Device key only — this
        /// is not something a signed-in person should be able to fake, since
        /// the whole point is that the value came off real hardware.
        /// </summary>
        [Authorize(
            AuthenticationSchemes = ApiKeyDefaults.AuthenticationScheme,
            Roles = ApiKeyDefaults.DeviceRole)]
        [HttpPost("scan")]
        public Task<ActionResult<RfidScanResponse>> Scan(
            [FromBody] RfidScanDto dto, CancellationToken ct)
            => _enrollment.RecordScanAsync(dto, DeviceId, DeviceName, ct);

        /// <summary>
        /// Polled by the admin panel while its Assign dialog is open. Returns
        /// null rather than 404 when nothing has been tapped — "no card yet" is
        /// the normal state, not an error.
        /// </summary>
        [Authorize(
            AuthenticationSchemes = JwtBearerDefaults.AuthenticationScheme,
            Roles = "Admin")]
        [HttpGet("last-scan")]
        public Task<ActionResult<RfidLastScanResponse?>> LastScan(CancellationToken ct)
            => _enrollment.GetLastScanAsync(ct);

        private Guid DeviceId => Guid.Parse(User.FindFirst(ClaimTypes.NameIdentifier)!.Value);

        private string DeviceName => User.FindFirst(ClaimTypes.Name)?.Value ?? "Reader";
    }
}
