using AimPark.API.DTOs;
using AimPark.API.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;

namespace AimPark.API.Controllers
{
    [ApiController]
    [Route("api/admin/notifications")]
    [Authorize(Roles = "Admin")]
    public class AdminNotificationsController : ControllerBase
    {
        private readonly INotificationService _notificationService;

        public AdminNotificationsController(INotificationService notificationService)
        {
            _notificationService = notificationService;
        }

        [HttpGet]
        public Task<ActionResult<NotificationListResponse>> List(
            [FromQuery] int page = 1,
            [FromQuery] int pageSize = 20,
            CancellationToken ct = default)
            => _notificationService.ListAllAsync(page, pageSize, ct);

        /// <summary>
        /// What the system itself has pushed, newest first. <c>from</c> and
        /// <c>to</c> are instants (UTC); the Overview sends its period's bounds.
        /// </summary>
        [HttpGet("system")]
        public Task<ActionResult<NotificationListResponse>> ListSystem(
            [FromQuery] DateTime? from = null, [FromQuery] DateTime? to = null,
            [FromQuery] int take = 8, CancellationToken ct = default)
            => _notificationService.ListSystemAsync(from, to, take, ct);

        [HttpPost]
        public Task<ActionResult<object>> Broadcast([FromBody] BroadcastNotificationDto dto, CancellationToken ct)
            => _notificationService.BroadcastAsync(dto, GetAdminUserId(), ct);

        private Guid GetAdminUserId()
            => Guid.Parse(User.FindFirst(ClaimTypes.NameIdentifier)!.Value);
    }
}
