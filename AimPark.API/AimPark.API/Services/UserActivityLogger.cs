using AimPark.API.Data;
using AimPark.API.Entities;
using AimPark.API.Interfaces;

namespace AimPark.API.Services
{
    public class UserActivityLogger : IUserActivityLogger
    {
        private readonly AppDbContext _db;
        private readonly IHttpContextAccessor _http;
        private readonly ILogger<UserActivityLogger> _logger;

        public UserActivityLogger(
            AppDbContext db,
            IHttpContextAccessor http,
            ILogger<UserActivityLogger> logger)
        {
            _db = db;
            _http = http;
            _logger = logger;
        }

        public async Task LogAsync(
            Guid? userId,
            string email,
            string activity,
            string? detail = null,
            CancellationToken ct = default)
        {
            try
            {
                _db.UserActivityLogs.Add(new UserActivityLog
                {
                    UserId = userId,
                    EmailAtTime = email,
                    Activity = activity,
                    Detail = detail,
                    IpAddress = ResolveIp()
                });

                await _db.SaveChangesAsync(ct);
            }
            catch (Exception ex)
            {
                // An audit line is not worth failing a login over. It is worth
                // knowing that the audit trail has a hole in it, so this still
                // reaches the application log.
                _logger.LogWarning(ex,
                    "Could not record user activity {Activity} for {Email}",
                    activity, email);
            }
        }

        /// <summary>
        /// The deployed API sits behind a reverse proxy, so the socket address is
        /// the proxy's. `X-Forwarded-For` is the caller's real address when the
        /// proxy sets it — spoofable in general, which is why this is recorded as
        /// a hint for an investigation and never trusted for a decision.
        /// </summary>
        private string? ResolveIp()
        {
            var context = _http.HttpContext;
            if (context is null) return null;

            var forwarded = context.Request.Headers["X-Forwarded-For"].FirstOrDefault();
            if (!string.IsNullOrWhiteSpace(forwarded))
                return forwarded.Split(',')[0].Trim();

            return context.Connection.RemoteIpAddress?.ToString();
        }
    }
}
