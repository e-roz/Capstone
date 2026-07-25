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

        public NotificationsController(INotificationService notificationService)
        {
            _notificationService = notificationService;
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

        private Guid GetUserId()
            => Guid.Parse(User.FindFirst(ClaimTypes.NameIdentifier)!.Value);

        private UserRole GetRole()
            => Enum.Parse<UserRole>(User.FindFirst(ClaimTypes.Role)!.Value);
    }
}
