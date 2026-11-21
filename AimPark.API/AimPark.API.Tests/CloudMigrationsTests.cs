using AimPark.API.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

namespace AimPark.API.Tests;

/// <summary>
/// The cloud applies only additive migrations at startup. Checked against the
/// project's real migrations, read the same way the API reads them. No
/// database is touched: the connection is never opened.
/// </summary>
public class CloudMigrationsTests
{
    private static readonly (IMigrationsAssembly Assembly, string Provider) Migrations = Load();

    private static (IMigrationsAssembly, string) Load()
    {
        var db = new AppDbContext(new DbContextOptionsBuilder<AppDbContext>()
            .UseNpgsql("Host=unused;Database=unused")
            .Options);
        return (db.GetService<IMigrationsAssembly>(), db.Database.ProviderName!);
    }

    private static Migration Get(string id) =>
        Migrations.Assembly.CreateMigration(Migrations.Assembly.Migrations[id], Migrations.Provider);

    private static string Id(string name) =>
        Migrations.Assembly.Migrations.Keys.Single(k => k.EndsWith("_" + name));

    [Theory]
    [InlineData("AddBulkArchiveRuns")]
    [InlineData("AddArchiveWhenClear")]
    [InlineData("AddBulkRestore")]
    [InlineData("AddBillCoverage")]
    public void Migrations_that_only_add_are_safe(string name) =>
        Assert.Empty(CloudMigrations.UnsafeOperations(Get(Id(name))));

    [Fact]
    public void Dropping_or_renaming_a_column_is_not()
    {
        Assert.Contains("DropColumn", CloudMigrations.UnsafeOperations(Get(Id("RemovePhoneFromRegistrationSession"))));

        var phase1 = CloudMigrations.UnsafeOperations(Get(Id("RegistrationEnhancementPhase1")));
        Assert.Contains("DropColumn", phase1);
        Assert.Contains("RenameColumn", phase1);
    }

    [Fact]
    public void Every_migration_in_the_project_can_be_checked()
    {
        foreach (var id in Migrations.Assembly.Migrations.Keys)
            _ = CloudMigrations.UnsafeOperations(Get(id));
    }

    [Fact]
    public void It_goes_up_to_the_first_unsafe_migration_and_stops_there()
    {
        var safe1 = Id("AddBulkArchiveRuns");
        var unsafe1 = Id("RemovePhoneFromRegistrationSession");
        var safe2 = Id("AddBulkRestore");

        var (target, blocked, reasons) = CloudMigrations.Plan([safe1, unsafe1, safe2], Get);
        Assert.Equal(safe1, target);
        Assert.Equal(unsafe1, blocked);
        Assert.Contains("DropColumn", reasons);
    }

    [Fact]
    public void An_unsafe_first_migration_applies_nothing()
    {
        var (target, blocked, _) = CloudMigrations.Plan(
            [Id("RemovePhoneFromRegistrationSession"), Id("AddBulkRestore")], Get);
        Assert.Null(target);
        Assert.NotNull(blocked);
    }

    [Fact]
    public void All_safe_goes_to_the_last_one()
    {
        var last = Id("AddBulkRestore");
        var (target, blocked, reasons) = CloudMigrations.Plan([Id("AddArchiveWhenClear"), last], Get);
        Assert.Equal(last, target);
        Assert.Null(blocked);
        Assert.Empty(reasons);
    }
}
