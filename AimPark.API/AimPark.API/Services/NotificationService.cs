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
        private readonly AppDbContext _db;

        public NotificationService(
            IRepository<Notification> notifications,
            IRepository<NotificationRead> reads,
            IPushSender pushSender,
            AppDbContext db)
        {
            _notifications = notifications;
            _reads = reads;
            _pushSender = pushSender;
            _db = db;
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

            var baseQuery = _db.Set<Notification>().AsNoTracking()
                .Where(n => n.TargetRole == null || n.TargetRole == role);

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
