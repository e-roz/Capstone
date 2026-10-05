using AimPark.API.Auth;
using AimPark.API.Enums;
using AimPark.API.Sync.Cloud;
using AimPark.API.Sync.Site;
using AimPark.API.Sync.Site.Cameras;
using AimPark.API.Sync.Site.GateReaders;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
using Microsoft.Extensions.FileProviders;

namespace AimPark.API.Sync
{
    /// <summary>
    /// Everything that differs between the cloud and the site server, in one
    /// place. Program.cs calls these four and otherwise does not care which
    /// one it is.
    /// </summary>
    public static class SyncSetup
    {
        public static SiteOptions AddAimParkSync(this WebApplicationBuilder builder)
        {
            var section = builder.Configuration.GetSection(SiteOptions.SectionName);
            var options = section.Get<SiteOptions>() ?? new SiteOptions();
            var services = builder.Services;

            services.Configure<SiteOptions>(section);
            services.AddScoped<SyncSuppression>();
            services.AddSingleton<GuardPostSignIn>();
            // Filled only on the cloud, but registered on both so the sync
            // controller and hub resolve wherever they are mapped.
            services.AddSingleton<SiteLinkState>();

            services.AddAuthorization(o => o.AddPolicy(SitePolicies.SiteServer, p => p
                .RequireRole(ApiKeyDefaults.DeviceRole)
                .RequireClaim(ApiKeyDefaults.DeviceTypeClaim, nameof(GateDeviceType.SiteServer))));

            if (options.IsSite)
                AddSite(services, options);
            else
                AddCloud(services);

            return options;
        }

        private static void AddSite(IServiceCollection services, SiteOptions options)
        {
            if (string.IsNullOrWhiteSpace(options.CloudBaseUrl) || string.IsNullOrWhiteSpace(options.CloudApiKey))
                throw new InvalidOperationException(
                    "Site mode needs Site:CloudBaseUrl and Site:CloudApiKey. See MD files/SITE_SERVER.md.");

            var cloud = new Uri(options.CloudBaseUrl.TrimEnd('/') + "/");

            // The site's own calls: sync, signed with the site's key.
            services.AddHttpClient(SiteOutboxPusher.CloudClient, c =>
            {
                c.BaseAddress = cloud;
                c.Timeout = TimeSpan.FromSeconds(30);
                c.DefaultRequestHeaders.Add(ApiKeyDefaults.HeaderName, options.CloudApiKey);
            });

            // Somebody else's calls passed through — carries their own
            // credentials and never the site's key.
            services.AddHttpClient(CloudForwarder.ForwardClient, c =>
                {
                    c.BaseAddress = cloud;
                    c.Timeout = TimeSpan.FromSeconds(100);
                })
                .ConfigurePrimaryHttpMessageHandler(() => new HttpClientHandler
                {
                    AllowAutoRedirect = false,
                    UseCookies = false
                });

            services.AddSingleton<OutboxSignal>();
            services.AddSingleton<SnapshotSignal>();
            services.AddSingleton<SiteSyncStatus>();
            services.AddScoped<ISaveChangesInterceptor, SiteOutboxInterceptor>();
            services.AddScoped<SnapshotApplier>();
            services.AddHostedService<SiteOutboxPusher>();
            services.AddHostedService<SiteMasterDataSync>();
            services.AddScoped<DeviceHealthReport>();
            services.AddHostedService<SiteHealthPusher>();

            // Barrier readers plugged into this PC by USB. One instance, since
            // the Gate Readers screen reads and changes the same connections
            // the background loop holds open.
            services.AddScoped<GateTapHandler>();
            services.AddScoped<GateTapRecorder>();
            services.AddSingleton<PendingVisitorRegistrations>();
            services.AddSingleton<CameraFrames>();
            services.AddHostedService(sp => sp.GetRequiredService<CameraFrames>());
            services.AddSingleton<UsbGateReaders>();
            services.AddHostedService(sp => sp.GetRequiredService<UsbGateReaders>());

            // The ESP-NOW hub: wireless gates and slot sensors behind one USB
            // cable. Answers gate taps through the readers above.
            services.AddSingleton<EspNowHubs>();
            services.AddHostedService(sp => sp.GetRequiredService<EspNowHubs>());
            services.AddSingleton<AimPark.API.Interfaces.ISlotSensors>(sp => sp.GetRequiredService<EspNowHubs>());

            // Keeps this PC on the newest release, installed when the gates are quiet.
            services.AddHttpClient(Site.Updates.SiteUpdater.HttpClientName, c =>
            {
                c.Timeout = TimeSpan.FromMinutes(15);
                c.DefaultRequestHeaders.UserAgent.ParseAdd("AimPark-SiteServer");
                c.DefaultRequestHeaders.Accept.ParseAdd("application/vnd.github+json");
            });
            services.AddSingleton<Site.Updates.UpdateSignal>();
            services.AddSingleton<Site.Updates.SiteUpdateStatus>();
            services.AddHostedService<Site.Updates.SiteUpdater>();
        }

        private static void AddCloud(IServiceCollection services)
        {
            services.AddSingleton<AimPark.API.Interfaces.ISlotSensors, AimPark.API.Interfaces.NoSlotSensors>();
            services.AddSignalR();
            services.AddSingleton<MasterDataChangeNotifier>();
            services.AddSingleton<SentPushLedger>();
            // Clock-driven pushes: due tomorrow, overdue, suspension start/end.
            services.AddHostedService<AimPark.API.Services.NotificationReminderService>();
            // Issued violations past their appeal deadline become Accountable.
            services.AddHostedService<AimPark.API.Services.ViolationDeadlineService>();
            services.AddScoped<ISaveChangesInterceptor, MasterDataChangeInterceptor>();
            services.AddScoped<SnapshotBuilder>();
            services.AddScoped<EventIngestor>();
        }

        /// <summary>
        /// Site: brings the local database up to date with this version's
        /// migrations, so neither a first install nor an update needs
        /// <c>dotnet ef</c>. The cloud's migrations stay a deliberate, manual
        /// step, since that database is shared.
        /// </summary>
        /// <remarks>
        /// Waits for PostgreSQL rather than failing: after a power cut both
        /// services start together, and the database is usually the slower.
        /// </remarks>
        public static void PrepareSiteDatabase(this WebApplication app, SiteOptions options)
        {
            if (!options.IsSite)
                return;

            var log = app.Logger;
            for (var attempt = 1; ; attempt++)
            {
                try
                {
                    using var scope = app.Services.CreateScope();
                    var db = scope.ServiceProvider.GetRequiredService<AimPark.API.Data.AppDbContext>();
                    var pending = db.Database.GetPendingMigrations().ToList();
                    if (pending.Count > 0)
                    {
                        log.LogInformation("Updating the local database: {Count} migration(s).", pending.Count);
                        db.Database.Migrate();
                    }
                    return;
                }
                // A wrong password won't fix itself: fail at once with that.
                catch (Exception e) when (attempt < 30
                    && e is not Npgsql.PostgresException { SqlState: Npgsql.PostgresErrorCodes.InvalidPassword }
                    && e is Npgsql.NpgsqlException or System.Net.Sockets.SocketException
                        or InvalidOperationException { InnerException: Npgsql.NpgsqlException })
                {
                    log.LogWarning("The local database isn't answering yet ({Message}). Retrying.", e.Message);
                    Thread.Sleep(TimeSpan.FromSeconds(2));
                }
            }
        }

        /// <summary>Before authentication: decides where a request is answered.</summary>
        public static void UseAimParkSyncRouting(this WebApplication app, SiteOptions options)
        {
            if (options.IsSite)
            {
                app.UseMiddleware<CloudForwarder>();

                if (AdminWeb(options) is { } files)
                {
                    app.UseDefaultFiles(new DefaultFilesOptions { FileProvider = files });
                    // Re-checked on every load (an unchanged file is a cheap
                    // 304), so the panel is the new one right after an update.
                    app.UseStaticFiles(new StaticFileOptions
                    {
                        FileProvider = files,
                        OnPrepareResponse = c => c.Context.Response.Headers.CacheControl = "no-cache"
                    });
                }
            }
            else if (!options.CloudGateEndpointsEnabled)
            {
                app.UseMiddleware<CloudGateLock>();
            }
        }

        public static void MapAimParkSync(this WebApplication app, SiteOptions options)
        {
            if (options.IsCloud)
            {
                app.MapHub<SiteSyncHub>(SiteSyncHub.Path);
            }
            else if (AdminWeb(options) is { } files)
            {
                // The admin panel is a single-page app: any path that is not a
                // file or an API route is one of its screens.
                app.MapFallbackToFile("index.html", new StaticFileOptions { FileProvider = files });
            }
        }

        private static PhysicalFileProvider? AdminWeb(SiteOptions options)
        {
            if (string.IsNullOrWhiteSpace(options.AdminWebPath))
                return null;

            var path = Path.GetFullPath(options.AdminWebPath);
            return Directory.Exists(path) ? new PhysicalFileProvider(path) : null;
        }
    }
}
