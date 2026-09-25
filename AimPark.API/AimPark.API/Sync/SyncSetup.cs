using AimPark.API.Auth;
using AimPark.API.Enums;
using AimPark.API.Sync.Cloud;
using AimPark.API.Sync.Site;
using AimPark.API.Sync.Site.GateReaders;
using Microsoft.EntityFrameworkCore.Diagnostics;
using Microsoft.Extensions.FileProviders;

namespace AimPark.API.Sync
{
    /// <summary>
    /// Everything that differs between the cloud and the site server, in one
    /// place. Program.cs calls these three and otherwise does not care which
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
                    "Site mode needs Site:CloudBaseUrl and Site:CloudApiKey. See SITE_SERVER.md.");

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

            // Barrier readers plugged into this PC by USB. One instance, since
            // the Gate Readers screen reads and changes the same connections
            // the background loop holds open.
            services.AddScoped<GateTapHandler>();
            services.AddSingleton<UsbGateReaders>();
            services.AddHostedService(sp => sp.GetRequiredService<UsbGateReaders>());
        }

        private static void AddCloud(IServiceCollection services)
        {
            services.AddSignalR();
            services.AddSingleton<MasterDataChangeNotifier>();
            services.AddSingleton<SentPushLedger>();
            services.AddScoped<ISaveChangesInterceptor, MasterDataChangeInterceptor>();
            services.AddScoped<SnapshotBuilder>();
            services.AddScoped<EventIngestor>();
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
                    app.UseStaticFiles(new StaticFileOptions { FileProvider = files });
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
