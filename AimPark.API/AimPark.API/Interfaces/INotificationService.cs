using AimPark.API.DTOs;
using AimPark.API.Enums;
using Microsoft.AspNetCore.Mvc;

namespace AimPark.API.Interfaces
{
    public interface INotificationService
    {
        Task<ActionResult<object>> BroadcastAsync(BroadcastNotificationDto dto, Guid adminUserId, CancellationToken ct);
        Task<ActionResult<NotificationListResponse>> ListAllAsync(int page, int pageSize, CancellationToken ct);
        Task<ActionResult<NotificationListResponse>> ListForUserAsync(Guid userId, UserRole role, int page, int pageSize, CancellationToken ct);
        Task<ActionResult<object>> MarkReadAsync(Guid userId, Guid notificationId, CancellationToken ct);
    }
}
