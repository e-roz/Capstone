using AimPark.API.Data;
using AimPark.API.Entities;
using AimPark.API.Enums;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using BC = BCrypt.Net.BCrypt;

// Setup configuration
var configuration = new ConfigurationBuilder()
    .SetBasePath(Directory.GetCurrentDirectory())
    .AddJsonFile("appsettings.json", optional: false, reloadOnChange: true)
    .Build();

// Setup DI
var services = new ServiceCollection();
services.AddDbContext<AppDbContext>(options =>
    options.UseNpgsql(configuration.GetConnectionString("DefaultConnection")));

var serviceProvider = services.BuildServiceProvider();

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
    Console.WriteLine("2. Delete All Data");
    Console.WriteLine("3. Exit");
    Console.WriteLine();
    Console.Write("Enter your choice (1-3): ");

    var choice = Console.ReadLine();

    switch (choice)
    {
        case "1":
            await SeedAdmin(serviceProvider);
            break;
        case "2":
            await DeleteAllData(serviceProvider);
            break;
        case "3":
            Console.WriteLine("Exiting...");
            return;
        default:
            Console.WriteLine("Invalid choice. Please try again.");
            Console.ReadKey();
            break;
    }
}

async Task SeedAdmin(IServiceProvider sp)
{
    Console.Clear();
    try
    {
        using var context = sp.GetRequiredService<AppDbContext>();

        // Check if admin already exists
        var existingAdmin = await context.Users
            .FirstOrDefaultAsync(u => u.Email == "admin@gmail.com" && u.Role == UserRole.Admin);

        if (existingAdmin != null)
        {
            Console.WriteLine("❌ Admin user already exists with email: admin@gmail.com");
            Console.WriteLine("Press any key to continue...");
            Console.ReadKey();
            return;
        }

        // Create admin user
        var adminUser = new User
        {
            Id = Guid.NewGuid(),
            FullName = "Admin User",
            Email = "admin@gmail.com",
            IsEmailVerified = true,
            PhoneNumber = "+1234567890",
            IsPhoneVerified = true,
            PasswordHash = BC.HashPassword("admin123!"),
            AuthProvider = AuthProvider.Local,
            ExternalProviderId = null,
            Role = UserRole.Admin,
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

        context.Users.Add(adminUser);
        await context.SaveChangesAsync();

        Console.WriteLine("✅ Admin user seeded successfully!");
        Console.WriteLine($"   Email: admin@gmail.com");
        Console.WriteLine($"   Password: admin123!");
        Console.WriteLine($"   Role: Admin");
        Console.WriteLine();
        Console.WriteLine("Press any key to continue...");
        Console.ReadKey();
    }
    catch (Exception ex)
    {
        Console.WriteLine($"❌ Error seeding admin: {ex.Message}");
        Console.WriteLine($"   Inner Exception: {ex.InnerException?.Message}");
        Console.WriteLine();
        Console.WriteLine("Press any key to continue...");
        Console.ReadKey();
    }
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
        Console.WriteLine("Press any key to continue...");
        Console.ReadKey();
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
        Console.WriteLine("Press any key to continue...");
        Console.ReadKey();
    }
    catch (Exception ex)
    {
        Console.WriteLine($"❌ Error deleting data: {ex.Message}");
        Console.WriteLine($"   Inner Exception: {ex.InnerException?.Message}");
        Console.WriteLine();
        Console.WriteLine("Press any key to continue...");
        Console.ReadKey();
    }
}
