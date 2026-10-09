using AimPark.API.Data;
using AimPark.API.Entities;
using AimPark.API.Enums;
using AimPark.API.Interfaces;
using FirebaseAdmin.Messaging;
using Microsoft.EntityFrameworkCore;

namespace AimPark.API.Services
{
    /// <summary>
    /// Sends push notifications via Firebase Cloud Messaging.
    /// Delivery is best-effort: every failure is logged and swallowed, because a push
    /// that doesn't arrive must never fail the admin action that triggered it.
    /// If Firebase isn't configured (no credentials), this no-ops so the API still runs.
    /// </summary>
    public class FcmPushSender : IPushSender
    {
        // FCM caps a multicast at 500 tokens per call.
        private const int MaxTokensPerBatch = 500;

        private readonly AppDbContext _db;
        private readonly ILogger<FcmPushSender> _logger;

        public FcmPushSender(AppDbContext db, ILogger<FcmPushSender> logger)
        {
            _db = db;
            _logger = logger;
        }

        public Task SendToRoleAsync(UserRole? targetRole, string title, string body, IDictionary<string, string>? data, CancellationToken ct)
        {
            var query = _db.Set<DeviceToken>().AsNoTracking();

            if (targetRole is not null)
                query = query.Where(t => t.User.Role == targetRole);

            return SendAsync(query, title, body, data, ct);
        }

        public Task SendToUserAsync(Guid userId, string title, string body, IDictionary<string, string>? data, CancellationToken ct)
            => SendAsync(_db.Set<DeviceToken>().AsNoTracking().Where(t => t.UserId == userId), title, body, data, ct);

        private async Task SendAsync(IQueryable<DeviceToken> query, string title, string body, IDictionary<string, string>? data, CancellationToken ct)
        {
            try
            {
                if (FirebaseAdmin.FirebaseApp.DefaultInstance is null)
                {
                    _logger.LogDebug("Firebase is not configured — skipping push notification.");
                    return;
                }

                var tokens = await query.Select(t => t.Token).ToListAsync(ct);
                if (tokens.Count == 0)
                    return;

                var deadTokens = new List<string>();

                foreach (var batch in Chunk(tokens, MaxTokensPerBatch))
                {
                    var messages = batch.Select(token => new Message
                    {
                        Token = token,
                        Notification = new FirebaseAdmin.Messaging.Notification { Title = title, Body = body },
                        Data = data is null ? null : new Dictionary<string, string>(data),
                        Android = new AndroidConfig
                        {
                            Priority = Priority.High,
                            Notification = new AndroidNotification
                            {
                                // Must match the channel created on the Flutter side,
                                // otherwise Android 8+ silently drops the heads-up display.
                                ChannelId = "aimpark_default",
                            },
                        },
                    }).ToList();

                    var response = await FirebaseMessaging.DefaultInstance.SendEachAsync(messages, ct);

                    for (var i = 0; i < response.Responses.Count; i++)
                    {
                        var result = response.Responses[i];
                        if (result.IsSuccess)
                            continue;

                        // A token that FCM reports as unregistered/invalid belongs to an app
                        // that was uninstalled or reinstalled — prune it so the table doesn't
                        // fill with dead tokens we keep paying to retry.
                        var code = result.Exception?.MessagingErrorCode;
                        if (code is MessagingErrorCode.Unregistered or MessagingErrorCode.InvalidArgument)
                            deadTokens.Add(batch[i]);
                        else
                            _logger.LogWarning(result.Exception, "Push delivery failed for a device token.");
                    }
                }

                if (deadTokens.Count > 0)
                    await PruneAsync(deadTokens, ct);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to send push notification.");
            }
        }

        private async Task PruneAsync(List<string> deadTokens, CancellationToken ct)
        {
            try
            {
                await _db.Set<DeviceToken>()
                    .Where(t => deadTokens.Contains(t.Token))
                    .ExecuteDeleteAsync(ct);

                _logger.LogInformation("Pruned {Count} stale device token(s).", deadTokens.Count);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to prune stale device tokens.");
            }
        }

        private static IEnumerable<List<string>> Chunk(List<string> source, int size)
        {
            for (var i = 0; i < source.Count; i += size)
                yield return source.GetRange(i, Math.Min(size, source.Count - i));
        }
    }
}
