using System.Net;
using System.Text.RegularExpressions;
using AimPark.API.Auth;
using Npgsql;

namespace AimPark.API.Sync.Site.Setup
{
    /// <summary>
    /// The first-time setup page. A guard PC that has no site key yet starts
    /// this instead of the server: one page at http://localhost:5041/ that asks
    /// for the database password, the site key and the sign-in key, checks each
    /// one, saves them to <see cref="SiteSettingsFile"/> and restarts.
    /// </summary>
    /// <remarks>
    /// It replaces editing appsettings.Site.json and creating the database in
    /// pgAdmin. The tables themselves are made when the real server starts
    /// (<see cref="SyncSetup.PrepareSiteDatabase"/>).
    ///
    /// Answers only on the PC itself: until setup is done there is no login
    /// to protect the page, so a browser elsewhere on the network gets a 403.
    /// </remarks>
    public static class SiteSetup
    {
        /// <summary>Site mode, and no site key from any settings source.</summary>
        public static bool IsNeeded(IConfiguration config)
        {
            var options = config.GetSection(SiteOptions.SectionName).Get<SiteOptions>() ?? new SiteOptions();
            return options.IsSite && string.IsNullOrWhiteSpace(options.CloudApiKey);
        }

        public static void Run(WebApplicationBuilder builder)
        {
            builder.Services.AddWindowsService(o => o.ServiceName = "AimParkSite");
            builder.Services.AddHttpClient(nameof(SiteSetup), c => c.Timeout = TimeSpan.FromSeconds(90));

            var app = builder.Build();
            var config = app.Configuration;
            var log = app.Logger;

            log.LogWarning("No site key yet. Serving the setup page: open this server's address in a browser on this PC.");

            app.Use(async (context, next) =>
            {
                var from = context.Connection.RemoteIpAddress;
                if (from is not null && !IPAddress.IsLoopback(from))
                {
                    context.Response.StatusCode = StatusCodes.Status403Forbidden;
                    await context.Response.WriteAsync(
                        "AimPark is not set up yet. Finish setup on the guard PC itself: http://localhost:5041/");
                    return;
                }
                await next();
            });

            // The installer and the setup page both poll this while waiting.
            app.MapGet("/api/site/status", () => Results.Ok(new { mode = "Setup", setupRequired = true }));

            app.MapGet("/setup/api/defaults", () =>
            {
                var db = new NpgsqlConnectionStringBuilder(config.GetConnectionString("DefaultConnection") ?? string.Empty);
                return Results.Ok(new
                {
                    dbHost = db.Host ?? "localhost",
                    dbPort = db.Port,
                    dbName = db.Database ?? "AimParkSite",
                    dbUser = db.Username ?? "postgres",
                    // The installer set PostgreSQL up and saved its password:
                    // the page skips that box. The password itself stays here.
                    dbPreset = !string.IsNullOrEmpty(db.Password),
                    cloudBaseUrl = config["Site:CloudBaseUrl"] ?? string.Empty,
                    jwtIssuer = config["Jwt:Issuer"] ?? "AimPark.API",
                    jwtAudience = config["Jwt:Audience"] ?? "AimPark.Client",
                });
            });

            app.MapPost("/setup/api/save", async (SetupRequest request, IHttpClientFactory http, IHostApplicationLifetime lifetime) =>
            {
                if (string.IsNullOrEmpty(request.DbPassword))
                {
                    var preset = new NpgsqlConnectionStringBuilder(config.GetConnectionString("DefaultConnection") ?? string.Empty);
                    request = request with { DbPassword = preset.Password ?? string.Empty };
                }

                var checks = new List<SetupCheck>
                {
                    await CheckDatabaseAsync(request),
                    await CheckCloudAsync(request, http.CreateClient(nameof(SiteSetup))),
                    CheckJwt(request),
                };

                if (checks.Any(c => !c.Ok))
                    return Results.Ok(new { ok = false, checks, restarting = false });

                SiteSettingsFile.Save(new Dictionary<string, string>
                {
                    ["ConnectionStrings:DefaultConnection"] = ConnectionString(request, request.DbName),
                    ["Jwt:Key"] = request.JwtKey.Trim(),
                    ["Jwt:Issuer"] = request.JwtIssuer.Trim(),
                    ["Jwt:Audience"] = request.JwtAudience.Trim(),
                    ["Site:Mode"] = nameof(SiteMode.Site),
                    ["Site:CloudBaseUrl"] = request.CloudBaseUrl.Trim().TrimEnd('/'),
                    ["Site:CloudApiKey"] = request.CloudApiKey.Trim(),
                });
                log.LogInformation("Setup saved to {Path}. Restarting.", SiteSettingsFile.FilePath);

                // As a service: end the process without reporting a stop, so
                // Windows treats it as a crash and starts it again in 5 seconds
                // (install-service.ps1 sets that up). Started by hand: just stop.
                var asService = Microsoft.Extensions.Hosting.WindowsServices.WindowsServiceHelpers.IsWindowsService();
                _ = Task.Run(async () =>
                {
                    await Task.Delay(TimeSpan.FromSeconds(1));
                    if (asService)
                        Environment.Exit(1);
                    else
                        lifetime.StopApplication();
                });

                return Results.Ok(new { ok = true, checks, restarting = asService });
            });

            app.MapFallback(() => Results.Content(SetupPage.Html, "text/html; charset=utf-8"));

            app.Run();
        }

        private static readonly Regex SafeName = new("^[A-Za-z0-9_]{1,63}$", RegexOptions.Compiled);

        private static string ConnectionString(SetupRequest r, string database) => new NpgsqlConnectionStringBuilder
        {
            Host = r.DbHost.Trim(),
            Port = r.DbPort,
            Database = database,
            Username = r.DbUser.Trim(),
            Password = r.DbPassword,
        }.ConnectionString;

        /// <summary>Signs in to PostgreSQL, and makes the database if it isn't there yet.</summary>
        private static async Task<SetupCheck> CheckDatabaseAsync(SetupRequest r)
        {
            const string name = "Database";

            if (r.DbName is null || !SafeName.IsMatch(r.DbName))
                return new(name, false, "The database name may only use letters, numbers and _.");

            try
            {
                await using var conn = new NpgsqlConnection(ConnectionString(r, "postgres"));
                await conn.OpenAsync();

                await using var exists = new NpgsqlCommand("SELECT 1 FROM pg_database WHERE datname = @n", conn);
                exists.Parameters.AddWithValue("n", r.DbName);
                if (await exists.ExecuteScalarAsync() is not null)
                    return new(name, true, $"Connected. Using the existing database \"{r.DbName}\".");

                // Checked against SafeName above, so it can go in the statement as is.
                await using var create = new NpgsqlCommand($"CREATE DATABASE \"{r.DbName}\"", conn);
                await create.ExecuteNonQueryAsync();
                return new(name, true, $"Connected. Created the database \"{r.DbName}\".");
            }
            catch (PostgresException e) when (e.SqlState == PostgresErrorCodes.InvalidPassword)
            {
                return new(name, false, "Wrong password for the PostgreSQL user.");
            }
            catch (Exception e) when (e is NpgsqlException or System.Net.Sockets.SocketException or TimeoutException)
            {
                return new(name, false, $"Can't reach PostgreSQL at {r.DbHost}:{r.DbPort}. Is it installed and running? ({e.Message})");
            }
        }

        /// <summary>Asks the cloud whether the key belongs to a Site Server.</summary>
        private static async Task<SetupCheck> CheckCloudAsync(SetupRequest r, HttpClient client)
        {
            const string name = "Site key";

            if (string.IsNullOrWhiteSpace(r.CloudApiKey) || r.CloudBaseUrl is null)
                return new(name, false, "Paste the Site Server key from the online admin panel.");

            if (!Uri.TryCreate(r.CloudBaseUrl.Trim().TrimEnd('/') + "/", UriKind.Absolute, out var cloud))
                return new(name, false, "The cloud address isn't a web address.");

            try
            {
                using var request = new HttpRequestMessage(HttpMethod.Get, new Uri(cloud, "api/site-sync/snapshot"));
                request.Headers.Add(ApiKeyDefaults.HeaderName, r.CloudApiKey.Trim());
                using var response = await client.SendAsync(request, HttpCompletionOption.ResponseHeadersRead);

                return response.StatusCode switch
                {
                    HttpStatusCode.OK => new(name, true, "The cloud accepted the key."),
                    HttpStatusCode.Unauthorized => new(name, false, "The cloud doesn't know this key. It may be mistyped or revoked: make a new one in Gate Devices."),
                    HttpStatusCode.Forbidden => new(name, false, "This key isn't a Site Server key. Register a device of type Site Server and use its key."),
                    var code => new(name, false, $"The cloud answered {(int)code}. Try again in a minute."),
                };
            }
            catch (Exception e) when (e is HttpRequestException or TaskCanceledException)
            {
                return new(name, false, "Can't reach the cloud. Check this PC's internet. The free server can take a minute to wake up, so try again.");
            }
        }

        private static SetupCheck CheckJwt(SetupRequest r)
        {
            const string name = "Sign-in key";

            if (string.IsNullOrWhiteSpace(r.JwtKey))
                return new(name, false, "Paste Jwt__Key from Render's Environment settings.");
            // HS256 needs at least 256 bits, and the cloud's key already has them.
            if (System.Text.Encoding.UTF8.GetByteCount(r.JwtKey.Trim()) < 32)
                return new(name, false, "That's too short to be the cloud's key. Copy the whole value.");
            if (string.IsNullOrWhiteSpace(r.JwtIssuer) || string.IsNullOrWhiteSpace(r.JwtAudience))
                return new(name, false, "Issuer and audience can't be empty.");

            return new(name, true, "Looks right. It must match the cloud exactly, or the Notifications screen won't work.");
        }

        public record SetupRequest(
            string DbHost, int DbPort, string DbName, string DbUser, string DbPassword,
            string CloudBaseUrl, string CloudApiKey,
            string JwtKey, string JwtIssuer, string JwtAudience);

        public record SetupCheck(string Name, bool Ok, string Message);
    }
}
