namespace AimPark.API.Sync.Cloud
{
    /// <summary>
    /// Once the site server is live, stops the cloud taking gate traffic
    /// itself. Off until <c>Site:CloudGateEndpointsEnabled</c> is set false.
    /// </summary>
    /// <remarks>
    /// Two places deciding who is in the lot would disagree: a reader still
    /// aimed at the cloud would open a session the site has never heard of,
    /// and the car could not get out at a gate the site runs.
    /// </remarks>
    public class CloudGateLock
    {
        private static readonly string[] GatePaths =
        [
            "/api/admin/parking/log-entry",
            "/api/admin/parking/log-exit",
            "/api/gate/alpr-readings",
        ];

        private readonly RequestDelegate _next;

        public CloudGateLock(RequestDelegate next)
        {
            _next = next;
        }

        public async Task InvokeAsync(HttpContext context)
        {
            var path = context.Request.Path;

            var isGate = GatePaths.Any(p => path.Equals(p, StringComparison.OrdinalIgnoreCase)) ||
                         // Reviewing a flagged attempt belongs where the attempt was made.
                         (path.StartsWithSegments("/api/security/gate-access-attempts") &&
                          HttpMethods.IsPost(context.Request.Method));

            if (!isGate)
            {
                await _next(context);
                return;
            }

            context.Response.StatusCode = StatusCodes.Status409Conflict;
            await context.Response.WriteAsJsonAsync(new
            {
                message = "Gate entry and exit now run on the guard post's server. Point this device or screen at it instead of the cloud."
            });
        }
    }
}
