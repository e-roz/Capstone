using AimPark.API.DTOs;
using AimPark.API.Enums;
using Microsoft.AspNetCore.Mvc;

namespace AimPark.API.Interfaces
{
    public interface INotificationService
    {
        Task<ActionResult<object>> BroadcastAsync(BroadcastNotificationDto dto, Guid adminUserId, CancellationToken ct);

        /// <summary>
        /// Raises a notification addressed to one person and pushes it to their
        /// devices. Best-effort and never throws: a failed push must not roll
        /// back the violation or payment that caused it.
        /// </summary>
        /// <param name="data">
        /// Extra key/value pairs delivered with the push, so the app can deep-link
        /// straight to the violation or payment being referred to.
        /// </param>
        Task NotifyUserAsync(
            Guid userId,
            NotificationType type,
            string title,
            string message,
            IDictionary<string, string>? data,
            CancellationToken ct);
        Task<ActionResult<NotificationListResponse>> ListAllAsync(int page, int pageSize, CancellationToken ct);
        Task<ActionResult<NotificationListResponse>> ListForUserAsync(Guid userId, UserRole role, int page, int pageSize, CancellationToken ct);
        Task<ActionResult<object>> MarkReadAsync(Guid userId, Guid notificationId, CancellationToken ct);
    }
}
