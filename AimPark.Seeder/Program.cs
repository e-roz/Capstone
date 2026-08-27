using AimPark.API.Data;
using AimPark.API.Entities;
using AimPark.API.Enums;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using BC = BCrypt.Net.BCrypt;

// Setup configuration
// Same sources as the API, in the same order, so the seeder can never end up
// writing to a different database than the one the app reads. appsettings.json
// alone pointed at a local Postgres while the API ran on Supabase out of user
// secrets - and a seeded account that lands in the wrong database looks exactly
// like a seeder that silently did nothing.
var configuration = new ConfigurationBuilder()
    .SetBasePath(Directory.GetCurrentDirectory())
    .AddJsonFile("appsettings.json", optional: false, reloadOnChange: true)
    .AddUserSecrets(typeof(AppDbContext).Assembly, optional: true)
    .AddEnvironmentVariables()
    .Build();

// Setup DI
var services = new ServiceCollection();
services.AddDbContext<AppDbContext>(options =>
    options.UseNpgsql(configuration.GetConnectionString("DefaultConnection")));

var serviceProvider = services.BuildServiceProvider();

// Non-interactive mode: `dotnet run -- security` seeds and exits.
//
// The menu needs a keypress, which means it cannot be driven from a script, a
// CI step, or by anyone whose terminal is not attached to it. Seeding a staff
// account is one of the first things done on a fresh database and should not
// require a human sitting in front of the console.
if (args.Length > 0)
{
    var target = args[0].Trim().ToLowerInvariant();

    switch (target)
    {
        case "admin":
            await SeedStaff(serviceProvider, UserRole.Admin, "admin@gmail.com", "admin123!", "Admin User");
            return;
        case "security":
            await SeedStaff(serviceProvider, UserRole.Security, "security@gmail.com", "security123!", "Security Guard");
            return;
        default:
            Console.WriteLine($"Unknown argument '{args[0]}'. Use 'admin' or 'security', or pass nothing for the menu.");
            return;
    }
}

// Menu loop
while (true)
{
    Console.Clear();
    Console.WriteLine("================================");
    Console.WriteLine("  AimPark Database Seeder");
    Console.WriteLine("================================");
    Console.WriteLine();
    Console.WriteLine("Choose an option:");
    Console.WriteLine("1. Seed Admin Credentials");
    Console.WriteLine("2. Seed Security Credentials");
    Console.WriteLine("3. Delete All Data");
    Console.WriteLine("4. Exit");
    Console.WriteLine();
    Console.Write("Enter your choice (1-4): ");

    var choice = Console.ReadLine();

    switch (choice)
    {
        case "1":
            await SeedStaff(serviceProvider, UserRole.Admin, "admin@gmail.com", "admin123!", "Admin User");
            break;
        case "2":
            await SeedStaff(serviceProvider, UserRole.Security, "security@gmail.com", "security123!", "Security Guard");
            break;
        case "3":
            await DeleteAllData(serviceProvider);
            break;
        case "4":
            Console.WriteLine("Exiting...");
            return;
        default:
            Console.WriteLine("Invalid choice. Please try again.");
            Console.ReadKey();
            break;
    }
}

// One method for both staff roles rather than a copy per role. An Admin and a
// Security account differ by exactly three values - role, email, password - and
// everything else about them is the same: a pre-approved, pre-verified account
// that skips the whole registration flow because there is nothing to verify
// about a member of staff the school employed directly.
async Task SeedStaff(
    IServiceProvider sp, UserRole role, string email, string password, string fullName)
{
    ClearScreen();
    try
    {
        using var context = sp.GetRequiredService<AppDbContext>();

        var existing = await context.Users
            .FirstOrDefaultAsync(u => u.Email == email);

        if (existing != null)
        {
            // Not skipped silently. Somebody seeding a second time is almost
            // always doing it because they cannot get in, and being told the
            // row is there while the password stays a mystery is the least
            // useful answer available.
            Console.WriteLine($"⚠️  An account already uses {email} (role: {existing.Role}).");
            Console.WriteLine();
            Console.Write("Reset its password and role to the seed values? (y/N): ");

            // Nobody is there to answer in non-interactive mode, and the
            // explicit `-- security` is answer enough.
            var confirmed = Console.IsInputRedirected
                || string.Equals(Console.ReadLine()?.Trim(), "y", StringComparison.OrdinalIgnoreCase);

            if (!confirmed)
            {
                Console.WriteLine("❌ Left as it was.");
                Pause();
                return;
            }

            existing.PasswordHash = BC.HashPassword(password);
            existing.Role = role;
            existing.AccountStatus = AccountStatus.Active;
            existing.RegistrationStep = RegistrationStep.Completed;
            existing.IsDeleted = false;
            existing.DeletedAt = null;
            existing.UpdatedAt = DateTime.UtcNow;

            await context.SaveChangesAsync();

            Console.WriteLine();
            Console.WriteLine($"✅ {role} account reset.");
            PrintCredentials(email, password, role);
            return;
        }

        var user = new User
        {
            Id = Guid.NewGuid(),
            FullName = fullName,
            Email = email,
            IsEmailVerified = true,
            PasswordHash = BC.HashPassword(password),
            AuthProvider = AuthProvider.Local,
            ExternalProviderId = null,
            Role = role,
            // Staff skip registration entirely: there are no documents to
            // photograph and nobody to approve them.
            RegistrationStep = RegistrationStep.Completed,
            AccountStatus = AccountStatus.Active,
            VerificationStatus = VerificationStatus.Passed,
            RejectionReason = null,
            RejectedAt = null,
            RejectionCount = 0,
            CanReapplyAt = null,
            IsFirstLogin = false,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow,
            IsDeleted = false,
            DeletedAt = null
        };

        context.Users.Add(user);
        await context.SaveChangesAsync();

        Console.WriteLine($"✅ {role} user seeded successfully!");
        PrintCredentials(email, password, role);
    }
    catch (Exception ex)
    {
        Console.WriteLine($"❌ Error seeding {role}: {ex.Message}");
        Console.WriteLine($"   Inner Exception: {ex.InnerException?.Message}");
        Console.WriteLine();
        Pause();
    }
}

void PrintCredentials(string email, string password, UserRole role)
{
    Console.WriteLine($"   Email: {email}");
    Console.WriteLine($"   Password: {password}");
    Console.WriteLine($"   Role: {role}");
    Console.WriteLine();
    Console.WriteLine(role == UserRole.Security
        ? "   Sign in at the web panel. The mobile app is for drivers."
        : "   Sign in at the web panel.");
    Console.WriteLine();
    Pause();
}

// Console.ReadKey throws outright when stdin is redirected, which would turn a
// successful seed into a crash *after* the row was written - the worst of both.
// Console.Clear() throws "The handle is invalid" when there is no real console
// behind stdout - a piped run, or a CI log. Wiping the screen is a convenience
// for the menu and nothing more, so it is skipped rather than fatal.
void ClearScreen()
{
    if (Console.IsOutputRedirected || Console.IsInputRedirected) return;

    Console.Clear();
}

void Pause()
{
    if (Console.IsInputRedirected) return;

    Pause();
}

async Task DeleteAllData(IServiceProvider sp)
{
    Console.Clear();
    Console.WriteLine("⚠️  WARNING: This will delete ALL data from the database!");
    Console.WriteLine();
    Console.Write("Type 'DELETE' to confirm: ");

    var confirmation = Console.ReadLine();

    if (confirmation != "DELETE")
    {
        Console.WriteLine("❌ Operation cancelled.");
        Pause();
        return;
    }

    try
    {
        using var context = sp.GetRequiredService<AppDbContext>();

        // Delete in correct order (respect foreign keys)
        await context.Database.ExecuteSqlRawAsync("TRUNCATE TABLE \"AdminAuditLogs\" CASCADE");
        await context.Database.ExecuteSqlRawAsync("TRUNCATE TABLE \"Documents\" CASCADE");
        await context.Database.ExecuteSqlRawAsync("TRUNCATE TABLE \"vehicles\" CASCADE");
        await context.Database.ExecuteSqlRawAsync("TRUNCATE TABLE \"RegistrationSessions\" CASCADE");
        await context.Database.ExecuteSqlRawAsync("TRUNCATE TABLE \"Users\" CASCADE");

        Console.WriteLine("✅ All data deleted successfully!");
        Console.WriteLine();
        Pause();
    }
    catch (Exception ex)
    {
        Console.WriteLine($"❌ Error deleting data: {ex.Message}");
        Console.WriteLine($"   Inner Exception: {ex.InnerException?.Message}");
        Console.WriteLine();
        Pause();
    }
}
