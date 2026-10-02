using System.Security.AccessControl;
using System.Security.Principal;
using System.Text.Json;
using System.Text.Json.Nodes;
using Microsoft.Extensions.Configuration.Json;

namespace AimPark.API.Sync.Site.Setup
{
    /// <summary>
    /// The guard PC's own settings: database password, sign-in key, site key.
    /// Kept in <c>C:\ProgramData\AimPark\site-settings.json</c>, beside
    /// gate-readers.json, so installing a new version of the server replaces
    /// the program and never the settings.
    /// </summary>
    /// <remarks>
    /// Only read when the server runs with <c>--environment Site</c>, so a
    /// developer's cloud-mode API never picks up a guard PC's file. Written by
    /// the setup page (<see cref="SiteSetup"/>), never by hand.
    /// </remarks>
    public static class SiteSettingsFile
    {
        public const string EnvironmentName = "Site";

        public static readonly string Folder = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData), "AimPark");

        public static readonly string FilePath = Path.Combine(Folder, "site-settings.json");

        /// <summary>
        /// What a fresh guard PC starts from. Ranked above appsettings.json
        /// (which says Cloud) and below everything that can override it.
        /// </summary>
        private static Dictionary<string, string?> Defaults(string contentRoot) => new()
        {
            ["Site:Mode"] = nameof(SiteMode.Site),
            ["Site:CloudBaseUrl"] = "https://aimpark-api.onrender.com",
            ["Site:AdminWebPath"] = AdminWebDefault(contentRoot),
            ["ConnectionStrings:DefaultConnection"] =
                "Host=localhost;Port=5432;Database=AimParkSite;Username=postgres;Password=",
        };

        /// <summary>
        /// The installer puts the guard panel's web build next to the server.
        /// Run from the repo instead (<c>dotnet run</c>), it is the admin
        /// app's own <c>flutter build web</c> output.
        /// </summary>
        private static string AdminWebDefault(string contentRoot)
        {
            var installed = Path.Combine(AppContext.BaseDirectory, "admin-web");
            var repo = Path.GetFullPath(Path.Combine(contentRoot, "..", "..", "aimpark_admin", "build", "web"));
            return !Directory.Exists(installed) && Directory.Exists(repo) ? repo : installed;
        }

        /// <summary>
        /// Adds the defaults and the ProgramData file to configuration, in Site
        /// mode only. Order, lowest first: appsettings.json, the defaults,
        /// appsettings.Site.json (older setups), this file, then user secrets,
        /// environment variables and the command line as usual.
        /// </summary>
        public static void AddTo(WebApplicationBuilder builder)
        {
            if (!builder.Environment.IsEnvironment(EnvironmentName))
                return;

            var sources = builder.Configuration.Sources;
            var appsettings = sources
                .Select((s, i) => (Source: s as JsonConfigurationSource, Index: i))
                .Where(x => x.Source?.Path?.StartsWith("appsettings", StringComparison.OrdinalIgnoreCase) == true)
                .ToList();

            var file = new JsonConfigurationSource { Path = FilePath, Optional = true, ReloadOnChange = false };
            file.ResolveFileProvider();

            if (appsettings.Count == 0)
            {
                builder.Configuration.AddInMemoryCollection(Defaults(builder.Environment.ContentRootPath));
                builder.Configuration.Sources.Add(file);
                return;
            }

            // The later insert first, so the earlier index is still right.
            sources.Insert(appsettings[^1].Index + 1, file);
            sources.Insert(appsettings[0].Index + 1,
                new Microsoft.Extensions.Configuration.Memory.MemoryConfigurationSource { InitialData = Defaults(builder.Environment.ContentRootPath) });
        }

        /// <summary>
        /// Merges <paramref name="values"/> (keys like <c>Site:CloudApiKey</c>)
        /// into the file, keeping anything else already in it. Only SYSTEM,
        /// Administrators and the account saving it can read the result: it
        /// holds the database password and the key that signs logins.
        /// </summary>
        public static void Save(IReadOnlyDictionary<string, string> values)
        {
            Directory.CreateDirectory(Folder);

            var root = File.Exists(FilePath)
                ? JsonNode.Parse(File.ReadAllText(FilePath)) as JsonObject ?? new JsonObject()
                : new JsonObject();

            foreach (var (key, value) in values)
            {
                var parts = key.Split(':');
                var node = root;
                foreach (var part in parts[..^1])
                {
                    if (node[part] is not JsonObject child)
                        node[part] = child = new JsonObject();
                    node = child;
                }
                node[parts[^1]] = value;
            }

            var json = root.ToJsonString(new JsonSerializerOptions { WriteIndented = true });

            // Lock the file down before the secrets go into it, then swap it in.
            var temp = FilePath + ".tmp";
            File.WriteAllText(temp, string.Empty);
            Protect(temp);
            File.WriteAllText(temp, json);
            File.Move(temp, FilePath, overwrite: true);
        }

        private static void Protect(string path)
        {
            if (!OperatingSystem.IsWindows())
                return;

            var security = new FileSecurity();
            security.SetAccessRuleProtection(isProtected: true, preserveInheritance: false);

            var owners = new List<IdentityReference>
            {
                new SecurityIdentifier(WellKnownSidType.LocalSystemSid, null),
                new SecurityIdentifier(WellKnownSidType.BuiltinAdministratorsSid, null),
            };
            if (WindowsIdentity.GetCurrent().User is { } me)
                owners.Add(me);

            foreach (var who in owners)
                security.AddAccessRule(new FileSystemAccessRule(who, FileSystemRights.FullControl, AccessControlType.Allow));

            new FileInfo(path).SetAccessControl(security);
        }
    }
}
