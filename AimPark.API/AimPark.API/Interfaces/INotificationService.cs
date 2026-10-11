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
        /// <summary>
        /// Raises a notification for everyone holding a role, with no
        /// administrator behind it, and pushes it to their devices.
        /// </summary>
        /// <remarks>
        /// Distinct from <c>BroadcastAsync</c>, which records the administrator
        /// who chose to send it. This is the system noticing something - the lot
        /// filling up, a bay coming free - where there is no author to record
        /// and nobody pressed anything.
        ///
        /// Best-effort and never throws, for the same reason as
        /// <see cref="NotifyUserAsync"/>: logging an entry must not fail because
        /// messaging did.
        /// </remarks>
        Task NotifyRoleAsync(
            UserRole role,
            NotificationType type,
            string title,
            string message,
            CancellationToken ct);

        Task<ActionResult<NotificationListResponse>> ListAllAsync(int page, int pageSize, CancellationToken ct);
        Task<ActionResult<NotificationListResponse>> ListForUserAsync(Guid userId, UserRole role, int page, int pageSize, CancellationToken ct);
        Task<ActionResult<object>> MarkReadAsync(Guid userId, Guid notificationId, CancellationToken ct);
    }
}
