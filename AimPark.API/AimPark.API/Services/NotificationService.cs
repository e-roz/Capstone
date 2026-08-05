using AimPark.API.Data;
using AimPark.API.DTOs;
using AimPark.API.Entities;
using AimPark.API.Enums;
using AimPark.API.Interfaces;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace AimPark.API.Services
{
    public class NotificationService : INotificationService
    {
        private readonly IRepository<Notification> _notifications;
        private readonly IRepository<NotificationRead> _reads;
        private readonly IPushSender _pushSender;
        private readonly ILogger<NotificationService> _logger;
        private readonly AppDbContext _db;

        public NotificationService(
            IRepository<Notification> notifications,
            IRepository<NotificationRead> reads,
            IPushSender pushSender,
            ILogger<NotificationService> logger,
            AppDbContext db)
        {
            _notifications = notifications;
            _reads = reads;
            _pushSender = pushSender;
            _logger = logger;
            _db = db;
        }

        public async Task NotifyUserAsync(
            Guid userId,
            NotificationType type,
            string title,
            string message,
            IDictionary<string, string>? data,
            CancellationToken ct)
        {
            try
            {
                var notification = new Notification
                {
                    Id = Guid.NewGuid(),
                    Title = title,
                    Message = message,
                    Type = type,
                    TargetUserId = userId,
                    TargetRole = null,
                    CreatedByUserId = Guid.Empty, // raised by the system, not an admin
                    CreatedAt = DateTime.UtcNow
                };

                await _notifications.AddAsync(notification, ct);
                await _notifications.SaveAsync(ct);

                var payload = new Dictionary<string, string>(data ?? new Dictionary<string, string>())
                {
                    ["type"] = "notification",
                    ["notificationId"] = notification.Id.ToString(),
                };

                // Persisted above, so a push failure costs the heads-up but never
                // the notification itself — the user still sees it in the app.
                await _pushSender.SendToUserAsync(userId, title, message, payload, ct);
            }
            catch (Exception ex)
            {
                // Notifying is never the point of the operation that triggered it.
                // Issuing a violation must not fail because messaging did.
                _logger.LogError(ex, "Failed to notify user {UserId}.", userId);
            }
        }

        // POST /api/admin/notifications
        public async Task<ActionResult<object>> BroadcastAsync(BroadcastNotificationDto dto, Guid adminUserId, CancellationToken ct)
        {
            if (string.IsNullOrWhiteSpace(dto.Title) || string.IsNullOrWhiteSpace(dto.Message))
                return new BadRequestObjectResult(new { message = "Title and message are required." });

            if (!Enum.TryParse<NotificationType>(dto.Type, true, out var type))
                return new BadRequestObjectResult(new { message = "Invalid notification type." });

            UserRole? targetRole = null;
            if (!string.IsNullOrWhiteSpace(dto.TargetRole))
            {
                if (!Enum.TryParse<UserRole>(dto.TargetRole, true, out var parsedRole))
                    return new BadRequestObjectResult(new { message = "Invalid target role." });
                targetRole = parsedRole;
            }

            var notification = new Notification
            {
                Id = Guid.NewGuid(),
                Title = dto.Title.Trim(),
                Message = dto.Message.Trim(),
                Type = type,
                TargetRole = targetRole,
                TargetUserId = null, // broadcast — see NotifyUserAsync for addressed ones
                CreatedByUserId = adminUserId,
                CreatedAt = DateTime.UtcNow
            };

            await _notifications.AddAsync(notification, ct);
            await _notifications.SaveAsync(ct);

            // Best-effort push — the in-app notification is already persisted above,
            // so a push failure never costs the user the notification itself.
            await _pushSender.SendToRoleAsync(
                targetRole,
                notification.Title,
                notification.Message,
                new Dictionary<string, string>
                {
                    ["type"] = "notification",
                    ["notificationId"] = notification.Id.ToString(),
                },
                ct);

            return new OkObjectResult(new { message = "Notification broadcast." });
        }

        // GET /api/admin/notifications
        public async Task<ActionResult<NotificationListResponse>> ListAllAsync(int page, int pageSize, CancellationToken ct)
        {
            page = Math.Max(1, page);
            pageSize = Math.Clamp(pageSize, 1, 100);

            var query = _db.Set<Notification>().AsNoTracking();
            var totalCount = await query.CountAsync(ct);

            var notifications = await query
                .OrderByDescending(n => n.CreatedAt)
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .Select(n => new NotificationResponse
                {
                    NotificationId = n.Id,
                    Title = n.Title,
                    Message = n.Message,
                    Type = n.Type.ToString(),
                    TargetRole = n.TargetRole == null ? null : n.TargetRole.ToString(),
                    CreatedAt = n.CreatedAt,
                    IsRead = false
                })
                .ToListAsync(ct);

            return new OkObjectResult(new NotificationListResponse
            {
                Notifications = notifications,
                TotalCount = totalCount,
                Page = page,
                PageSize = pageSize,
                UnreadCount = 0
            });
        }

        // GET /api/notifications
        public async Task<ActionResult<NotificationListResponse>> ListForUserAsync(Guid userId, UserRole role, int page, int pageSize, CancellationToken ct)
        {
            page = Math.Max(1, page);
            pageSize = Math.Clamp(pageSize, 1, 100);

            // Two kinds reach a user: notifications addressed to them personally,
            // and broadcasts for their role. A personally-addressed row must never
            // fall through into someone else's list, hence the TargetUserId null
            // check on the broadcast side.
            var baseQuery = _db.Set<Notification>().AsNoTracking()
                .Where(n => n.TargetUserId == userId
                         || (n.TargetUserId == null
                             && (n.TargetRole == null || n.TargetRole == role)));

            var totalCount = await baseQuery.CountAsync(ct);
            var unreadCount = await baseQuery.CountAsync(
                n => !_db.Set<NotificationRead>().Any(r => r.NotificationId == n.Id && r.UserId == userId), ct);

            var notifications = await baseQuery
                .OrderByDescending(n => n.CreatedAt)
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .Select(n => new NotificationResponse
                {
                    NotificationId = n.Id,
                    Title = n.Title,
                    Message = n.Message,
                    Type = n.Type.ToString(),
                    TargetRole = n.TargetRole == null ? null : n.TargetRole.ToString(),
                    CreatedAt = n.CreatedAt,
                    IsRead = _db.Set<NotificationRead>().Any(r => r.NotificationId == n.Id && r.UserId == userId)
                })
                .ToListAsync(ct);

            return new OkObjectResult(new NotificationListResponse
            {
                Notifications = notifications,
                TotalCount = totalCount,
                Page = page,
                PageSize = pageSize,
                UnreadCount = unreadCount
            });
        }

        // POST /api/notifications/{id}/read
        public async Task<ActionResult<object>> MarkReadAsync(Guid userId, Guid notificationId, CancellationToken ct)
        {
            var notification = await _notifications.FindAsync(n => n.Id == notificationId, ct);
            if (notification is null)
                return new NotFoundObjectResult(new { message = "Notification not found." });

            var alreadyRead = await _reads.ExistsAsync(r => r.NotificationId == notificationId && r.UserId == userId, ct);
            if (alreadyRead)
                return new OkObjectResult(new { message = "Already marked as read." });

            await _reads.AddAsync(new NotificationRead
            {
                Id = Guid.NewGuid(),
                NotificationId = notificationId,
                UserId = userId,
                ReadAt = DateTime.UtcNow
            }, ct);
            await _reads.SaveAsync(ct);

            return new OkObjectResult(new { message = "Marked as read." });
        }
    }
}
