using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace AimPark.API.Migrations
{
    /// <inheritdoc />
    public partial class PolicyRulesHoursAndTwoCategories : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.RenameColumn(
                name: "SuspensionDays",
                table: "Violations",
                newName: "SuspensionHours");

            migrationBuilder.RenameColumn(
                name: "DefaultSuspensionDays",
                table: "PolicyRules",
                newName: "DefaultSuspensionHours");

            // The renamed columns still hold days, so every stored length
            // becomes that many times 24 hours.
            migrationBuilder.Sql(@"UPDATE ""Violations"" SET ""SuspensionHours"" = ""SuspensionHours"" * 24 WHERE ""SuspensionHours"" IS NOT NULL;");
            migrationBuilder.Sql(@"UPDATE ""PolicyRules"" SET ""DefaultSuspensionHours"" = ""DefaultSuspensionHours"" * 24 WHERE ""DefaultSuspensionHours"" IS NOT NULL;");

            // Access, Documentation and Other were folded into Conduct.
            migrationBuilder.Sql(@"UPDATE ""PolicyRules"" SET ""Category"" = 'Conduct' WHERE ""Category"" IN ('Access', 'Documentation', 'Other');");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // Back to whole days, rounding a part-day up so a suspension is
            // never shortened by the rollback. The merged categories stay merged.
            migrationBuilder.Sql(@"UPDATE ""Violations"" SET ""SuspensionHours"" = CEIL(""SuspensionHours"" / 24.0) WHERE ""SuspensionHours"" IS NOT NULL;");
            migrationBuilder.Sql(@"UPDATE ""PolicyRules"" SET ""DefaultSuspensionHours"" = CEIL(""DefaultSuspensionHours"" / 24.0) WHERE ""DefaultSuspensionHours"" IS NOT NULL;");

            migrationBuilder.RenameColumn(
                name: "SuspensionHours",
                table: "Violations",
                newName: "SuspensionDays");

            migrationBuilder.RenameColumn(
                name: "DefaultSuspensionHours",
                table: "PolicyRules",
                newName: "DefaultSuspensionDays");
        }
    }
}
