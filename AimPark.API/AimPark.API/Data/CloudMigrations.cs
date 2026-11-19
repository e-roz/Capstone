using AimPark.API.Sync;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using Microsoft.EntityFrameworkCore.Migrations.Operations;

namespace AimPark.API.Data
{
    /// <summary>
    /// The cloud API brings Supabase up to this version's migrations when it
    /// starts, but only the ones that add things.
    /// </summary>
    /// <remarks>
    /// Before this, the cloud never migrated: a merged migration put new code
    /// on the old schema until someone ran <c>dotnet ef database update</c> by
    /// hand, and every request touching the new columns failed meanwhile.
    ///
    /// The database is shared and holds real records, so a migration that
    /// drops, renames or alters a column or table, or runs raw SQL, is never
    /// applied here. Migrations run in order, so everything from that one on
    /// waits; the API still starts and logs which one needs a person.
    ///
    /// Never in Development: a developer pointing a local build at the real
    /// database (TROUBLESHOOTING.md §7) must not push their branch's
    /// migrations into it. Set <c>Database:MigrateOnStartup</c> to false to
    /// turn it off without a deploy.
    /// </remarks>
    public static class CloudMigrations
    {
        private static readonly HashSet<Type> Unsafe =
        [
            typeof(DropTableOperation),
            typeof(DropColumnOperation),
            typeof(RenameTableOperation),
            typeof(RenameColumnOperation),
            typeof(AlterColumnOperation),
            typeof(SqlOperation),
        ];

        /// <summary>What in a migration's Up would change or lose existing data, e.g. "DropColumn".</summary>
        public static IReadOnlyList<string> UnsafeOperations(Migration migration) =>
            migration.UpOperations
                .Select(op => op.GetType())
                .Where(Unsafe.Contains)
                .Select(t => t.Name.Replace("Operation", string.Empty))
                .Distinct()
                .ToList();

        /// <summary>
        /// How far it is safe to go: the last pending migration before the
        /// first unsafe one (null when the first is already unsafe), and that
        /// unsafe one with its reasons.
        /// </summary>
        public static (string? Target, string? Blocked, IReadOnlyList<string> Reasons) Plan(
            IReadOnlyList<string> pending, Func<string, Migration> load)
        {
            string? target = null;
            foreach (var id in pending)
            {
                var reasons = UnsafeOperations(load(id));
                if (reasons.Count > 0)
                    return (target, id, reasons);
                target = id;
            }
            return (target, null, []);
        }

        public static void ApplyCloudMigrations(this WebApplication app, SiteOptions options)
        {
            if (options.IsSite || app.Environment.IsDevelopment())
                return;
            if (!app.Configuration.GetValue("Database:MigrateOnStartup", true))
                return;

            var log = app.Logger;
            try
            {
                using var scope = app.Services.CreateScope();
                var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();

                var pending = db.Database.GetPendingMigrations().ToList();
                if (pending.Count == 0)
                {
                    log.LogInformation("Cloud database is up to date.");
                    return;
                }

                var assembly = db.GetService<IMigrationsAssembly>();
                var provider = db.Database.ProviderName!;
                Migration Load(string id) => assembly.CreateMigration(assembly.Migrations[id], provider);

                var (target, blocked, reasons) = Plan(pending, Load);

                if (target is not null)
                {
                    var applying = pending.TakeWhile(id => id != blocked).ToList();
                    log.LogInformation("Applying {Count} migration(s) to the cloud database: {Ids}",
                        applying.Count, string.Join(", ", applying));
                    db.GetService<IMigrator>().Migrate(target);
                    log.LogInformation("Cloud database migrated to {Target}.", target);
                }

                if (blocked is not null)
                {
                    log.LogError(
                        "Migration {Id} was NOT applied: it uses {Reasons}, which can change or lose existing data. " +
                        "It and any later migrations wait. Apply them by hand: " +
                        "dotnet ef database update --connection \"<cloud connection string>\" (see MD files/TROUBLESHOOTING.md).",
                        blocked, string.Join(", ", reasons));
                }
            }
            catch (Exception e)
            {
                // A failed migration must not keep the API down: most requests
                // still work on the old schema. The log says what to fix.
                log.LogError(e, "Cloud database migration failed at startup. The API is starting anyway.");
            }
        }
    }
}
