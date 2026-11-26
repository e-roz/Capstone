using Npgsql;

namespace AimPark.API.Data
{
    /// <summary>
    /// Keeps each copy of the API to a few database connections, so every copy
    /// together stays inside Supabase's limit.
    /// </summary>
    /// <remarks>
    /// Supabase's session pooler allows 15 connections in total, and in session
    /// mode an idle connection the API is keeping open still takes one of them.
    /// Npgsql's defaults (up to 100 per copy, idle ones kept for 5 minutes) let a
    /// single copy take all 15. Render, a developer's local API and, during a
    /// deploy, the old and new Render copies side by side all share the same 15,
    /// and the overflow surfaced as 500s with "EMAXCONNSESSION max clients
    /// reached" (Nov 5, 19, 25 and 26, 2026).
    ///
    /// Four per copy: 3 copies at once is 12, leaving room for a migration or the
    /// Supabase dashboard. A request that finds all four busy waits for one to
    /// come free (milliseconds) rather than failing.
    ///
    /// A database on this machine (the guard post's site server) has no such
    /// limit and is left exactly as configured. Either setting can be changed
    /// with Database:MaxPoolSize and Database:IdleSeconds.
    /// </remarks>
    public static class ConnectionLimits
    {
        public static string? Apply(string? connectionString, IConfiguration config)
        {
            if (string.IsNullOrWhiteSpace(connectionString)) return connectionString;

            var builder = new NpgsqlConnectionStringBuilder(connectionString);
            if (builder.Host is null or "localhost" or "127.0.0.1" or "::1") return connectionString;

            var idle = Math.Max(10, config.GetValue("Database:IdleSeconds", 30));
            builder.MaxPoolSize = Math.Max(1, config.GetValue("Database:MaxPoolSize", 4));
            builder.MinPoolSize = 0;
            builder.ConnectionIdleLifetime = idle;
            // How often idle connections are checked; must be shorter than the lifetime.
            builder.ConnectionPruningInterval = Math.Max(1, idle / 3);

            return builder.ConnectionString;
        }
    }
}
