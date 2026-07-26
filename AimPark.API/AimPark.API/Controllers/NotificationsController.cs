using AimPark.API.DTOs;
using AimPark.API.Enums;
using AimPark.API.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;

namespace AimPark.API.Controllers
{
    [ApiController]
    [Route("api/notifications")]
    [Authorize]
    public class NotificationsController : ControllerBase
    {
        private readonly INotificationService _notificationService;
        private readonly IDeviceTokenService _deviceTokenService;

        public NotificationsController(
            INotificationService notificationService,
            IDeviceTokenService deviceTokenService)
        {
            _notificationService = notificationService;
            _deviceTokenService = deviceTokenService;
        }

        [HttpGet]
        public Task<ActionResult<NotificationListResponse>> List(
            [FromQuery] int page = 1,
            [FromQuery] int pageSize = 20,
            CancellationToken ct = default)
            => _notificationService.ListForUserAsync(GetUserId(), GetRole(), page, pageSize, ct);

        [HttpPost("{notificationId:guid}/read")]
        public Task<ActionResult<object>> MarkRead(Guid notificationId, CancellationToken ct)
            => _notificationService.MarkReadAsync(GetUserId(), notificationId, ct);

        /// <summary>
        /// Registers this device's FCM token so the user can receive push notifications.
        /// Called by the mobile app after login and whenever FCM rotates the token.
        /// </summary>
        [HttpPost("device-token")]
        public Task<ActionResult<object>> RegisterDeviceToken(
            [FromBody] RegisterDeviceTokenDto dto, CancellationToken ct)
            => _deviceTokenService.RegisterAsync(GetUserId(), dto, ct);

        /// <summary>
        /// Removes this device's FCM token — called on logout so the next person
        /// signing in on this phone doesn't receive the previous user's notifications.
        /// </summary>
        [HttpDelete("device-token")]
        public Task<ActionResult<object>> UnregisterDeviceToken(
            [FromBody] RegisterDeviceTokenDto dto, CancellationToken ct)
            => _deviceTokenService.UnregisterAsync(GetUserId(), dto, ct);

        private Guid GetUserId()
            => Guid.Parse(User.FindFirst(ClaimTypes.NameIdentifier)!.Value);

        private UserRole GetRole()
            => Enum.Parse<UserRole>(User.FindFirst(ClaimTypes.Role)!.Value);
    }
}
