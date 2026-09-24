namespace AimPark.API.Sync.Site
{
    /// <summary>
    /// On the site server, decides whether a request is gate work — answered
    /// here, internet or not — or everything else, which is passed through to
    /// the cloud unchanged.
    /// </summary>
    /// <remarks>
    /// This is what lets the guard post run the one admin panel it already
    /// knows. Its gate screens and the incident queue hit this server; its
    /// notifications and the rest go on to the cloud, and simply fail with a
    /// clear message while the internet is down.
    ///
    /// A token issued here is accepted by the cloud because both are
    /// configured with the same JWT key, issuer and audience, and the user ids
    /// are the same on both sides.
    /// </remarks>
    public class CloudForwarder
    {
        public const string ForwardClient = "AimParkCloudForward";

        /// <summary>Answered by this server. Everything else under /api goes to the cloud.</summary>
        private static readonly (string Method, string Path, bool Prefix)[] LocalRoutes =
        [
            ("POST", "/api/auth/login", false),
            ("*", "/api/gate", true),
            ("*", "/api/security", true),
            ("*", "/api/site", true),
            ("POST", "/api/admin/parking/log-entry", false),
            ("POST", "/api/admin/parking/log-exit", false),
            ("GET", "/api/admin/parking/active-sessions", false),
            ("GET", "/api/admin/parking/slots", false),
            ("GET", "/api/admin/logs/rfid-access", false),
            // Security reports and follows up incidents from the guard post.
            // Kept in step with the cloud both ways — see SnapshotApplier and
            // SiteOutboxInterceptor.
            ("*", "/api/incidents", true),
            ("*", "/api/admin/incidents", true),
        ];

        // Connection-level headers belong to one hop, not the whole trip.
        private static readonly HashSet<string> HopByHop = new(StringComparer.OrdinalIgnoreCase)
        {
            "Host", "Connection", "Keep-Alive", "Transfer-Encoding", "Upgrade",
            "Proxy-Connection", "Proxy-Authenticate", "Proxy-Authorization", "TE", "Trailer"
        };

        private readonly RequestDelegate _next;
        private readonly IHttpClientFactory _http;
        private readonly ILogger<CloudForwarder> _logger;

        public CloudForwarder(RequestDelegate next, IHttpClientFactory http, ILogger<CloudForwarder> logger)
        {
            _next = next;
            _http = http;
            _logger = logger;
        }

        public async Task InvokeAsync(HttpContext context)
        {
            var path = context.Request.Path;

            if (!path.StartsWithSegments("/api") || IsLocal(context.Request.Method, path))
            {
                await _next(context);
                return;
            }

            await ForwardAsync(context);
        }

        private static bool IsLocal(string method, PathString path)
        {
            foreach (var (routeMethod, routePath, prefix) in LocalRoutes)
            {
                if (routeMethod != "*" && !string.Equals(routeMethod, method, StringComparison.OrdinalIgnoreCase))
                    continue;

                if (prefix ? path.StartsWithSegments(routePath) : path.Equals(routePath, StringComparison.OrdinalIgnoreCase))
                    return true;
            }

            return false;
        }

        private async Task ForwardAsync(HttpContext context)
        {
            var request = context.Request;
            var client = _http.CreateClient(ForwardClient);

            using var outgoing = new HttpRequestMessage(
                new HttpMethod(request.Method),
                request.Path.Value!.TrimStart('/') + request.QueryString);

            if (request.ContentLength > 0 || request.Headers.ContainsKey("Transfer-Encoding"))
                outgoing.Content = new StreamContent(request.Body);

            foreach (var header in request.Headers)
            {
                if (HopByHop.Contains(header.Key))
                    continue;

                if (!outgoing.Headers.TryAddWithoutValidation(header.Key, header.Value.ToArray()))
                    outgoing.Content?.Headers.TryAddWithoutValidation(header.Key, header.Value.ToArray());
            }

            HttpResponseMessage response;
            try
            {
                response = await client.SendAsync(outgoing, HttpCompletionOption.ResponseHeadersRead, context.RequestAborted);
            }
            catch (Exception ex) when (ex is HttpRequestException or TaskCanceledException && !context.RequestAborted.IsCancellationRequested)
            {
                _logger.LogWarning("Could not forward {Method} {Path} to the cloud: {Error}", request.Method, request.Path, ex.Message);

                context.Response.StatusCode = StatusCodes.Status503ServiceUnavailable;
                await context.Response.WriteAsJsonAsync(new
                {
                    message = "This needs the internet, and the guard post can't reach the cloud right now. Gate entry and exit still work."
                });
                return;
            }

            using (response)
            {
                context.Response.StatusCode = (int)response.StatusCode;

                foreach (var header in response.Headers.Concat(response.Content.Headers))
                {
                    if (!HopByHop.Contains(header.Key))
                        context.Response.Headers[header.Key] = header.Value.ToArray();
                }

                await response.Content.CopyToAsync(context.Response.Body, context.RequestAborted);
            }
        }
    }
}
